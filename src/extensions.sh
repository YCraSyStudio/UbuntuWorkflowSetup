#!/usr/bin/env bash

install_gnome_extension() {
  local extension_pk="$1"
  local expected_uuid="$2"
  local extension_name="$3"
  local extension_info download_url extension_uuid archive

  log "Instalar extensión GNOME: $extension_name"
  extension_info="$(curl -fsSL --get \
    --data-urlencode "pk=$extension_pk" \
    --data-urlencode "shell_version=$GNOME_SHELL_VERSION" \
    "$GNOME_EXTENSIONS_API")"
  download_url="$(jq -er '.download_url' <<<"$extension_info")"
  extension_uuid="$(jq -er '.uuid' <<<"$extension_info")"

  if [[ "$extension_uuid" != "$expected_uuid" ]]; then
    printf 'UUID inesperado para %s: %s\n' "$extension_name" "$extension_uuid" >&2
    return 1
  fi

  archive="$(mktemp --suffix=.zip)"
  if ! curl -fsSL "https://extensions.gnome.org${download_url}" -o "$archive"; then
    rm -f "$archive"
    return 1
  fi
  if ! run_as_user gnome-extensions install --force "$archive"; then
    rm -f "$archive"
    return 1
  fi
  rm -f "$archive"

  if ! run_as_user gnome-extensions enable "$extension_uuid"; then
    printf '%s se habilitará después de cerrar sesión.\n' "$extension_name"
  fi
}

install_gnome_extensions() {
  local GNOME_SHELL_VERSION

  if ! is_selected gnome_manager; then return; fi
  if ! is_selected copyous && ! is_selected dash_to_panel; then return; fi

  GNOME_SHELL_VERSION="$(gnome-shell --version | sed -E 's/[^0-9]*([0-9]+).*/\1/')"
  if [[ -z "$GNOME_SHELL_VERSION" ]]; then
    printf 'No se pudo detectar la versión de GNOME Shell.\n' >&2
    return 1
  fi

  if is_selected copyous; then
    install_gnome_extension 8834 "copyous@boerdereinar.dev" "Copyous"
  fi
  if is_selected dash_to_panel; then
    install_gnome_extension \
      1160 "dash-to-panel@jderose9.github.com" "Dash to Panel"
  fi
}
