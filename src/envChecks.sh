#!/usr/bin/env bash

check_environment() {
  local ubuntu_major_version

  if [[ ! -r /etc/os-release ]]; then
    printf 'No se pudo identificar el sistema operativo.\n' >&2
    return 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "$ID" != "ubuntu" ]]; then
    printf 'Este instalador solo es compatible con Ubuntu. Sistema: %s\n' \
      "$PRETTY_NAME" >&2
    return 1
  fi

  ubuntu_major_version="${VERSION_ID%%.*}"
  if ((ubuntu_major_version < 24)); then
    printf 'Se requiere Ubuntu 24 o superior. Sistema: %s\n' \
      "$PRETTY_NAME" >&2
    return 1
  fi

  USER_NAME="${SUDO_USER:-$USER}"
  USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
  USER_ID="$(id -u "$USER_NAME")"

  if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    printf 'No se pudo detectar HOME para %s.\n' "$USER_NAME" >&2
    return 1
  fi

  export USER_NAME USER_HOME USER_ID
  export DEBIAN_FRONTEND=noninteractive
}
