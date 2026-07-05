#!/usr/bin/env bash

cleanup_preinstalled_apps() {
  local package
  local installed_packages=()

  log "Eliminar aplicaciones preinstaladas no deseadas"
  if command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
    sudo snap remove --purge firefox
  fi

  for package in \
    firefox gnome-user-docs vim vim-common vim-runtime vim-tiny yelp; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii'; then
      installed_packages+=("$package")
    fi
  done
  if ((${#installed_packages[@]} > 0)); then
    sudo apt purge -y "${installed_packages[@]}"
  else
    log "No hay aplicaciones preinstaladas que eliminar"
  fi
}

configure_services() {
  log "Configurar servicios"
  run_as_user git lfs install --skip-repo
  if is_selected docker; then
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER_NAME"
  fi
  if is_selected mysql; then sudo systemctl enable --now mysql; fi
}

cleanup_system() {
  log "Limpiar paquetes innecesarios"
  sudo apt autoremove --purge -y
  sudo apt autoclean -y
}

print_dpkg_version() {
  local label="$1"
  local package="$2"
  local version

  version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
  printf '  %-24s %s\n' "$label" "${version:-no detectada}"
}

print_snap_version() {
  local label="$1"
  local package="$2"
  local version

  version="$(snap list "$package" 2>/dev/null | awk 'NR == 2 { print $2 }' || true)"
  printf '  %-24s %s\n' "$label" "${version:-no detectada}"
}

print_extension_version() {
  local label="$1"
  local uuid="$2"
  local metadata="$USER_HOME/.local/share/gnome-shell/extensions/$uuid/metadata.json"
  local version="" display="no detectada"

  if [[ -f "$metadata" ]]; then
    version="$(jq -r '.version // empty' "$metadata")"
  fi
  if [[ -n "$version" ]]; then display="v$version"; fi
  printf '  %-24s %s\n' "$label" "$display"
}

print_versions() {
  log "Versiones instaladas"
  if is_selected docker; then print_dpkg_version "Docker" docker-ce; fi
  if is_selected dotnet; then
    printf '  %-24s %s\n' ".NET SDK" "$(dotnet --version 2>/dev/null || true)"
  fi
  if is_selected mysql; then print_dpkg_version "MySQL" mysql-server; fi
  if is_selected unity; then print_dpkg_version "Unity Hub" unityhub; fi
  if is_selected vscode; then print_dpkg_version "Visual Studio Code" code; fi
  if is_selected github_cli; then print_dpkg_version "GitHub CLI" gh; fi
  if is_selected atlassian_cli; then print_dpkg_version "Atlassian CLI" acli; fi
  if is_selected dbeaver; then print_snap_version "DBeaver" dbeaver-ce; fi
  if is_selected chromium; then print_snap_version "Chromium" chromium; fi
  if is_selected chrome; then print_dpkg_version "Google Chrome" google-chrome-stable; fi
  if is_selected telegram; then print_snap_version "Telegram Desktop" telegram-desktop; fi
  if is_selected node; then
    run_as_user env USER_HOME="$USER_HOME" \
      SHOW_NPM="${SELECTED_APPS[npm]}" \
      SHOW_ANGULAR="${SELECTED_APPS[angular]}" \
      SHOW_NCU="${SELECTED_APPS[ncu]}" bash <<'EOF_VERSIONS'
export NVM_DIR="$USER_HOME/.nvm"
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
global_package_version() {
  local package="$1"
  local package_root
  package_root="$(npm root -g)"
  node -e \
    'try { console.log(require(process.argv[1]).version) } catch (_) {}' \
    "$package_root/$package/package.json"
}
printf '  %-24s %s\n' "Node.js" "$(node --version)"
if [[ "$SHOW_NPM" == 1 ]]; then
  printf '  %-24s %s\n' "npm" "$(npm --version)"
fi
if [[ "$SHOW_ANGULAR" == 1 ]]; then
  printf '  %-24s %s\n' "Angular CLI" "$(global_package_version @angular/cli)"
fi
if [[ "$SHOW_NCU" == 1 ]]; then
  printf '  %-24s %s\n' "npm-check-updates" \
    "$(global_package_version npm-check-updates)"
fi
EOF_VERSIONS
  fi
  if is_selected codex; then
    printf '  %-24s %s\n' "Codex CLI" \
      "$("$USER_HOME/.local/bin/codex" --version 2>/dev/null || true)"
  fi
  if is_selected yed; then printf '  %-24s v%s\n' "yEd" "$YED_VERSION"; fi
  if is_selected gnome_manager; then
    print_dpkg_version "Extension Manager" gnome-shell-extension-manager
  fi
  if is_selected copyous; then
    print_extension_version "Copyous" "copyous@boerdereinar.dev"
  fi
  if is_selected dash_to_panel; then
    print_extension_version "Dash to Panel" "dash-to-panel@jderose9.github.com"
  fi
}

print_manual_steps() {
  log "Instalación terminada"
  if is_selected docker || is_selected copyous || is_selected dash_to_panel; then
    manual_step "Cierra sesión para aplicar el grupo de Docker y las extensiones GNOME."
  fi
  if is_selected copyous || is_selected dash_to_panel; then
    manual_step "Comprueba en Extension Manager que las extensiones estén activas."
  fi
  if is_selected vscode; then
    manual_step "Inicia sesión en VS Code para sincronizar la configuración."
  fi
  if is_selected codex; then
    manual_step "Ejecuta codex --version para comprobar Codex CLI."
  fi
  if is_selected unity; then
    manual_step "Instala manualmente el editor desde Unity Hub."
  fi
}

offer_reboot() {
  local answer

  printf '\n***********************************************************************'
  printf '\nAntes de reiniciar, guarda todo el trabajo que tengas abierto.'
  printf '\n***********************************************************************'
  printf '\n'
  if read -r -p '¿Quieres reiniciar el equipo ahora? [s/N] ' answer; then
    case "$answer" in
      s | S | y | Y | si | sí | SI | SÍ | yes | YES)
        log "Reiniciar el equipo"
        sudo systemctl reboot
        ;;
      *)
        log "No se reiniciará el equipo"
        ;;
    esac
  fi
}
