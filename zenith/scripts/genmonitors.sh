#!/usr/bin/env bash
# Rebuilds ~/.config/hypr/lua/monitors_data.lua from settings.json.
#
# Why a separate file if the shell can already apply screen settings
# via hyprctl: it does this ~400 ms after it starts, and before that
# The monitor is in "preferred" mode. HDMI preferred mode is often
# It turns out 1920x1080@60, even if the panel can do 144.
#
# Qt binds the animation timer to the update rate once, when creating
# first window. The shell starts before 144 Hz arrives - and until the end
# session spins animations at 60 Hz, although the monitor switched a long time ago. From the outside
# it looks like “after reboot the island twitches, after restart
# shells - no."
#
# Therefore, the mode must be set before the shell starts, that is, in the config
# linker. The format is the same as binds_data.lua: the file is created from here,
# monitors.lua reads it, but there is no file - “preferred” is taken.
set -u

CFG="$HOME/.config/panacea/settings.json"
OUT="$HOME/.config/hypr/lua/monitors_data.lua"

[ -f "$CFG" ] || exit 1
command -v jq >/dev/null 2>&1 || exit 1

# monOverrides is a string with JSON inside: {"HDMI-A-1":{"w":..,"h":..,"rr":..}}
raw="$(jq -r '.monOverrides // ""' "$CFG")"
[ -n "$raw" ] && [ "$raw" != "null" ] || exit 0

mkdir -p "$(dirname "$OUT")"
tmp="$OUT.new"

{
    echo "-- File is generated automatically: panacea/scripts/genmonitors.sh"
    echo "-- Manual edits will be overwritten upon next display settings change."
    echo "return {"
    printf '%s' "$raw" | jq -r '
        to_entries[]
        | "    { output = \"" + .key + "\""
        + ", mode = \"" + (.value.w|tostring) + "x" + (.value.h|tostring)
        + "@" + ((.value.rr|tonumber) | tostring) + "\""
        + ", position = \"" + (.value.pos // "auto") + "\""
        + ", scale = " + ((.value.scale // 1) | tostring)
        + ", transform = " + ((.value.transform // 0) | tostring)
        + ", vrr = " + (if .value.vrr then "1" else "0" end)
        + (if .value.mirror and .value.mirror != "" and .value.mirror != "none" then ", mirror = \"" + .value.mirror + "\"" else "" end)
        + " },"
    ' 2>/dev/null
    echo "}"
} > "$tmp"

# An empty list means jq did not parse the string: then it is better to remain without
# file and with "preferred", rather than slipping an empty table into the linker.
if grep -q "^    {" "$tmp"; then
    mv -f "$tmp" "$OUT"
else
    rm -f "$tmp"
fi
