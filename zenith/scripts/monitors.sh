#!/usr/bin/env bash
# Screens: List of monitors and overwrite ~/.config/hypr/monitors.conf.
#
#   list -> JSON from hyprctl, including disabled monitors and all
#                       available modes of each
#   apply "<lines>" -> puts ready-made monitor=… lines into monitors.conf
#                       and asks Hyprland to re-read the config
#   reset -> returns automatic layout
#
# The settings panel collects the strings: it knows both the modes and the selected layout,
# and the script can only write and reload. Through a file, not hyprctl keyword,
# because otherwise the setting was lost during the next reload.

OUT="$HOME/.config/hypr/monitors.conf"

HEAD="# Файл создаётся автоматически панелью настроек пилюли (Super+I → Экран).
# Manual edits will be erased the next time you “Apply.”

# The last line is for monitors that the panel does not know: they will turn on
# themselves, and will not remain black until you go into the settings.
TAIL="monitor=,preferred,auto,1.0"

case "$1" in
list)
    hyprctl -j monitors all
    ;;

apply)
    [ -n "$2" ] || exit 1
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n%s\n%s\n' "$HEAD" "$2" "$TAIL" > "$OUT" || exit 1
    hyprctl reload >/dev/null 2>&1
    ;;

reset)
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n%s\n' "$HEAD" "$TAIL" > "$OUT" || exit 1
    hyprctl reload >/dev/null 2>&1
    ;;

*)
    echo "usage: monitors.sh list|apply <lines>|reset" >&2
    exit 2
    ;;
esac
