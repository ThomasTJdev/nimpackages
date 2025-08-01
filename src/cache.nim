import std/[
  json,
  options
]

import ready

let cachePool* = newRedisPool(3)


proc rateLimitBlock(ip: string) =
  cachePool.withConnection conn:
    discard conn.command("SET", "rate_limit:" & ip, "1", "EX", "60")

proc rateLimitCheck(ip: string): bool =
  cachePool.withConnection conn:
    let count = conn.command("GET", "rate_limit:" & ip)
    let countOpt = count.to(Option[int])
    if countOpt.isSome:
      return countOpt.get > 10
    return false