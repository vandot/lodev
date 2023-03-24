import chronos, chronos/apps/http/[shttpserver, httpclient]
import stew/results, strutils

import helpers

template log(lvl: string, msg: varargs[string, `$`]) =
  stdout.writeLine(datetime() & lvl.toUpper() & " " & @msg)
  
type
  ProxyServerState* {.pure.} = enum
    Closed, Stopped, Running

  SecureProxyServer* = object of RootObj 
    server*: SecureHttpServerRef
    proxy*: ProxyServer

  SecureProxyServerRef* = ref SecureProxyServer

  ProxyServer* = object
    targetHost*: string
    targetPort*: Port
    serverIdent*: string
    cert*: (string, string)

  ProxyResult*[T] = Result[T, cstring]

proc processProxyRequest*[T](server: T,
                            rf: RequestFence): Future[HttpResponseRef] {.
     gcsafe, async.} =
  if rf.isOk():
    let request = rf.get()
    log("info", "method=", $request.meth, " uri=", $request.uri)
    let target = initTAddress(server.proxy.targetHost & ":" & $server.proxy.targetPort)
    let session = HttpSessionRef.new()
    var ha = getAddress(target, HttpClientScheme.NonSecure)
    ha.path = $request.uri.path
    if not request.query.isEmpty:
      for q in request.query:
        var query = $q[0] & "=" & request.query.getString($q[0]) & "&"
        ha.query.add(query)
      ha.query.removeSuffix("&")
    var reqHeaders: seq[(string, string)]
    for h in request.headers.toList():
      if $h[0].toLower() == "cache-control":
        continue
      reqHeaders.add(($h[0], $h[1]))
    reqHeaders.add(("X-Real-IP", $request.remoteAddress.address()))
    reqHeaders.add(("Cache-Control", "no-cache"))
    reqHeaders.add(("Pragma", "no-cache"))
    let optBody = await request.getBody()
    let agent = HttpClientRequestRef.new(session, ha, request.meth, request.version, {}, reqHeaders, optBody)
    let proxyResponse = await agent.send()
    var resHeaders: HttpTable
    for h in proxyResponse.headers.toList():
      if $h[0].toLower() == "content-length":
        continue
      if $h[0].toLower() == "transfer-encoding":
        continue
      resHeaders.add($h[0], $h[1])
    if proxyResponse.headers.contains("Location"):
      await proxyResponse.closeWait()
      return await request.redirect(fromInt(proxyResponse.status), proxyResponse.headers.getString("Location"), resHeaders)
    let body = await proxyResponse.getBodyBytes()
    await proxyResponse.closeWait()
    return await request.respond(fromInt(proxyResponse.status), body, resHeaders)
  else:
    return dumbResponse()

proc new*(t: typedesc[SecureProxyServerRef], 
          proxy: ProxyServer,
          address: TransportAddress,
          tlsPrivateKey: TLSPrivateKey,
          tlsCertificate: TLSCertificate,
          serverIdent: string = "lodev",
          secureFlags: set[TLSFlags] = {},
          serverFlags = {Secure},
          socketFlags: set[ServerFlags] = {ServerFlags.TcpNoDelay, ServerFlags.ReuseAddr},
          serverUri = Uri(),
          maxConnections: int = -1,
          backlogSize: int = 100,
          bufferSize: int = 4096,
          httpHeadersTimeout = 10.seconds,
          maxHeadersSize: int = 8192,
          maxRequestBodySize: int = 1_048_576
         ): ProxyResult[SecureProxyServerRef] =
  var server = SecureProxyServerRef(proxy: proxy)

  proc processCallback(rf: RequestFence): Future[HttpResponseRef] =
    processProxyRequest(server, rf)

  let sres = SecureHttpServerRef.new(address, processCallback, tlsPrivateKey,
                                     tlsCertificate, serverFlags, socketFlags,
                                     serverUri, proxy.serverIdent, secureFlags,
                                     maxConnections, bufferSize, backlogSize,
                                     httpHeadersTimeout, maxHeadersSize,
                                     maxRequestBodySize)
  if sres.isOk():
    server.server = sres.get()
    ok(server)
  else:
    err("Could not create HTTPS server instance")

proc state*(rs: SecureProxyServerRef): ProxyServerState =
  case rs.server.state
  of HttpServerState.ServerClosed:
    ProxyServerState.Closed
  of HttpServerState.ServerStopped:
    ProxyServerState.Stopped
  of HttpServerState.ServerRunning:
    ProxyServerState.Running

proc start*(rs: SecureProxyServerRef) =
  rs.server.start()
  log("info", "status=listening ip=", rs.server.address.host(), " port=", rs.server.address.port, " to=", rs.proxy.targetHost, ":", rs.proxy.targetPort)

proc stop*(rs: SecureProxyServerRef) {.async.} =
  await rs.server.stop()
  log("info", "status=stopped ip=", rs.server.address.host(), " port=", rs.server.address.port)

proc drop*(rs: SecureProxyServerRef): Future[void] =
  rs.server.drop()

proc closeWait*(rs: SecureProxyServerRef) {.async.} =
  await rs.server.closeWait()
  log("info", "status=closed ip=", rs.server.address.host(), " port=", rs.server.address.port)

proc join*(rs: SecureProxyServerRef): Future[void] =
  rs.server.join()

proc createServer*(proxy: ProxyServer): SecureProxyServerRef =
  let address = initTAddress("127.0.0.1:443")
  let secureKey = TLSPrivateKey.init(readFile(proxy.cert[1]))
  let secureCert = TLSCertificate.init(readFile(proxy.cert[0]))
  let sres = SecureProxyServerRef.new(proxy, address, secureKey,
                                     secureCert)
  sres.get()
