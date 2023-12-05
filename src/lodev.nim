import std/[os, parseopt, strutils, nativesockets]
when not defined macosx:
  import pkg/lodnspkg/[actions, server]
import pkg/locertpkg/actions as certActions
import threadpool
import chronos

import ./lodev/[proxy, httpserver]

var tld = "lo"
var domain = "dev"

when defined macosx:
  tld = "local"
  domain = getHostname()

proc writeVersion(): string =
  const NimblePkgVersion {.strdefine.} = "dev"
  result = getAppFilename().extractFilename() & "-" & NimblePkgVersion

proc writeHelp() =
  echo writeVersion()
  echo """
  Run local reverse proxy server with SSL termination
  and custom DNS resolver.

  install       : install system files
  uninstall     : uninstall system files
  start         : start service
  -p, --port    : target port [default 3000]
  -h, --help    : show help
  -v, --version : show version
  """
  quit()

proc main() =
  var
    start = false
    targetIp = "127.0.0.1"
    targetPort = Port(3000)
  when not defined macosx:
    var
      dnsIp :string
      dnsPort :int

  for kind, key, value in getOpt():
    case kind
    of cmdArgument:
      case key
      of "install":
        when not defined macosx:
          (dnsIp, dnsPort) = actions.systemProbe()
          actions.install(dnsIp, dnsPort, domain & "." & tld)
        certActions.installCA(domain & "." & tld, true)
      of "start":
        start = true
      of "uninstall":
        when not defined macosx:
          actions.uninstall(domain & "." & tld)
        certActions.uninstallCA(true)
      else:
        echo "unknown argument: ", key
        writeHelp()
    of cmdLongOption, cmdShortOption:
      case key
      of "p", "port":
        if value == "":
          echo "use '=' to specify port -p=3000 or --port=3000"
          quit(1)
        targetPort = Port(parseInt(value))
      of "v", "version":
        echo writeVersion()
        quit()
      of "h", "help":
        writeHelp()
      else:
        echo "unknown option: ", key
        writeHelp()
    of cmdEnd:
      discard

  if start:
    let cert = certActions.getCert(true)
    let ca = os.splitPath(cert[0])[0] & "/locertCA.pem"
    let secureProxy = ProxyServer(targetHost: targetIp, targetPort: targetPort, serverIdent: writeVersion(), cert: cert)
    let proxyServer = createServer(secureProxy)
    when not defined macosx:
      (dnsIp, dnsPort) = actions.systemProbe()
      spawn server.serve(dnsIp, dnsPort, domain & "." & tld)
    spawn httpserver.serve(domain & "." & tld, ca)
    proxyServer.start()
    waitFor proxyServer.join()
    sync()

when isMainModule:
  main()
