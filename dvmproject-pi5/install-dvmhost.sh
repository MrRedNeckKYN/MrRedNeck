#!/usr/bin/env bash
# Beginner-safe installer for the official DVMProject dvmhost repository.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=libdvm.sh
source "$SCRIPT_DIR/libdvm.sh"

setup_logging "install"
echo "DVMProject dvmhost installer"
echo "Official source: $DVM_REPOSITORY"
setup_sudo
verify_raspberry_pi_5
install_dependencies
verify_or_clone_source
refresh_source
refuse_running_host
build_and_install

echo
echo "Install complete. No service was created or enabled."
echo "Next: edit $DVM_INSTALL_DIR/config.yml for your radio/network, then start it manually:"
echo "  sudo $DVM_INSTALL_DIR/bin/dvmhost -c $DVM_INSTALL_DIR/config.yml"
echo "Run $SCRIPT_DIR/update-dvmhost.sh later to update from the official $DVM_BRANCH branch."
echo "When your modem and RF configuration are ready, run $SCRIPT_DIR/enable-dvmhost-service.sh to enable boot startup."
