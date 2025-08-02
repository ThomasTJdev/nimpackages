import std/[
  json,
  options
]

import
  mummy, mummy_utils,
  ready

let cachePool* = newRedisPool(3)


proc rateLimitIncrement(ip: string): int =
  ## Increment rate limit counter for IP and return current count
  cachePool.withConnection conn:
    # Use INCR to atomically increment the counter
    let count = conn.command("INCR", "rate_limit:" & ip)
    result = count.to(int)

    # Set expiry to 60 seconds (1 minute) if this is the first request
    if result == 1:
      discard conn.command("EXPIRE", "rate_limit:" & ip, "60")

proc rateLimitCheck(ip: string): bool =
  ## Check if IP has exceeded rate limit (60 requests per minute)
  cachePool.withConnection conn:
    let count = conn.command("GET", "rate_limit:" & ip)
    let countOpt = count.to(Option[int])
    if countOpt.isSome:
      return countOpt.get > 60
    return false

template ratelimitHeaders*(request: Request, headers: var HttpHeaders) =
  let ip = request.ip()
  let currentCount = rateLimitIncrement(ip)
  if rateLimitCheck(ip):
    headers["X-RateLimit-Limit"] = "60"
    headers["X-RateLimit-Remaining"] = "0"
    request.respond(429, headers, $(%*{"error": "Rate limit exceeded. Maximum 60 requests per minute."}))
    return

  headers["X-RateLimit-Limit"] = "60"
  headers["X-RateLimit-Remaining"] = $(60 - currentCount)