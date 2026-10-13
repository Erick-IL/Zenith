#!/usr/bin/env bash
# Other operating systems on this machine and one-time boot into them.
#
#   bootos.sh list - list of systems: id|name|type
#   bootos.sh boot <id> - next boot into this system, then reboot
#                           (you need root, so you call it via pkexec)
#
# One-time, not permanent: The default system does not change.
# Once you boot into Windows, the next reboot will lead you here again.
# Otherwise, the choice from the launcher would silently rearrange the bootloader, and the person would recognize
# more about this in a week.
#
# There can be any number of systems: the list knows nothing about Windows and does not
# limited to two points. Where does it come from:
#
#   1. GRUB. The points that os-prober made are exactly “foreign systems”:
#      GRUB generates its own with other scripts and labels them differently. Download via
#      grub-reboot, a standard one-time selection mechanism.
#   2. If GRUB is not installed, EFI entries in NVRAM and BootNext. Works with anyone
#      bootloader, but what names were asked there, and there is more garbage, so
#      This is a backup route, not the main one.
set -u

GRUB_CFG=""
for c in /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/*/grub.cfg; do
    [ -f "$c" ] && { GRUB_CFG="$c"; break; }
done

# The name is for the person, not the bootloader.
#
# os-prober and firmware name the systems as written inside them:
# "Windows Boot Manager (on /dev/nvme0n1p1)." The section is chosen not with the eyes, but
# “Boot Manager” is about the bootloader, while choosing the system. Distributions
# at the same time, you cannot touch it: “Ubuntu 24.04 LTS” without the version will become worse, not
# better, so we cut off only the obviously useful tails.
pretty_name() {
    printf '%s' "$1" \
        | sed 's/ (on \/dev\/[^)]*)//' \
        | sed 's/ *Boot Manager$//; s/ *Bootloader$//' \
        | sed 's/^ *//; s/ *$//'
}

grub_cmd() {
    for g in grub-reboot grub2-reboot; do
        command -v "$g" >/dev/null 2>&1 && { echo "$g"; return 0; }
    done
    return 1
}

# ------------------------------------------------------------------ list
list_grub() {
    [ -n "$GRUB_CFG" ] || return 1
    grub_cmd >/dev/null || return 1

    # The title in quotes and the osprober-* identifier are on the same line.
    # We take the view from --class: it is assigned to os-prober according to the found system.
    grep -oE "menuentry '[^']*'[^{]*osprober-[a-zA-Z0-9._-]*" "$GRUB_CFG" 2>/dev/null |
    while IFS= read -r line; do
        title=$(printf '%s' "$line" | sed -n "s/^menuentry '\([^']*\)'.*/\1/p")
        id=$(printf '%s' "$line" | grep -oE 'osprober-[a-zA-Z0-9._-]*')
        [ -n "$title" ] && [ -n "$id" ] || continue

        kind=other
        case "$line" in
            *--class\ windows*) kind=windows ;;
            *--class\ macosx*|*--class\ osx*) kind=mac ;;
            *--class\ gnu-linux*|*--class\ linux*) kind=linux ;;
        esac

        printf '%s|%s|%s\n' "$id" "$(pretty_name "$title")" "$kind"
    done
}

list_efi() {
    command -v efibootmgr >/dev/null 2>&1 || return 1
    local out; out="$(efibootmgr -v 2>/dev/null)" || return 1
    local current; current="$(printf '%s' "$out" | sed -n 's/^BootCurrent: *//p')"

    printf '%s\n' "$out" | grep -E '^Boot[0-9A-Fa-f]{4}\*' |
    while IFS= read -r line; do
        num=$(printf '%s' "$line" | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*.*/\1/p')
        [ "$num" = "$current" ] && continue          # it's us
        name=$(printf '%s' "$line" | sed -n 's/^Boot[0-9A-Fa-f]\{4\}\*[[:space:]]*//p' \
               | sed 's/\t.*//')

        # Removable media and bootloader records are not systems.
        case "$name" in
            "UEFI: "*|"UEFI OS"|GRUB|grub|rEFInd|systemd-bootx64*) continue ;;
        esac
        case "$line" in *USB\(*) continue ;; esac
        [ -n "$name" ] || continue

        kind=other
        case "$line" in
            *bootmgfw.efi*|*Microsoft*) kind=windows ;;
            *Apple*|*System\\Library*)  kind=mac ;;
            *vmlinuz*|*linux*|*Linux*)  kind=linux ;;
        esac
        printf 'efi:%s|%s|%s\n' "$num" "$(pretty_name "$name")" "$kind"
    done
}

# ------------------------------------------------------------------ launch
boot_into() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "no id" >&2; return 1; }

    case "$id" in
        efi:*)
            command -v efibootmgr >/dev/null 2>&1 || { echo "no efibootmgr" >&2; return 1; }
            efibootmgr --bootnext "${id#efi:}" >/dev/null 2>&1 \
                || { echo "bootnext failed" >&2; return 1; }
            ;;
        *)
            local g; g="$(grub_cmd)" || { echo "no grub-reboot" >&2; return 1; }
            "$g" "$id" >/dev/null 2>&1 || { echo "grub-reboot failed" >&2; return 1; }
            ;;
    esac

    # We reboot in a separate step and only after the choice
    # signed up: if the recording fails, the car remains here and does not leave
    # into a reboot to return to the same place without explanation.
    systemctl reboot
}

case "${1:-list}" in
    list)
        out="$(list_grub)"
        [ -n "$out" ] || out="$(list_efi)"
        printf '%s' "$out" | grep -v '^$' || true
        ;;
    boot) boot_into "${2:-}" ;;
    *) echo "usage: bootos.sh list|boot <id>" >&2; exit 1 ;;
esac
