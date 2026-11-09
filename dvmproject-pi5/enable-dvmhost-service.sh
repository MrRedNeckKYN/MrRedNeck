#!/usr/bin/env bash
# Enable dvmhost at boot after the radio configuration has been reviewed.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=libdvm.sh
source "$SCRIPT_DIR/libdvm.sh"

setup_logging "enable-service"
echo "DVMProject dvmhost boot-service setup"
setup_sudo
verify_raspberry_pi_5
"${SUDO[@]}" test -x "$DVM_INSTALL_DIR/bin/dvmhost" || die "dvmhost is not installed at $DVM_INSTALL_DIR/bin/dvmhost. Run install-dvmhost.sh first."
"${SUDO[@]}" test -f "$DVM_INSTALL_DIR/config.yml" || die "Missing $DVM_INSTALL_DIR/config.yml. Configure dvmhost first."

echo "Creating or updating the restricted dvmhost service account..."
"${SUDO[@]}" useradd --user-group -M --system dvmhost --shell /bin/false 2>/dev/null || true
"${SUDO[@]}" usermod --groups dialout --append dvmhost
"${SUDO[@]}" chown dvmhost:dvmhost "$DVM_INSTALL_DIR/config.yml"
prepare_runtime_layout
"${SUDO[@]}" chown -R dvmhost:dvmhost "$DVM_INSTALL_DIR/log"
if "${SUDO[@]}" test -f "$DVM_INSTALL_DIR/iden_table.dat"; then
  "${SUDO[@]}" chown dvmhost:dvmhost "$DVM_INSTALL_DIR/iden_table.dat"
  "${SUDO[@]}" chmod 0640 "$DVM_INSTALL_DIR/iden_table.dat"
fi

service_file="/etc/systemd/system/dvmhost.service"
temporary_unit="$(mktemp)"
trap 'rm -f "$temporary_unit"' EXIT
cat >"$temporary_unit" <<'UNIT'
[Unit]
Description=DVMProject Host Radio Service
After=syslog.target network.target

[Service]
User=dvmhost
WorkingDirectory=/opt/dvm
Type=forking
ExecStart=/opt/dvm/bin/dvmhost -c /opt/dvm/config.yml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

if "${SUDO[@]}" test -f "$service_file" && ! "${SUDO[@]}" cmp -s "$temporary_unit" "$service_file"; then
  backup_dir="$DVM_INSTALL_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  "${SUDO[@]}" install -d -m 0700 "$backup_dir"
  "${SUDO[@]}" cp -a "$service_file" "$backup_dir/dvmhost.service"
  echo "Backed up the existing service unit to $backup_dir/dvmhost.service"
fi
"${SUDO[@]}" install -m 0644 "$temporary_unit" "$service_file"
"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" systemctl enable dvmhost.service

echo
echo "dvmhost is enabled for future boots. It was not started now."
echo "After the modem is connected and the RF configuration is reviewed, start it with:"
echo "  sudo systemctl start dvmhost.service"
echo "Check it with: sudo systemctl status dvmhost.service --no-pager"
