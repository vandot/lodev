# lodev
lodev is a simple reverse proxy server for local development with SSL termination.

Obsoletes using ngrok or manually configuring combination of mkcert, dnsmasq and nginx/caddy. It provides HTTPS endpoint under `https://dev.lo` and by default proxies all requests to `http://127.0.0.1:3000`.

It uses [locert](https://github.com/vandot/locert) to generate and install locally trusted SSL certs and [lodns](https://github.com/vandot/lodns) for DNS name resolution.

## Installation
Download correct binary from the latest [release](https://github.com/vandot/lodev/releases) and place it somewhere in the PATH.

Or `nimble install https://github.com/vandot/lodev`

## Configuration
lodev comes preconfigured for all supported platforms to act as a HTTPS reverse proxy server behind `dev.lo` domain.

On MacOS and Linux you have to run with `sudo` to be able to configure the system
```
sudo lodev install
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe install
```

## Start
Service must be started with elevated priviledges because it will bind to a well-known port `443`. By default service will proxy all requests to `127.0.0.1:3000`. You can specify different destination port using `-p=8000`.

On MacOS and Linux
```
sudo lodev start
```
On Windows inside elevated command prompt or Powershell
```
lodev.exe start
```

## Uninstallation
On MacOS and Linux run 
```
sudo lodev uninstall
```
On Windows run inside elevated command prompt or Powershell
```
lodev.exe uninstall
```
and remove the binary.

## License

BSD 3-Clause License
