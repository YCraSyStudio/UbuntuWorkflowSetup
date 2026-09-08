#!/usr/bin/env bash

update_system() {
  log "Actualizar Ubuntu"
  sudo apt update
  sudo apt upgrade -y
}

install_base_packages() {
  log "Instalar herramientas base"
  sudo apt install -y \
    ca-certificates curl git git-lfs gnupg jq snapd unzip

  if is_selected gnome_manager; then
    sudo apt install -y \
      gir1.2-gda-5.0 gir1.2-gsound-1.0 \
      gnome-browser-connector gnome-shell-extension-manager
  fi

  sudo install -m 0755 -d /etc/apt/keyrings /usr/share/keyrings
}

configure_docker_repository() {
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF_DOCKER
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF_DOCKER
}

configure_chrome_repository() {
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/google-chrome.gpg >/dev/null
  sudo tee /etc/apt/sources.list.d/google-chrome.sources >/dev/null <<'EOF_CHROME'
Types: deb
URIs: https://dl.google.com/linux/chrome-stable/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF_CHROME
}

configure_vscode_repository() {
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null
  sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF_VSCODE
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF_VSCODE
}

configure_github_cli_repository() {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo tee /etc/apt/sources.list.d/github-cli.sources >/dev/null <<EOF_GITHUB
Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg
EOF_GITHUB
}

configure_atlassian_cli_repository() {
  curl -fsSL https://acli.atlassian.com/gpg/public-key.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/acli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/acli-archive-keyring.gpg
  sudo tee /etc/apt/sources.list.d/acli.sources >/dev/null <<EOF_ACLI
Types: deb
URIs: https://acli.atlassian.com/linux/deb
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/acli-archive-keyring.gpg
EOF_ACLI
}

configure_unity_repository() {
  curl -fsSL https://hub.unity3d.com/linux/keys/public \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg >/dev/null
  sudo tee /etc/apt/sources.list.d/unityhub.sources >/dev/null <<'EOF_UNITY'
Types: deb
URIs: https://hub.unity3d.com/linux/repos/deb
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/Unity_Technologies_ApS.gpg
EOF_UNITY
}

configure_external_repositories() {
  local repositories_changed=0 architecture

  log "Configurar repositorios seleccionados"
  architecture="$(dpkg --print-architecture)"

  if is_selected docker &&
    { [[ ! -s /etc/apt/sources.list.d/docker.sources ]] ||
      [[ ! -s /etc/apt/keyrings/docker.asc ]]; }; then
    configure_docker_repository
    repositories_changed=1
  fi
  if is_selected chrome &&
    { [[ ! -s /etc/apt/sources.list.d/google-chrome.sources ]] ||
      [[ ! -s /usr/share/keyrings/google-chrome.gpg ]]; }; then
    configure_chrome_repository
    repositories_changed=1
  fi
  if is_selected vscode &&
    { [[ ! -s /etc/apt/sources.list.d/vscode.sources ]] ||
      [[ ! -s /usr/share/keyrings/microsoft.gpg ]] ||
      ! grep -Fxq "Architectures: $architecture" \
        /etc/apt/sources.list.d/vscode.sources; }; then
    configure_vscode_repository
    repositories_changed=1
  fi
  if is_selected github_cli &&
    { [[ ! -s /etc/apt/sources.list.d/github-cli.sources ]] ||
      [[ ! -s /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; }; then
    configure_github_cli_repository
    repositories_changed=1
  fi
  if is_selected atlassian_cli &&
    { [[ ! -s /etc/apt/sources.list.d/acli.sources ]] ||
      [[ ! -s /etc/apt/keyrings/acli-archive-keyring.gpg ]]; }; then
    configure_atlassian_cli_repository
    repositories_changed=1
  fi
  if is_selected unity &&
    { [[ ! -s /etc/apt/sources.list.d/unityhub.sources ]] ||
      [[ ! -s /usr/share/keyrings/Unity_Technologies_ApS.gpg ]]; }; then
    configure_unity_repository
    repositories_changed=1
  fi

  if ((repositories_changed)); then
    sudo apt update
  else
    log "Los repositorios ya estaban configurados"
  fi
}

# En Ubuntu recientes `qemu-kvm` es solo un paquete virtual y `apt` no sabe
# resolverlo solo (No candidate). El proveedor estándar y estable en todas las
# versiones es `qemu-system-x86`; se usa `qemu-system-x86-hwe` como alternativa
# y `qemu-kvm` solo como último recurso. Devuelve el nombre del paquete instalable.
qemu_system_package() {
  local candidate version
  for candidate in qemu-system-x86 qemu-system-x86-hwe qemu-kvm; do
    version="$(apt-cache policy "$candidate" 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
    if [[ -n "$version" && "$version" != "(none)" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf '%s' qemu-system-x86
}

install_selected_packages() {
  local packages=()

  log "Instalar paquetes seleccionados"
  if is_selected docker; then
    packages+=(
      containerd.io docker-buildx-plugin docker-ce docker-ce-cli
      docker-compose-plugin
    )
  fi
  if is_selected dotnet; then packages+=("dotnet-sdk-$DOTNET_VERSION"); fi
  if is_selected chrome; then packages+=(google-chrome-stable); fi
  if is_selected vscode; then packages+=(code); fi
  if is_selected github_cli; then packages+=(gh); fi
  if is_selected atlassian_cli; then packages+=(acli); fi
  if is_selected mysql; then
    packages+=(default-libmysqlclient-dev mysql-client mysql-server)
  fi
  if is_selected postgresql; then
    packages+=(postgresql postgresql-client)
  fi
  if is_selected unity; then packages+=(unityhub); fi
  if is_selected yed; then packages+=(default-jre); fi
  if is_selected qemu; then
    packages+=("$(qemu_system_package)" qemu-utils libvirt-daemon-system libvirt-clients virt-manager)
  fi

  if ((${#packages[@]} > 0)); then
    sudo apt install -y "${packages[@]}"
  fi
}
