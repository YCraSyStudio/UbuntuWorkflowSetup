#!/usr/bin/env bash

install_chatgpt() {
  local architecture package_dir package_file download_url

  if ! is_selected chatgpt; then return; fi

  if dpkg-query -W -f='${Status}' chatgpt 2>/dev/null | grep -qx 'install ok installed'; then
    log "ChatGPT ya está instalado"
    return
  fi

  architecture="$(dpkg --print-architecture)"
  case "$architecture" in
    amd64 | arm64) ;;
    *)
      printf 'ChatGPT no admite la arquitectura %s.\n' "$architecture" >&2
      return 1
      ;;
  esac

  # Paquetes oficiales: https://learn.chatgpt.com/docs/linux/linux-app
  download_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_${architecture}.deb"
  package_dir="$(mktemp -d)"
  package_file="$package_dir/chatgpt_${architecture}.deb"
  log "Descargar e instalar ChatGPT"
  if ! curl -fsSL "$download_url" -o "$package_file"; then
    rm -f "$package_file"
    rmdir "$package_dir"
    return 1
  fi

  # Permitir que el usuario _apt lea el paquete descargado.
  chmod 0755 "$package_dir"
  chmod 0644 "$package_file"
  if ! sudo apt install -y "$package_file"; then
    rm -f "$package_file"
    rmdir "$package_dir"
    return 1
  fi
  rm -f "$package_file"
  rmdir "$package_dir"
}

install_yed() {
  local archive install_root install_dir launcher desktop_file

  if ! is_selected yed; then return; fi

  install_root="$USER_HOME/.local/opt"
  install_dir="$install_root/yed-$YED_VERSION"
  launcher="$USER_HOME/.local/bin/yed"
  desktop_file="$USER_HOME/.local/share/applications/yed.desktop"
  run_as_user install -d \
    "$install_root" "$USER_HOME/.local/bin" \
    "$USER_HOME/.local/share/applications"

  if [[ ! -f "$install_dir/yed.jar" ]]; then
    log "Descargar e instalar yEd ${YED_VERSION}"
    archive="$(mktemp --suffix=_yed.zip)"
    if ! curl -fsSL "$YED_ARCHIVE_URL" -o "$archive"; then
      rm -f "$archive"
      return 1
    fi

    if ! run_as_user unzip -oq "$archive" -d "$install_root"; then
      rm -f "$archive"
      return 1
    fi
    rm -f "$archive"
  else
    log "yEd ${YED_VERSION} ya está instalado"
  fi

  if [[ ! -f "$install_dir/yed.jar" ]]; then
    printf 'El paquete de yEd no contiene el archivo esperado: %s\n' \
      "$install_dir/yed.jar" >&2
    return 1
  fi

  run_as_user tee "$launcher" >/dev/null <<EOF_LAUNCHER
#!/usr/bin/env bash
exec java -jar "$install_dir/yed.jar" "\$@"
EOF_LAUNCHER
  run_as_user chmod 0755 "$launcher"

  run_as_user tee "$desktop_file" >/dev/null <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=yEd Graph Editor
Comment=Create and edit diagrams
Exec=$launcher %F
Icon=$install_dir/icons/yed128.png
Terminal=false
Categories=Graphics;Office;
MimeType=application/x-yed;
StartupNotify=true
EOF_DESKTOP

  run_as_user update-desktop-database "$USER_HOME/.local/share/applications" \
    >/dev/null 2>&1 || true
  log "yEd ${YED_VERSION} instalado correctamente"
}

install_snap_if_missing() {
  local package="$1"
  shift

  if snap list "$package" >/dev/null 2>&1; then
    log "$package ya está instalado"
  else
    sudo snap install "$package" "$@"
  fi
}

install_selected_apps() {
  if is_selected chromium; then install_snap_if_missing chromium; fi
  if is_selected telegram; then install_snap_if_missing telegram-desktop; fi
  if is_selected dbeaver; then install_snap_if_missing dbeaver-ce --classic; fi
  if is_selected bruno; then install_snap_if_missing bruno; fi
}
