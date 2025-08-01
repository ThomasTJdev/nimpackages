import std/[
  httpclient,
  os,
  json,
  times
]
import ready

import ./cache

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

  sleep(86400 * 1000)
  echo "Updated packages"