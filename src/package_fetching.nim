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


proc extractRepoInfo*(url: string): tuple[owner: string, repo: string, platform: string] =
  ## Extract owner, repo, and platform from repository URL
  result = (owner: "", repo: "", platform: "")

  # Handle GitHub URLs
  if url.startsWith("https://github.com/"):
    let parts = url.replace("https://github.com/", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1].replace(".git", "")
      result.platform = "github"
  elif url.startsWith("git@github.com:"):
    let parts = url.replace("git@github.com:", "").replace(".git", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1]
      result.platform = "github"

  # Handle GitLab URLs
  elif url.startsWith("https://gitlab.com/"):
    let parts = url.replace("https://gitlab.com/", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1].replace(".git", "")
      result.platform = "gitlab"
  elif url.startsWith("git@gitlab.com:"):
    let parts = url.replace("git@gitlab.com:", "").replace(".git", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1]
      result.platform = "gitlab"

  # Handle Codeberg URLs
  elif url.startsWith("https://codeberg.org/"):
    let parts = url.replace("https://codeberg.org/", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1].replace(".git", "")
      result.platform = "codeberg"
  elif url.startsWith("git@codeberg.org:"):
    let parts = url.replace("git@codeberg.org:", "").replace(".git", "").split("/")
    if parts.len >= 2:
      result.owner = parts[0]
      result.repo = parts[1]
      result.platform = "codeberg"

proc fetchPackageRepoInfo*(packageName: string, url: string, client: HttpClient): Option[JsonNode] =
  ## Fetch repository info for a specific package (GitHub, GitLab, Codeberg)
  try:
    let (owner, repo, platform) = extractRepoInfo(url)
    if owner.len == 0 or repo.len == 0:
      echo "Invalid repository URL: $1" % url
      return none(JsonNode)

    var apiUrl = ""
    var tagsUrl = ""
    var token = ""

    case platform:
    of "github":
      apiUrl = "https://api.github.com/repos/$1/$2" % [owner, repo]
      tagsUrl = apiUrl & "/tags"
      token = getEnv("GITHUB_TOKEN")
    of "gitlab":
      let encodedPath = encodeUrl(owner & "/" & repo)
      apiUrl = "https://gitlab.com/api/v4/projects/" & encodedPath
      tagsUrl = apiUrl & "/repository/tags"
      token = getEnv("GITLAB_TOKEN")
    of "codeberg":
      apiUrl = "https://codeberg.org/api/v1/repos/$1/$2" % [owner, repo]
      tagsUrl = apiUrl & "/tags"
      token = getEnv("CODEBERG_TOKEN")
    else:
      echo "Unsupported platform: $1" % platform
      return none(JsonNode)

    # Set authorization header if token is available
    if token.len > 0:
      client.headers["Authorization"] = "Bearer " & token

    # Fetch repository info (includes updated_at)
    let repoResponse = client.get(apiUrl)

    # Handle rate limiting (403/429)
    if repoResponse.status == "403 Forbidden" or repoResponse.status == "429 Too Many Requests":
      echo "Rate limited for $1 ($2). Waiting 1 hour..." % [platform, repoResponse.status]
      sleep(3600 * 1000) # Wait 1 hour
      return none(JsonNode)

    if repoResponse.status != "200 OK":
      echo "Failed to fetch $1 repository info for $2: $3" % [platform, apiUrl, repoResponse.status]
      return none(JsonNode)

    let repoData = repoResponse.body.parseJson()
    var updatedAt = ""

    # Extract updated_at based on platform
    case platform:
    of "github":
      updatedAt = repoData["updated_at"].getStr()
    of "gitlab":
      updatedAt = repoData["last_activity_at"].getStr()
    of "codeberg":
      updatedAt = repoData["updated_at"].getStr()

    # Fetch latest tag
    let tagsResponse = client.get(tagsUrl)

    # Handle rate limiting for tags request
    if tagsResponse.status == "403 Forbidden" or tagsResponse.status == "429 Too Many Requests":
      echo "Rate limited for $1 tags ($2). Waiting 1 hour..." % [platform, tagsResponse.status]
      sleep(3600 * 1000) # Wait 1 hour
      return none(JsonNode)

    if tagsResponse.status != "200 OK":
      echo "Failed to fetch $1 tags for $2: $3" % [platform, tagsUrl, tagsResponse.status]
      return none(JsonNode)

    let tagsData = tagsResponse.body.parseJson()
    var latestVersion = "main"

    # Extract latest version based on platform
    if tagsData.kind == JArray and tagsData.len > 0:
      case platform:
      of "github":
        latestVersion = tagsData[0]["name"].getStr()
      of "gitlab":
        latestVersion = tagsData[0]["name"].getStr()
      of "codeberg":
        latestVersion = tagsData[0]["name"].getStr()
      else:
        discard

    result = some(%*{
      "latest_version": latestVersion,
      "latest_update_date": updatedAt,
      "last_checked": getTime().toUnix(),
      "platform": platform
    })

  except:
    return none(JsonNode)

