#!/usr/bin/env bash
# Shared helpers for the DVMProject dvmhost installer and updater.

set -Eeo pipefail

readonly DVM_REPOSITORY="https://github.com/DVMProject/dvmhost.git"
readonly DVM_BRANCH="${DVM_BRANCH:-master}"
readonly DVM_HOME="${DVM_HOME:-$HOME/dvmproject}"
readonly DVM_SOURCE_DIR="${DVM_SOURCE_DIR:-$DVM_HOME/dvmhost}"
readonly DVM_BUILD_DIR="${DVM_BUILD_DIR:-$DVM_SOURCE_DIR/build}"
readonly DVM_INSTALL_DIR="${DVM_INSTALL_DIR:-/opt/dvm}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  echo "ERROR: stopped at line $1 (exit code $exit_code)." >&2
  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

setup_logging() {
  local log_dir="$DVM_HOME/logs"
  mkdir -p "$log_dir"
  local log_file="$log_dir/${1}-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$log_file") 2>&1
  echo "Log: $log_file"
}

setup_sudo() {
  if [[ $EUID -eq 0 ]]; then
    SUDO=()
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required; run this as a user with sudo access."
    SUDO=(sudo)
  fi
}

verify_raspberry_pi_5() {
  [[ -r /etc/os-release ]] || die "This does not look like Raspberry Pi OS (/etc/os-release is missing)."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "raspbian" ]] || die "This script is for Raspberry Pi OS (found: ${PRETTY_NAME:-unknown})."

  local model architecture
  model="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
  architecture="$(uname -m)"
  [[ "$model" == *"Raspberry Pi 5"* ]] || die "This script is for a Raspberry Pi 5 (found: ${model:-unknown})."
  case "$architecture" in
    aarch64|armv7l) ;;
    *) die "Unsupported CPU architecture: $architecture. Expected 64-bit (aarch64) or 32-bit (armv7l) Raspberry Pi OS." ;;
  esac

  echo "Verified: $model; Raspberry Pi OS; architecture $architecture."
}

install_dependencies() {
  echo "Installing only the build tools and libraries required by dvmhost..."
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake git libasio-dev libncurses-dev libssl-dev
}

verify_dependencies() {
  local package
  local missing=()
  for package in build-essential cmake git libasio-dev libncurses-dev libssl-dev; do
    if ! dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
      missing+=("$package")
    fi
  done
  ((${#missing[@]} == 0)) || die "Required build packages are missing: ${missing[*]}. Run install-dvmhost.sh once."
}

verify_or_clone_source() {
  if [[ -e "$DVM_SOURCE_DIR" ]]; then
    [[ -d "$DVM_SOURCE_DIR/.git" ]] || die "$DVM_SOURCE_DIR exists but is not a Git checkout; choose another DVM_SOURCE_DIR."
    local origin
    origin="$(git -C "$DVM_SOURCE_DIR" config --get remote.origin.url || true)"
    [[ "$origin" == "$DVM_REPOSITORY" ]] || die "Refusing to use an unexpected source remote: ${origin:-none}."
  else
    mkdir -p "$(dirname "$DVM_SOURCE_DIR")"
    echo "Cloning the official DVMProject dvmhost source..."
    git clone --branch "$DVM_BRANCH" "$DVM_REPOSITORY" "$DVM_SOURCE_DIR"
  fi
}

refresh_source() {
  [[ -d "$DVM_SOURCE_DIR/.git" ]] || die "Source checkout not found at $DVM_SOURCE_DIR. Run install-dvmhost.sh first."
  local origin
  origin="$(git -C "$DVM_SOURCE_DIR" config --get remote.origin.url || true)"
  [[ "$origin" == "$DVM_REPOSITORY" ]] || die "Refusing to update an unexpected source remote: ${origin:-none}."
  [[ -z "$(git -C "$DVM_SOURCE_DIR" status --porcelain)" ]] || die "Source checkout has local changes; resolve or move them before updating."

  echo "Checking the official $DVM_BRANCH branch for updates..."
  git -C "$DVM_SOURCE_DIR" fetch --prune origin "$DVM_BRANCH"
  git -C "$DVM_SOURCE_DIR" checkout "$DVM_BRANCH"
  git -C "$DVM_SOURCE_DIR" merge --ff-only "origin/$DVM_BRANCH"
  echo "Source revision: $(git -C "$DVM_SOURCE_DIR" rev-parse --short HEAD)"
}

refuse_running_host() {
  if pgrep -x dvmhost >/dev/null 2>&1; then
    die "dvmhost is running. Stop it first (for example: sudo systemctl stop dvmhost), then run this script again."
  fi
}

build_and_install() {
  echo "Configuring a native $DVM_BRANCH build..."
  cmake -S "$DVM_SOURCE_DIR" -B "$DVM_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
  echo "Building dvmhost..."
  cmake --build "$DVM_BUILD_DIR" --parallel "$(nproc)"

  if "${SUDO[@]}" test -f "$DVM_INSTALL_DIR/config.yml"; then
    local backup_dir
    backup_dir="$DVM_INSTALL_DIR/backups/$(date +%Y%m%d-%H%M%S)"
    "${SUDO[@]}" install -d -m 0700 "$backup_dir"
    "${SUDO[@]}" cp -a "$DVM_INSTALL_DIR/config.yml" "$backup_dir/config.yml"
    echo "Backed up your active configuration to $backup_dir/config.yml"
  fi

  echo "Installing binaries and upstream example files to $DVM_INSTALL_DIR..."
  "${SUDO[@]}" cmake --build "$DVM_BUILD_DIR" --target old_install

  if ! "${SUDO[@]}" test -f "$DVM_INSTALL_DIR/config.yml"; then
    "${SUDO[@]}" install -m 0600 "$DVM_INSTALL_DIR/config.example.yml" "$DVM_INSTALL_DIR/config.yml"
    echo "Created $DVM_INSTALL_DIR/config.yml from the official example. Edit it before starting dvmhost."
  else
    echo "Kept your existing $DVM_INSTALL_DIR/config.yml unchanged."
  fi
}
