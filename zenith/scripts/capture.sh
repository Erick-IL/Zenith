#!/usr/bin/env bash
# Temporarily disables Hyprland hotkeys so that the settings panel
# caught the entire click, but did not receive the triggered action.
#
#   on -> go to submap "capture": it is declared empty in keybindings.lua,
#          so all the keys go to the application.
#   off -> return to normal mode.
#
# The Hyprland config here is in Lua, so dispatch accepts a Lua call.

case "$1" in
    on)
        hyprctl dispatch 'hl.dsp.submap("capture")' >/dev/null
        ;;
    off)
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
        qs -c "$HOME/.config/zenith" ipc call pill cancelCapture 2>/dev/null
        ;;
    *)
        echo "usage: capture.sh on|off" >&2
        exit 1
        ;;
esac
