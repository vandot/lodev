#!/usr/bin/env bash

APP_NAME="lodev"
REPO_URL="https://github.com/vandot/lodev"
SUPPORTED_ARCH="darwin-amd64\ndarwin-arm64\nlinux-amd64"

VERSION_ARG="--version"
HELP_ARG="--help"
version_filter=(cut -d'-' -f2)

: "${USE_SUDO:="true"}"
: "${APP_INSTALL_DIR:="/usr/local/bin"}"

detect_arch() {
  ARCH=$(uname -m)
  case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

detect_os() {
  OS=$(uname|tr '[:upper:]' '[:lower:]')

  case "$OS" in
    # minimalist GNU for Windows.
    mingw*) OS='windows';;
  esac
}

run_as_root() {
  local CMD="$*"
  if [ $EUID -ne 0 ] && [ $USE_SUDO = "true" ]; then
    CMD="sudo $CMD"
  fi

  $CMD
}

# check if local machine OS and arch matches list of supported ones.
supported() {
  if ! echo "${SUPPORTED_ARCH}" | grep -q "${OS}-${ARCH}"; then
    if [ $OS == "windows" ]; then
      echo "Auto install not supported for Windows."
      echo "Install binary from here $REPO_URL/releases"
      exit 1
    else
      echo "No prebuilt binary for ${OS}-${ARCH}."
      echo "To build from source, go to $REPO_URL"
      exit 1
    fi
  fi

  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "Either curl or wget is required"
    exit 1
  fi
}

# check_installed_version checks which version of app is installed and
# if it needs to be changed.
check_installed_version() {
  if [[ -f "${APP_INSTALL_DIR}/${APP_NAME}" ]]; then
    local version=$($APP_NAME $VERSION_ARG 2>&1 | "${version_filter[@]}")
    if [[ "${version%-*}" == "${TAG#v}" ]]; then
      echo "$APP_NAME $version is already ${TAG:-latest}."
      return 0
    else
      echo "$APP_NAME ${TAG} is available. Changing from version ${version}."
      return 1
    fi
  else
    return 1
  fi
}

# check_tag_provided checks whether TAG has provided as an environment variable
# so we can skip check_latest_version.
check_tag_provided() {
  [[ ! -z "$TAG" ]]
}

# check_latest_version grabs the latest version string from the releases.
check_latest_version() {
  local latest_release_url="$REPO_URL/releases/latest"
  if command -v curl &> /dev/null; then
    TAG=$(curl -Ls -o /dev/null -w %{url_effective} $latest_release_url | grep -oE "[^/]+$" )
  elif command -v wget &> /dev/null; then
    TAG=$(wget $latest_release_url --server-response -O /dev/null 2>&1 | awk '/^  Location: /{DEST=$2} END{ print DEST}' | grep -oE "[^/]+$")
  fi
}

# download_file downloads the latest binary package and also the checksum
# for that binary.
download_file() {
  APP_DIST="$APP_NAME-$OS-$ARCH"
  if [ "$OS" == "windows" ]; then
    APP_DIST="$APP_NAME-$OS-$ARCH.exe"
  fi
  DOWNLOAD_URL="$REPO_URL/releases/download/$TAG/$APP_DIST"
  APP_TMP_ROOT="$(mktemp -dt $APP_NAME-binary)"
  APP_TMP_FILE="$APP_TMP_ROOT/$APP_DIST"
  if command -v curl &> /dev/null; then
    curl -SsL "$DOWNLOAD_URL" -o "$APP_TMP_FILE"
  elif command -v wget &> /dev/null; then
    wget -q -O "$APP_TMP_FILE" "$DOWNLOAD_URL"
  fi
}

# install_file verifies the SHA256 for the file, then unpacks and
# installs it.
install_file() {
  echo "Preparing to install $APP_NAME into ${APP_INSTALL_DIR}"
  run_as_root chmod +x "$APP_TMP_FILE"
  run_as_root cp "$APP_TMP_FILE" "$APP_INSTALL_DIR/$APP_NAME"
  echo "$APP_NAME installed into $APP_INSTALL_DIR/$APP_NAME"
}

# fail_trap is executed if an error occurs.
fail_trap() {
  result=$?
  if [ "$result" != "0" ]; then
    if [[ -n "$INPUT_ARGUMENTS" ]]; then
      echo "Failed to install $APP_NAME with the arguments provided: $INPUT_ARGUMENTS"
      help
    else
      echo "Failed to install $APP_NAME"
    fi
    echo -e "For support, go to $REPO_URL."
  fi
  cleanup
  exit $result
}

# test_binary tests the installed client to make sure it is working.
test_binary() {
  if ! command -v $APP_NAME &> /dev/null; then
    echo "$APP_NAME not found. Is $APP_INSTALL_DIR on your "'$PATH?'
    exit 1
  fi
  echo "Run '$APP_NAME $HELP_ARG' to see what you can do with it."
}

# help provides possible cli installation arguments.
help () {
  echo "Accepted cli arguments are:"
  echo -e " [--tag|-t vx.x.x] ->> install this tag"
  echo -e " [--help|-h] ->> prints this help"
  echo -e " [--no-sudo] ->> install without sudo"
}

# cleanup temporary files.
cleanup() {
  if [[ -d "${APP_TMP_ROOT:-}" ]]; then
    rm -rf "$APP_TMP_ROOT"
  fi
}

# execution

# stop execution on any error.
trap "fail_trap" EXIT
set -e

# parsing input arguments (if any).
export INPUT_ARGUMENTS="${@}"
set -u
while [[ $# -gt 0 ]]; do
  case $1 in
    '--tag'|-t)
       TAG="${2}"
       shift
       ;;
    '--no-sudo')
       USE_SUDO="false"
       ;;
    '--help'|-h)
       help
       exit 0
       ;;
    *) exit 1
       ;;
  esac
  shift
done
set +u

detect_arch
detect_os
supported
check_tag_provided || check_latest_version
if ! check_installed_version; then
  download_file
  install_file
fi

test_binary
cleanup
