# lodev
lodev is a simple reverse proxy server for local development with SSL termination.

Obsoletes using ngrok or manually configuring combination of mkcert, dnsmasq and nginx/caddy. It provides HTTPS endpoint under `https://*.dev.lo` and by default proxies all requests to `http://127.0.0.1:3000`.

It uses [locert](https://github.com/vandot/locert) to generate and install locally trusted SSL certs and [lodns](https://github.com/vandot/lodns) for DNS name resolution.

As described in [locert](https://github.com/vandot/locert) docs, to enable support for custom CA in Firefox on Windows and MacOS per [official document](https://support.mozilla.org/en-US/kb/setting-certificate-authorities-firefox#w_using-built-in-windows-and-macos-support) inside `about:config` set `security.enterprise_roots.enabled` to `true`.

*Note: current implementaion doesn't work with Firefox on Linux, implementation planned in the future.*

## Installation
Download correct binary from the latest [release](https://github.com/vandot/lodev/releases) and place it somewhere in the PATH.

Or `nimble install lodev`

## Configuration
lodev comes preconfigured for all supported platforms to act as a HTTPS reverse proxy server behind `*.dev.lo` domain.

On MacOS and Linux it will ask for sudo password
```
lodev install
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe install
```

## Start
Service will bind to a well-known port `443`. By default service will proxy all requests to `127.0.0.1:3000`. You can specify different destination port using `-p=8000`.

On Linux add CAP_NET_BIND_SERVICE capability to the lodev binary to able to bind port 443 as a non-root user.
```
sudo setcap cap_net_bind_service=+eip lodev
```

On MacOS and Linux
```
lodev start
```
On Windows inside elevated command prompt or Powershell
```
lodev.exe start
```

## Uninstallation
On MacOS and Linux run 
```
lodev uninstall
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe uninstall
```
and remove the binary.

## License

BSD 3-Clause License
