#!/usr/bin/env bash
# inject-config.sh - Inject Zenith dependencies into /etc/nixos/configuration.nix
# without removing any existing packages or configurations.

set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
CONFIG_FILE="${1:-/etc/nixos/configuration.nix}"
TARGET_USER="${2:-${SUDO_USER:-$USER}}"
DO_REBUILD="${3:-1}"

if [ -t 1 ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; OK=$'\e[32m'; WARN=$'\e[33m'; ERR=$'\e[31m'; N=$'\e[0m'
else
    B=""; DIM=""; OK=""; WARN=""; ERR=""; N=""
fi

step() { printf '\n%s▍ %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$OK" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$WARN" "$N" "$*"; }
die()  { printf '\n%sError:%s %s\n' "$ERR" "$N" "$*" >&2; exit 1; }

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

[ -f "$CONFIG_FILE" ] || die "Configuration file not found: $CONFIG_FILE"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${CONFIG_FILE}.bak-${STAMP}"

step "Backing up NixOS configuration"
$SUDO cp "$CONFIG_FILE" "$BACKUP_FILE"
ok "Backup created at $BACKUP_FILE"

step "Copying Zenith Nix theme modules to /etc/nixos/zenith"
$SUDO mkdir -p /etc/nixos/zenith/sddm /etc/nixos/zenith/grub
if [ -d "$SRC/sddm/zenith" ]; then
    $SUDO cp -r "$SRC/sddm/zenith" /etc/nixos/zenith/sddm/
    ok "SDDM theme copied to /etc/nixos/zenith/sddm/zenith"
fi
if [ -d "$SRC/grub/zenith" ]; then
    $SUDO cp -r "$SRC/grub/zenith" /etc/nixos/zenith/grub/
    ok "GRUB theme copied to /etc/nixos/zenith/grub/zenith"
fi
if [ -f "$SRC/nix/sddm-theme.nix" ]; then
    $SUDO cp "$SRC/nix/sddm-theme.nix" /etc/nixos/zenith/
fi
if [ -f "$SRC/nix/grub-theme.nix" ]; then
    $SUDO cp "$SRC/nix/grub-theme.nix" /etc/nixos/zenith/
fi
if [ -f "$SRC/nix/zenith.nix" ]; then
    $SUDO cp "$SRC/nix/zenith.nix" /etc/nixos/zenith.nix
    ok "Zenith module installed at /etc/nixos/zenith.nix"
fi

step "Injecting Zenith dependencies into $CONFIG_FILE"
TMP_CONFIG="$(mktemp)"
perl "$SRC/nix/inject_nixos_config.pl" "$CONFIG_FILE" "$TARGET_USER" > "$TMP_CONFIG"

if [ -s "$TMP_CONFIG" ]; then
    $SUDO cp "$TMP_CONFIG" "$CONFIG_FILE"
    rm -f "$TMP_CONFIG"
    ok "Dependencies and options successfully injected into $CONFIG_FILE (existing packages preserved)"
else
    rm -f "$TMP_CONFIG"
    die "Failed to generate updated configuration file"
fi

# Ensure bridge permissions
$SUDO mkdir -p /var/lib/zenith 2>/dev/null || true
$SUDO chmod 777 /var/lib/zenith 2>/dev/null || true

if [ "$DO_REBUILD" = "1" ]; then
    step "Applying changes with nixos-rebuild switch"
    printf '%sRunning: sudo nixos-rebuild switch%s\n' "$DIM" "$N"
    if $SUDO nixos-rebuild switch; then
        ok "NixOS system successfully rebuilt and updated!"
    else
        warn "nixos-rebuild switch encountered an issue. Check the logs above."
    fi
fi
