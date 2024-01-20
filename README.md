# lodev
lodev is a simple reverse proxy server for local development with SSL termination.

Obsoletes using ngrok or manually configuring combination of mkcert, dnsmasq and nginx/caddy. It provides HTTPS endpoint under `https://*.dev.lo` or `https://{COMPUTER_NAME}.local` and by default proxies all requests to `http://127.0.0.1:3000`.

It uses [locert](https://github.com/vandot/locert) to generate and install locally trusted SSL certs and [lodns](https://github.com/vandot/lodns) for DNS name resolution.

As described in [locert](https://github.com/vandot/locert) docs, to enable support for custom CA in Firefox on Windows and MacOS per [official document](https://support.mozilla.org/en-US/kb/setting-certificate-authorities-firefox#w_using-built-in-windows-and-macos-support) inside `about:config` set `security.enterprise_roots.enabled` to `true`.

*Note: current implementaion doesn't work with Firefox on Linux, implementation planned in the future.*

## local mode
With flag `--local` it will generate certificate that is valid for `{COMPUTER_NAME}.local` domain. Using .local it enables for local mDNS server to resolves hostname to all other devices inside local network.
Using your mobile access `http://{COMPUTER_NAME}.local/ca` to download CA certificate and install it.

Follow these manuals to install it on your [iOS](https://support.n4l.co.nz/s/article/Installing-an-SSL-Certificate-on-an-iOS-Device-Manually) or [Android](https://support.n4l.co.nz/s/article/Installing-an-SSL-Certificate-on-an-Android-Device-Manually) device.

## Installation
Download correct binary from the latest [release](https://github.com/vandot/lodev/releases) and place it somewhere in the PATH.

Or pipe the install script to bash
```
curl -sSfL https://raw.githubusercontent.com/vandot/lodev/main/install.sh | bash
```
Or build it locally
```
nimble install lodev
```

## Configuration
lodev comes preconfigured for all supported platforms to act as a HTTPS reverse proxy server behind `*.dev.lo` or `{COMPUTER_NAME}.local` domain.

### *.dev.lo
On MacOS and Linux it will ask for sudo password
```
lodev install
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe install
```

### {COMPUTER_NAME}.local
On MacOS and Linux it will ask for sudo password
```
lodev install --local
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe install --local
```

## Start
Service will bind to a well-known port `443`. By default service will proxy all requests to `127.0.0.1:3000`. You can specify different destination port using `-p=8000`.

On Linux add CAP_NET_BIND_SERVICE capability to the lodev binary to able to bind port 443 as a non-root user.
```
sudo setcap cap_net_bind_service=+eip lodev
```

### *.dev.lo
On MacOS and Linux
```
lodev start
```
On Windows inside elevated command prompt or Powershell
```
lodev.exe start
```

### {COMPUTER_NAME}.local
On MacOS and Linux
```
lodev start --local
```
On Windows inside elevated command prompt or Powershell
```
lodev.exe start --local
```

## Uninstallation
On MacOS and Linux run 
```
lodev uninstall [--local]
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe uninstall [--local]
```
and remove the binary.

## License

BSD 3-Clause License
