import std/[
  json
]

import
  mummy, mummy/routers,
  mummy_utils

import
  ./cache,
  ./cron,
  ./html,
  ./packages

const favicon = staticRead("../resources/favicon.ico")

proc indexHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html; charset=utf-8"

  let html = indexPackagesAll()
  request.respond(200, headers, html)

proc htmlSearchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html; charset=utf-8"

  let query = @"q"
  if query.len == 0:
    # Redirect to home if no query
    headers["Location"] = "/"
    request.respond(302, headers, "")
    return

  let html = indexPackagesSearch(query)
  request.respond(200, headers, html)

proc htmlPackageHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html; charset=utf-8"

  let name = @"name"
  if name.len == 0:
    headers["Location"] = "/"
    request.respond(302, headers, "")
    return

  let html = packageDetails(name)
  request.respond(200, headers, html)

proc apiEndpointsHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html; charset=utf-8"

  let html = apiEndpoints()
  request.respond(200, headers, html)


proc packagesHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let packages = getAllPackages()
  var packagesJson = newJArray()

  for package in packages:
    packagesJson.add(toJson(package))

  let response = %*{
    "packages": packagesJson,
    "count": packages.len
  }

  request.respond(200, headers, $response)

proc searchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let query = @"q"
  if query.len == 0:
    request.respond(400, headers, $(%*{"error": "Query parameter 'q' is required"}))
    return

  # Use the improved search with scoring
  let searchResults = searchPackagesWithScore(query)
  var resultsJson = newJArray()

  for result in searchResults:
    resultsJson.add(toJson(result))

  let response = %*{
    "results": resultsJson,
    "count": searchResults.len,
    "query": query,
    "searchInfo": {
      "description": "High-quality results only (score 40+). Sorted by relevance: 100 = exact name, 90 = starts with, 80 = contains, 50 = description, 45 = exact tag"
    }
  }

  request.respond(200, headers, $response)

proc simpleSearchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let query = request.queryParams["q"]
  if query.len == 0:
    request.respond(400, headers, $(%*{"error": "Query parameter 'q' is required"}))
    return

  let packages = searchPackages(query)
  var packagesJson = newJArray()

  for package in packages:
    packagesJson.add(toJson(package))

  let response = %*{
    "packages": packagesJson,
    "count": packages.len,
    "query": query
  }

  request.respond(200, headers, $response)

proc tagSearchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let tag = @"tag"
  if tag.len == 0:
    request.respond(400, headers, $(%*{"error": "Tag parameter is required"}))
    return

  let packages = searchPackagesByTag(tag)
  var packagesJson = newJArray()

  for package in packages:
    packagesJson.add(toJson(package))

  let response = %*{
    "packages": packagesJson,
    "count": packages.len,
    "tag": tag
  }

  request.respond(200, headers, $response)

proc packageHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let name = @"name"
  if name.len == 0:
    request.respond(400, headers, $(%*{"error": "Package name is required"}))
    return

  let package = getPackage(name)
  if package.name.len == 0:
    request.respond(404, headers, $(%*{"error": "Package not found"}))
    return

  request.respond(200, headers, $toJson(package))

proc statsHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let response = %*{
    "total_packages": getPackageCount(),
    "last_updated": getLastUpdated()
  }

  request.respond(200, headers, $response)

proc faviconHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "image/x-icon"
  request.respond(200, headers, favicon)


var router: Router
router.get("/", indexHandler)
router.get("/search", htmlSearchHandler)
router.get("/package/@name", htmlPackageHandler)
router.get("/api", apiEndpointsHandler)
router.get("/api/packages", packagesHandler)
router.get("/api/packages/search", searchHandler)
router.get("/api/packages/search/simple", simpleSearchHandler)
router.get("/api/packages/tag/@tag", tagSearchHandler)
router.get("/api/packages/@name", packageHandler)
router.get("/api/stats", statsHandler)
router.get("/favicon.ico", faviconHandler)

var thread: Thread[void]
proc main() =
  createThread(thread, updatePackages)

  let server = newServer(router)
  echo "Serving on http://localhost:8080"
  server.serve(Port(8080))

when isMainModule:
  main()