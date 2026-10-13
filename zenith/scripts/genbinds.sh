#!/usr/bin/env bash
# Rebuilds ~/.config/hypr/lua/binds_data.lua from settings.json
# and asks Hyprland to re-read the config.
#
# All keys of the form bind_<id> are taken. The value "" means that
# the combination is disabled - keybindings.lua allows them.

CFG="$HOME/.config/zenith/settings.json"
OUT="$HOME/.config/hypr/lua/binds_data.lua"

[ -f "$CFG" ] || exit 1

{
    echo "-- File is generated automatically by the pill settings panel (Super+I)."
    echo "-- Manual edits will be overwritten upon next keybinding change."
    echo "return {"
    jq -r '
        to_entries
        | map(select(.key | startswith("bind_")))
        | sort_by(.key)
        | .[]
        | "    [\"" + (.key | sub("^bind_"; "")) + "\"] = " + (.value | tostring | @json) + ","
    ' "$CFG"
    echo "}"
} > "$OUT"

hyprctl reload >/dev/null 2>&1
