#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/envChecks.sh
source "$SCRIPT_DIR/src/envChecks.sh"
check_environment
# shellcheck source=src/common.sh
source "$SCRIPT_DIR/src/common.sh"
# shellcheck source=src/selector.sh
source "$SCRIPT_DIR/src/selector.sh"
# shellcheck source=src/packages.sh
source "$SCRIPT_DIR/src/packages.sh"
# shellcheck source=src/apps.sh
source "$SCRIPT_DIR/src/apps.sh"
# shellcheck source=src/node.sh
source "$SCRIPT_DIR/src/node.sh"
# shellcheck source=src/extensions.sh
source "$SCRIPT_DIR/src/extensions.sh"
# shellcheck source=src/cleanup.sh
source "$SCRIPT_DIR/src/cleanup.sh"

sudo -v
select_apps

update_system
cleanup_preinstalled_apps
install_base_packages
configure_external_repositories
install_selected_packages
install_selected_apps
install_node_tools
install_chatgpt
install_yed
install_gnome_extensions
configure_services
cleanup_system
print_versions
print_manual_steps
offer_reboot
