#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
export SIM_HOME="$sandbox/home" SIM_TRACE="$sandbox/commands"
export TMPDIR="$sandbox/tmp"
export USER="$(id -un)"
unset SUDO_USER NODE_VERSION NVM_VERSION NPM_MAJOR_VERSION ANGULAR_MAJOR_VERSION
unset NCU_MAJOR_VERSION DOTNET_VERSION YED_VERSION YED_ARCHIVE_URL
mkdir -p "$SIM_HOME" "$TMPDIR" "$sandbox/bin"
export HOME="$SIM_HOME"
export PATH="$sandbox/bin:$PATH"

cat > "$sandbox/bin/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

tool="${0##*/}"
printf '%s %s\n' "$tool" "$*" >> "$SIM_TRACE"
case "$tool" in
  sudo)
    case "$1" in
      tee) cat ;;
      -v|apt|snap|install|curl|chmod|usermod) ;;
      systemctl) [[ "$2" == enable ]] ;;
      *) exit 1 ;;
    esac
    ;;
  getent) printf '%s:x:%s:%s::%s:/bin/bash\n' "$USER" "$(id -u)" "$(id -g)" "$SIM_HOME" ;;
  dpkg-query|snap) exit 1 ;;
  apt-cache) printf '  Candidate: 1\n' ;;
  gpg) cat ;;
  curl)
    case "$*" in
      *raw.githubusercontent.com/nvm-sh/nvm/*)
        cat <<'INSTALL_NVM'
mkdir -p "$SIM_HOME/.nvm"
cat > "$SIM_HOME/.nvm/nvm.sh" <<'NVM'
nvm() {
  printf 'nvm %s\n' "$*" >> "$SIM_TRACE"
}
NVM
INSTALL_NVM
        ;;
      *pk=8834*) echo '{"uuid":"copyous@boerdereinar.dev","download_url":"/mock.zip"}' ;;
      *pk=1160*) echo '{"uuid":"dash-to-panel@jderose9.github.com","download_url":"/mock.zip"}' ;;
      *)
        while (($#)); do
          if [[ "$1" == -o ]]; then
            touch "$2"
            break
          fi
          shift
        done
        ;;
    esac
    ;;
  unzip)
    mkdir -p "$4/yed-3.25.1"
    touch "$4/yed-3.25.1/yed.jar"
    ;;
  npm)
    case "$1" in
      --version) echo 11.0.0 ;;
      root) echo "$SIM_HOME/npm" ;;
      install) ;;
      *) exit 1 ;;
    esac
    ;;
  node)
    if [[ "$1" == --version ]]; then echo v26.13.0; fi
    ;;
  gnome-shell) echo 'GNOME Shell 46.0' ;;
  git|dotnet|gnome-extensions|update-desktop-database) ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$sandbox/bin/mock"
for tool in sudo getent dpkg-query snap apt-cache gpg curl unzip npm node \
    git gnome-shell dotnet gnome-extensions update-desktop-database; do
  ln -s mock "$sandbox/bin/$tool"
done

bash main.sh <<< 'N'

for expected in \
    'sudo apt install -y libatomic1' \
    'nvm install 26' \
    'nvm alias default 26' \
    'npm install -g npm@12' \
    'npm install -g @angular/cli@22' \
    'npm install -g npm-check-updates@23' \
    'sudo snap install bruno' \
    'sudo systemctl enable --now docker' \
    'gnome-extensions enable copyous@boerdereinar.dev' \
    'gnome-extensions enable dash-to-panel@jderose9.github.com'; do
  if ! grep -Fxq "$expected" "$SIM_TRACE"; then
    printf 'No se registró el comando esperado: %s\n' "$expected" >&2
    cat "$SIM_TRACE" >&2
    exit 1
  fi
done

grep -Fq 'nvm-sh/nvm/v0.40.8/install.sh' "$SIM_TRACE"
grep -Eq 'sudo apt install -y .*/chatgpt_(amd64|arm64)\.deb$' "$SIM_TRACE"
test -x "$SIM_HOME/.local/bin/yed"
