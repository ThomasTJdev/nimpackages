import std/[
  algorithm,
  options,
  json,
  strutils
]
import ready
import ./cache

type
  Package* = object
    name*: string
    url*: string
    mmethod*: string
    description*: string
    license*: string
    web*: string
    tags*: seq[string]
    latestVersion*: string
    latestUpdateDate*: string
    repoLastChecked*: string
    repoPlatform*: string

type
  SearchResult* = object
    package*: Package
    score*: float
    matchType*: string

proc getPackage*(name: string): Package =
  ## Retrieve a single package by name
  cachePool.withConnection conn:
    let hash = conn.command("HGETALL", "package:" & name)
    let hashArray = hash.to(seq[Option[string]])
    if hashArray.len > 0:
      # HGETALL returns array of key-value pairs
      for i in countup(0, hashArray.len - 2, 2):
        let key = hashArray[i].get("")
        let value = hashArray[i + 1]
        if value.isSome:
          case key
          of "name": result.name = value.get
          of "url": result.url = value.get
          of "method": result.mmethod = value.get
          of "description": result.description = value.get
          of "license": result.license = value.get
          of "web": result.web = value.get
          of "latest_version": result.latestVersion = value.get
          of "latest_update_date": result.latestUpdateDate = value.get
          of "repo_last_checked": result.repoLastChecked = value.get
          of "repo_platform": result.repoPlatform = value.get

      # Get tags
      let tags = conn.command("SMEMBERS", "package:" & name & ":tags")
      result.tags = tags.to(seq[string])

proc getAllPackages*(): seq[Package] =
  ## Retrieve all packages
  cachePool.withConnection conn:
    let packageNames = conn.command("SMEMBERS", "package_names")
    let names = packageNames.to(seq[string])
    result = @[]
    for name in names:
      result.add(getPackage(name))

proc searchPackages*(query: string): seq[Package] =
  ## Search packages with high-quality matching (score 40+)
  cachePool.withConnection conn:
    let packageNames = conn.command("SMEMBERS", "package_names")
    let names = packageNames.to(seq[string])
    result = @[]
    let queryLower = query.toLowerAscii()

    for name in names:
      let package = getPackage(name)
      let nameLower = package.name.toLowerAscii()
      let descLower = package.description.toLowerAscii()

      # High-quality matches (score 40+)
      # Exact name match (100)
      if queryLower == nameLower:
        result.add(package)
        continue
      # Name starts with query (90)
      elif nameLower.startsWith(queryLower):
        result.add(package)
        continue
      # Query is substring of name (80)
      elif queryLower in nameLower:
        result.add(package)
        continue
      # Description contains query (50)
      elif queryLower in descLower:
        result.add(package)
        continue
      # Exact tag match (45)
      else:
        for tag in package.tags:
          let tagLower = tag.toLowerAscii()
          if queryLower == tagLower:
            result.add(package)
            break

proc searchPackagesByTag*(tag: string): seq[Package] =
  ## Search packages by tag
  cachePool.withConnection conn:
    let packageNames = conn.command("SMEMBERS", "tag:" & tag)
    let names = packageNames.to(seq[string])
    result = @[]

    for name in names:
      result.add(getPackage(name))

proc searchPackagesWithScore*(query: string): seq[SearchResult] =
  ## Search packages with scoring for better relevance
  cachePool.withConnection conn:
    let packageNames = conn.command("SMEMBERS", "package_names")
    let names = packageNames.to(seq[string])
    result = @[]
    let queryLower = query.toLowerAscii()

    for name in names:
      let package = getPackage(name)
      let nameLower = package.name.toLowerAscii()
      let descLower = package.description.toLowerAscii()
      var score = 0.0
      var matchType = ""

      # Exact name match (highest priority)
      if queryLower == nameLower:
        score = 100.0
        matchType = "exact_name"
      # Name starts with query
      elif nameLower.startsWith(queryLower):
        score = 90.0
        matchType = "name_starts_with"
      # Query is substring of name
      elif queryLower in nameLower:
        score = 80.0
        matchType = "name_contains"
      # Name is substring of query
      elif nameLower in queryLower:
        score = 40.0
        matchType = "name_partial"

      # Word-based matching in description
      #if score == 0.0:
      let descWords = descLower.split({' ', '-', '_', '.', ',', ';', ':', '!'})
      for word in descWords:
        if queryLower in word:
          score += 40.0
          matchType = "description_word_contains"
          break
        elif word in queryLower:
          score += 15.0
          matchType = "description_word_partial"
          break

      # Tag matching
      #if score == 0.0:
      for tag in package.tags:
        let tagLower = tag.toLowerAscii()
        if queryLower == tagLower:
          score += 45.0
          matchType = "exact_tag"
          break
        elif queryLower in tagLower:
          score += 10.0
          matchType = "tag_contains"
          #break

      # Include high-quality matches (score 40+)
      if score >= 40.0:
        result.add(SearchResult(package: package, score: score, matchType: matchType))

  # Sort by score (highest first)
  result.sort(proc(a, b: SearchResult): int =
    if a.score > b.score: -1 elif a.score < b.score: 1 else: 0
  )

proc getPackageCount*(): int =
  ## Get total number of packages
  cachePool.withConnection conn:
    let count = conn.command("GET", "packages_count")
    let countOpt = count.to(Option[int])
    if countOpt.isSome:
      result = countOpt.get
    else:
      result = 0

proc getLastUpdated*(): int =
  ## Get timestamp of last update
  cachePool.withConnection conn:
    let timestamp = conn.command("GET", "last_updated")
    let timestampOpt = timestamp.to(Option[int])
    if timestampOpt.isSome:
      result = timestampOpt.get
    else:
      result = 0



proc toJson*(package: Package): JsonNode =
  ## Convert package to JSON
  result = %*{
    "name": package.name,
    "url": package.url,
    "method": package.mmethod,
    "description": package.description,
    "license": package.license,
    "web": package.web,
    "tags": package.tags,
    "latest_version": package.latestVersion,
    "latest_update_date": package.latestUpdateDate,
    "repo_last_checked": package.repoLastChecked,
    "repo_platform": package.repoPlatform
  }

proc toJson*(data: SearchResult): JsonNode =
  ## Convert search result to JSON
  result = %*{
    "package": toJson(data.package),
    "score": data.score,
    "matchType": data.matchType
  }
