import std/[
  envvars,
  httpclient,
  os,
  json,
  options,
  strutils,
  times,
  uri
]

import ready

import ./cache
import ./package_fetching

proc updatePackages*() {.thread.} =
  var packages: JsonNode
  when defined(release):
    echo "Downloading packages.json"
    let client = newHttpClient()
    let response = client.get("https://raw.githubusercontent.com/nim-lang/packages/refs/heads/master/packages.json")
    packages = response.body.parseJson()
    echo "Packages: ", packages.len

  when defined(dev):
    if fileExists("packages.json"):
      packages = readFile("packages.json").parseJson()
    else:
      echo "Downloading packages.json"
      let client = newHttpClient()
      let response = client.get("https://raw.githubusercontent.com/nim-lang/packages/refs/heads/master/packages.json")
      packages = response.body.parseJson()
      writeFile("packages.json", $packages)

  if packages.kind != JArray or packages.len == 0:
    echo "No packages found"
    return

  # Store each package individually as a Redis hash for better querying
  cachePool.withConnection conn:
    # Clear existing packages
    discard conn.command("DEL", "package_names")

    for package in packages:
      let name = if package.hasKey("name"): package["name"].getStr() else: ""
      if name.len == 0:
        continue

      # Store package as a hash
      discard conn.command("HSET", "package:" & name,
        "name", name,
        "url", if package.hasKey("url"): package["url"].getStr() else: "",
        "method", if package.hasKey("method"): package["method"].getStr() else: "",
        "description", if package.hasKey("description"): package["description"].getStr() else: "",
        "license", if package.hasKey("license"): package["license"].getStr() else: "",
        "web", if package.hasKey("web"): package["web"].getStr() else: ""
      )

      # Store tags as a separate set for each package
      let tags = if package.hasKey("tags"): package["tags"].getElems() else: @[]
      for tag in tags:
        discard conn.command("SADD", "package:" & name & ":tags", tag.getStr())
        discard conn.command("SADD", "tag:" & tag.getStr(), name)

      # Add to package names set for listing
      discard conn.command("SADD", "package_names", name)

    # Store metadata
    discard conn.command("SET", "packages_count", $packages.len)
    discard conn.command("SET", "last_updated", $getTime().toUnix())

  echo "Packages updated"
  sleep(43200 * 1000)


proc updatePackagesWithRepoInfo*() {.thread.} =
  ## Update packages and enrich with repository info weekly (GitHub, GitLab, Codeberg)
  const WEEKLY_INTERVAL_SECONDS = 7 * 24 * 60 * 60  # 7 days in seconds
  const REDIS_KEY_LAST_REPO_UPDATE = "last_repo_update_timestamp"

  while true:
    # Check if we need to run the update
    var shouldRun = false
    cachePool.withConnection conn:
      let lastUpdate = conn.command("GET", REDIS_KEY_LAST_REPO_UPDATE)
      let lastUpdateOpt = lastUpdate.to(Option[int])

      if lastUpdateOpt.isNone:
        # First time running, should update
        shouldRun = true
      else:
        let timeSinceLastUpdate = getTime().toUnix() - lastUpdateOpt.get
        shouldRun = timeSinceLastUpdate >= WEEKLY_INTERVAL_SECONDS

    if not shouldRun:
      echo "Repository info update not due yet. Sleeping for 1 hour before next check..."
      sleep(60 * 60 * 1000)  # Sleep for 1 hour before checking again
      continue

    echo "Starting weekly repository info update..."
    let updateStartTime = getTime().toUnix()

    # Create a single HTTP client for all requests
    let client = newHttpClient()
    client.headers = newHttpHeaders({
      "User-Agent": "nimpackages/1.0"
    })

    var processedCount = 0
    var enrichedCount = 0
    try:
      # Get all packages
      cachePool.withConnection conn:
        let packageNames = conn.command("SMEMBERS", "package_names")
        let names = packageNames.to(seq[string])

        for name in names:
          # Get package info
          let hash = conn.command("HGETALL", "package:" & name)
          let hashArray = hash.to(seq[Option[string]])

          if hashArray.len > 0:
            var url = ""
            # Extract URL from hash
            for i in countup(0, hashArray.len - 2, 2):
              let key = hashArray[i].get("")
              let value = hashArray[i + 1]
              if key == "url" and value.isSome:
                url = value.get
                break

            # Fetch repository info if it's a supported platform
            let (_, _, platform) = extractRepoInfo(url)
            if platform.len > 0:
              let info = fetchPackageRepoInfo(name, url, client)
              if info.isSome:
                discard conn.command("HSET", "package:" & name,
                  "latest_version", info.get["latest_version"].getStr(),
                  "latest_update_date", info.get["latest_update_date"].getStr(),
                  "repo_last_checked", info.get["last_checked"].getStr(),
                  "repo_platform", info.get["platform"].getStr()
                )
                enrichedCount.inc()

              # Rate limiting: sleep 1 second between requests to be respectful
              sleep(1000)

            processedCount.inc()

            when defined(dev):
              echo "Processed $1 packages, enriched $2 with $3 info" % [$processedCount, $url, $platform]
              if processedCount > 5:
                break

            # Progress update every 100 packages
            if processedCount mod 100 == 0:
              echo "Processed $1 packages, enriched $2 with repository info" % [$processedCount, $enrichedCount]

      # Store the completion timestamp in Redis
      cachePool.withConnection conn:
        discard conn.command("SET", REDIS_KEY_LAST_REPO_UPDATE, $updateStartTime)
        echo "Repository info update completed at timestamp: $1" % [$updateStartTime]

      echo "Completed: processed $1 packages, enriched $2 with repository info" % [$processedCount, $enrichedCount]

    finally:
      client.close()

    echo "Repository info update completed. Next update in 7 days."
    # Sleep for 1 hour before checking if we need to run again
    sleep(60 * 60 * 1000)


