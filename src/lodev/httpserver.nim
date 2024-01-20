import std/[asynchttpserver, asyncdispatch]
import std/strutils

import helpers

template log(lvl: string, msg: varargs[string, `$`]) =
  stdout.writeLine(datetime() & lvl.toUpper() & " " & @msg)

proc httpServer(domain: string, ca: string) {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    log("info", "method=", $req.reqMethod, " uri=", $req.url.path)
    if req.url.path == "/ca":
      let caFile = readFile(ca)
      let headers = newHttpHeaders([("Content-Type","text/plain; charset=utf-8"),("Content-Disposition","attachment; filename=\"locertCA.pem\"")])
      await req.respond(Http200, caFile, headers)
    else:
      let headers = newHttpHeaders([("Content-Type","text/plain; charset=utf-8"),("Location","https://" & domain)])
      await req.respond(Http302, "", headers)
  var address = "0.0.0.0"
  server.listen(Port(80), address)
  log("info", "status=listening ip=", address, " port=80")
  log("info", "status=listening host=", domain)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      await sleepAsync(500)

proc serve*(domain: string, cert: string) =
    waitFor httpServer(domain, cert)
