import std/[os, osproc, parseopt, strutils, nativesockets]
when defined linux:
  import pkg/[sudo]
  import std/[tempfiles]
import pkg/lodnspkg/[actions, server]
import pkg/locertpkg/actions as certActions
import threadpool
import chronos

import ./lodev/[proxy, httpserver]

var tld = "lo"
var domain = "dev"

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
  --local, -l   : use .local domain
  -p, --port    : target port [default 3000]
  -h, --help    : show help
  -v, --version : show version
  """
  quit()

proc main() =
  var
    start = false
    install = false
    uninstall = false
    local = false
    targetIp = "127.0.0.1"
    targetPort = Port(3000)
    dnsIp :string
    dnsPort :int

  for kind, key, value in getOpt():
    case kind
    of cmdArgument:
      case key
      of "install":
        install = true
      of "start":
        start = true
      of "uninstall":
        uninstall = true
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
      of "l", "local":
        local = true
        tld = "local"
        domain = getHostname()
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

  if install:
    when defined macosx:
      var localHostName = execProcess("scutil --get LocalHostName")
      var hostName = execProcess("scutil --get HostName")
      if localHostName != hostName:
        echo "LocalHostName and HostName must be the same, checkout README.md"
        quit(1)
    when defined linux:
      var avahi = execProcess("systemctl is-active avahi-daemon.service")
      var resolved = execProcess("systemctl is-active systemd-resolved.service")
      var systemd = execProcess("ps --no-headers -o comm 1")
      avahi.stripLineEnd
      resolved.stripLineEnd
      systemd.stripLineEnd
      if systemd != "systemd" or resolved != "active":
        echo "linux initialization is supported only for systemd using systemd-resolved"
        quit(1)
      if avahi != "active":
        let resolvedFile = createTempFile("lodev_", "")
        var resolvedText = "[Resolve]\nMulticastDNS=yes\nLLMNR=no"
        resolvedFile.cfile.write resolvedText
        close(resolvedFile.cfile)
        var exitCode = sudoCmd("install -m 644 " & resolvedFile.path & " /etc/systemd/resolved.conf.d/lodev.conf")
        removeFile(resolvedFile.path)
        if exitCode != 0:
          echo "creating file inside /etc/systemd/resolved.conf.d dir failed with code " &
              $exitCode
          quit(1)
        exitCode = sudoCmd("systemctl restart systemd-resolved.service")
        if exitCode != 0:
          echo "restarting systemd-resolved.service failed with code " &
              $exitCode
          quit(1)
    certActions.installCA(domain & "." & tld, true)

  if start:
    let cert = certActions.getCert(true)
    let ca = os.splitPath(cert[0])[0] & "/locertCA.pem"
    let secureProxy = ProxyServer(targetHost: targetIp, targetPort: targetPort, serverIdent: writeVersion(), cert: cert)
    let proxyServer = createServer(secureProxy)
    if local == false:
      (dnsIp, dnsPort) = actions.systemProbe()
      spawn server.serve(dnsIp, dnsPort, domain & "." & tld)
    spawn httpserver.serve(domain & "." & tld, ca)
    proxyServer.start()
    waitFor proxyServer.join()
    sync()

  if uninstall:
    if local == false:
      actions.uninstall(domain & "." & tld)
    when defined linux:
      if local == true:
        var avahi = execProcess("systemctl is-active avahi-daemon.service")
        avahi.stripLineEnd
        if avahi != "active":
          var exitCode = sudoCmd("rm /etc/systemd/resolved.conf.d/lodev.conf")
          if exitCode != 0:
            echo "removing /etc/systemd/resolved.conf.d/lodev.conf failed with code " & $exitCode
            quit(1)
          exitCode = sudoCmd("systemctl restart systemd-resolved.service")
          if exitCode != 0:
            echo "restarting systemd-resolved.service failed with code " &
                $exitCode
            quit(1)
    certActions.uninstallCA(true)

when isMainModule:
  main()
