#!/usr/bin/env bash

install_node_tools() {
  if ! is_selected node; then return; fi

  log "Instalar Node.js ${NODE_VERSION} y herramientas JavaScript"
  if ! run_as_user bash -c '
    nvm_script="$1/.nvm/nvm.sh"
    [[ -s "$nvm_script" ]] || exit 1
    source "$nvm_script" --no-use
    [[ "$(nvm --version)" == "${2#v}" ]]
  ' bash "$USER_HOME" "$NVM_VERSION"; then
    run_as_user bash -o pipefail -c '
      curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$1/install.sh" | bash
    ' bash "$NVM_VERSION"
  fi

  run_as_user env \
    USER_HOME="$USER_HOME" NODE_VERSION="$NODE_VERSION" \
    NPM_MAJOR_VERSION="$NPM_MAJOR_VERSION" \
    ANGULAR_MAJOR_VERSION="$ANGULAR_MAJOR_VERSION" \
    NCU_MAJOR_VERSION="$NCU_MAJOR_VERSION" \
    INSTALL_NPM="${SELECTED_APPS[npm]}" \
    INSTALL_ANGULAR="${SELECTED_APPS[angular]}" \
    INSTALL_NCU="${SELECTED_APPS[ncu]}" bash <<'EOF_NODE'
export NVM_DIR="$USER_HOME/.nvm"
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION" || exit $?
nvm alias default "$NODE_VERSION" || exit $?

global_package_version() {
  local package="$1"
  local package_root
  package_root="$(npm root -g)"
  node -e \
    'try { console.log(require(process.argv[1]).version) } catch (_) {}' \
    "$package_root/$package/package.json"
}

if [[ "$INSTALL_NPM" == 1 && "$(npm --version)" != "$NPM_MAJOR_VERSION".* ]]; then
  npm install -g "npm@$NPM_MAJOR_VERSION"
fi
if [[ "$INSTALL_ANGULAR" == 1 &&
  "$(global_package_version @angular/cli)" != "$ANGULAR_MAJOR_VERSION".* ]]; then
  npm install -g "@angular/cli@$ANGULAR_MAJOR_VERSION"
fi
if [[ "$INSTALL_NCU" == 1 &&
  "$(global_package_version npm-check-updates)" != "$NCU_MAJOR_VERSION".* ]]; then
  npm install -g "npm-check-updates@$NCU_MAJOR_VERSION"
fi
EOF_NODE
}
