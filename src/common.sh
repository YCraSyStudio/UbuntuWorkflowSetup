#!/usr/bin/env bash

DOTNET_VERSION="${DOTNET_VERSION:-10.0}"
NODE_VERSION="${NODE_VERSION:-26}"
NVM_VERSION="${NVM_VERSION:-v0.40.8}"
NPM_MAJOR_VERSION="${NPM_MAJOR_VERSION:-12}"
ANGULAR_MAJOR_VERSION="${ANGULAR_MAJOR_VERSION:-22}"
NCU_MAJOR_VERSION="${NCU_MAJOR_VERSION:-23}"
YED_VERSION="${YED_VERSION:-3.25.1}"
YED_ARCHIVE_URL="${YED_ARCHIVE_URL:-https://www.yworks.com/resources/yed/demo/yEd-${YED_VERSION}.zip}"
export GNOME_EXTENSIONS_API="https://extensions.gnome.org/extension-info/"

log() {
  printf '\n==> %s\n' "$*"
}

run_as_user() {
  if [[ "$(id -un)" == "$USER_NAME" ]]; then
    "$@"
  else
    sudo -u "$USER_NAME" -H env \
      DISPLAY="${DISPLAY:-}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
      XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}" \
      "$@"
  fi
}

manual_step() {
  printf '%s\n' "- $*"
}
