#!/usr/bin/env bash
# Smart window / overlay closer for Super+Q.
# Closes open Zenith overlays first if closeZenithFirst is enabled in settings.

CFG="$HOME/.config/zenith/settings.json"
PREF=1

if [ -f "$CFG" ]; then
    VAL=$(jq -r '.closeZenithFirst // true' "$CFG" 2>/dev/null)
    if [ "$VAL" = "false" ]; then
        PREF=0
    fi
fi

if [ "$PREF" = 1 ]; then
    OUT=$(qs -c "$HOME/.config/zenith" ipc call pill smartClose 2>/dev/null | tr -d '\r\n')
    if echo "$OUT" | grep -q "closed_overlay"; then
        exit 0
    fi
fi

if [ -n "$NIRI_SOCKET" ] || [ "${XDG_CURRENT_DESKTOP,,}" = "niri" ]; then
    niri msg action close-window >/dev/null 2>&1
else
    hyprctl dispatch "hl.dsp.window.close()" >/dev/null 2>&1 || hyprctl dispatch killactive >/dev/null 2>&1
fi
