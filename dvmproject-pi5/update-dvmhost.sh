#!/usr/bin/env bash
# Safe updater for an installation made by install-dvmhost.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=libdvm.sh
source "$SCRIPT_DIR/libdvm.sh"

setup_logging "update"
echo "DVMProject dvmhost updater"
echo "Official source: $DVM_REPOSITORY"
setup_sudo
verify_raspberry_pi_5
verify_dependencies
refresh_source
refuse_running_host
build_and_install

echo
echo "Update complete. Your active configuration was not changed."
echo "If you use your own systemd unit, start it only after reviewing the new release notes and configuration examples."
