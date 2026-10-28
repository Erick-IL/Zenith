#!/usr/bin/env bash
# Launching the lock screen (lock.qml).
#
# The background is also prepared here: the theme’s wallpaper, compressed under the screen and cached.
# QML itself reads the path from ZENITH_LOCK_BG.

DIR="$(dirname "$(readlink -f "$0")")"
QML="$DIR/../lock.qml"

# Last run trace. The lock is called from the panel, where nothing is visible
# output, no return code: if it didn’t work, there’s no other way to figure it out
# what. There is only one file and is rewritten with each launch - this is not a log, but
# mark “as far as we reached last time.”
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/lock.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null
step() { printf '%s %s\n' "$(date +%H:%M:%S)" "$1" >> "$LOG"; }
: > "$LOG" 2>/dev/null
step "launch, PATH=$PATH"

# already blocked - no need for a second copy
if pgrep -f "quickshell --path .*lock\.qml" >/dev/null; then
    step "already locked — exiting"
    exit 0
fi

wallpaper=$(grep -m1 '^\$wallpaper' "$HOME/.config/hypr/wallpaper.conf" 2>/dev/null \
            | cut -d= -f2- | sed 's/^ *//; s/ *$//')
wallpaper="${wallpaper/#\~/$HOME}"

if [ -n "$wallpaper" ] && [ "$wallpaper" != "black" ] && [ -f "$wallpaper" ]; then
    bg=$("$DIR/thumbs.sh" lockbg "$wallpaper" 2>/dev/null)
    [ -n "$bg" ] && export ZENITH_LOCK_BG="$bg"
fi
step "background ready: ${ZENITH_LOCK_BG:-none}"
command -v quickshell >/dev/null 2>&1 || step "quickshell not found in PATH"

# The same threaded cycle as the pill: with the NVIDIA Qt driver it chooses
# “basic”, and it spins animations from a timer of 16 ms - 60 frames on any
# monitor. This is especially noticeable on the lock screen: everything there is based on
# smoothness of appearance.
export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-threaded}"

step "launching $QML"
exec quickshell --path "$QML" 2>>"$LOG"
