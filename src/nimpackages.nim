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
  let html = indexPackagesAll()
  resp(Http200, html)

proc htmlSearchHandler(request: Request) =

  let query = @"q"
  if query.len == 0:
    redirect(Http302, "/")

  let html = indexPackagesSearch(query)
  resp(Http200, html)

proc htmlPackageHandler(request: Request) =
  let name = @"name"
  if name.len == 0:
    redirect(Http302, "/")

  let html = packageDetails(name)
  resp(Http200, html)

proc apiEndpointsHandler(request: Request) =
  let html = apiEndpoints()
  resp(Http200, html)


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

  resp(Http200, headers, $response)

proc searchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let query = @"q"
  if query.len == 0:
    resp(Http400, headers, $(%*{"error": "Query parameter 'q' is required"}))
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

  resp(Http200, headers, $response)

proc simpleSearchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let query = request.queryParams["q"]
  if query.len == 0:
    resp(Http400, headers, $(%*{"error": "Query parameter 'q' is required"}))
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

  resp(Http200, headers, $response)

proc tagSearchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let tag = @"tag"
  if tag.len == 0:
    resp(Http400, headers, $(%*{"error": "Tag parameter is required"}))
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

  resp(Http200, headers, $response)

proc packageHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let name = @"name"
  if name.len == 0:
    resp(Http400, headers, $(%*{"error": "Package name is required"}))
    return

  let package = getPackage(name)
  if package.name.len == 0:
    resp(Http404, headers, $(%*{"error": "Package not found"}))
    return

  resp(Http200, headers, $toJson(package))

proc statsHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"

  ratelimitHeaders(request, headers)

  let response = %*{
    "total_packages": getPackageCount(),
    "last_updated": getLastUpdated()
  }

  resp(Http200, headers, $response)

proc faviconHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "image/x-icon"
  resp(Http200, headers, favicon)

proc statusHandlerHead(request: Request) =
  resp(Http200)

proc statusHandlerGet(request: Request) =
  resp(Http200, ContentType.Json, """{"status": "OK"}""")

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

router.head("/", statusHandlerHead)
router.get("/status", statusHandlerGet)

var thread: Thread[void]
proc main() =
  createThread(thread, updatePackages)

  let server = newServer(router)
  echo "Serving on http://localhost:8080"
  server.serve(Port(8080))

when isMainModule:
  main()