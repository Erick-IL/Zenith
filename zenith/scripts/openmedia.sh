#!/usr/bin/env bash
# Open the picture/video in the pill's media player.
#
# Set by the image/* and video/* handlers (see zenith-media.desktop), so
# “Open” in browser and `xdg-open file.png` lead not to the browser, but here.
# The argument can come as a path or as a file:// URL.

f="$1"
case "$f" in
    file://*)
        # remove the circuit and decode %xx
        f="${f#file://}"
        f=$(printf '%b' "${f//%/\\x}")
        ;;
esac

[ -n "$f" ] || exit 1
exec qs -p "$HOME/.config/zenith" ipc call pill media "$f"
