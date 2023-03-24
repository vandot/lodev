import std/[os, parseopt, strutils]
import pkg/lodnspkg/[actions, server]
import pkg/locertpkg/actions as certActions
import threadpool
import chronos

import ./lodev/[proxy]

const tld = "lo"


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
    dnsIp :string
    dnsPort :int
    targetIp = "127.0.0.1"
    targetPort = Port(3000)

  for kind, key, value in getOpt():
    case kind
    of cmdArgument:
      case key
      of "install":
        (dnsIp, dnsPort) = actions.systemProbe()
        certActions.installCA("dev." & tld, true)
        actions.install(dnsIp, dnsPort, tld)
      of "start":
        start = true
      of "uninstall":
        certActions.uninstallCA(true)
        actions.uninstall(tld)
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
    (dnsIp, dnsPort) = actions.systemProbe()
    var cert = certActions.getCert(true)
    let secureProxy = ProxyServer(targetHost: targetIp, targetPort: targetPort, serverIdent: writeVersion(), cert: cert)
    let proxyServer = createServer(secureProxy)
    spawn server.serve(dnsIp, dnsPort, tld)
    proxyServer.start()
    waitFor proxyServer.join()
    sync()

when isMainModule:
  main()
