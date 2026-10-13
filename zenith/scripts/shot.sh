#!/usr/bin/env bash
# Screenshot of the area using a still frame. Super+Shift+S.
#
# Previously there was `grim -g "$(slurp)" - | wl-copy`: selection was live
# screen. Remove something that closes at the first movement of the mouse - an open menu,
# pop-up hint, auto-completion list - you can’t do that: while you’re dragging
# frame, there is nothing left to remove.
#
# Therefore, first a screenshot of the entire screen, then it is shown as a shell layer
# on top of everything (ipc freeze), and only it is selected.
#
# The area is cut from the same file, and not removed by a second call to grim with
# frozen screen: the second shot would again go through the composer, and the colors
# would depend on what he does with the output - night temperature,
# saturation, dither. We cut the original frame - it ends up in the buffer exactly
# the way it was filmed.
#
# The snapshot is stored in PPM: it is read only by the freeze frame layer and the cropping layer, both
# right away - there is no need to compress and decompress PNG for the sake of a temporary file, and the layer is also
# appears noticeably faster.
#
# If the shell does not respond, the selection goes on the live screen, as before.
# Being left without a freeze frame is better than being left without a screenshot.

set -u

CFG="$HOME/.config/zenith"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
SHOT=""
FROZEN=0

ipc() { qs -c "$CFG" ipc call pill "$@" >/dev/null 2>&1; }

# It is necessary to remove the layer: otherwise, if you cancel or fall on the screen forever
# The picture will remain hanging, indistinguishable from a frozen computer.
cleanup() {
    [ "$FROZEN" = 1 ] && ipc unfreeze
    [ -n "$SHOT" ] && rm -f -- "$SHOT"
}
trap cleanup EXIT INT TERM HUP

# The frame is entirely temporary and large (6 MB at 1080p), so in memory, not on
# disk: XDG_RUNTIME_DIR - tmpfs, and the file still lives until the end of the allocation.
SHOT=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" zenith-shot.XXXXXXXX.ppm) || exit 1

SNAP=0
if grim -t ppm "$SHOT" 2>/dev/null; then SNAP=1; fi

if [ "$SNAP" = 1 ] && ipc freeze "$SHOT"; then
    FROZEN=1
    # The layer needs a frame to appear on the screen. Without pause the first milliseconds
    # selections go across the live screen - exactly what they left.
    sleep 0.08
fi

# Cancel with Esc or right click - empty output and non-zero code.
GEOM=$(slurp -b 00000060 -c ffffffff -w 1) || exit 0
[ -n "$GEOM" ] || exit 0

# A freeze frame is no longer needed: cropping is carried out according to the file, and keep the picture on
# screen to the end means showing it an extra fraction of a second after the click.
if [ "$FROZEN" = 1 ]; then ipc unfreeze; FROZEN=0; fi

mkdir -p "$DIR" || exit 1
OUT="$DIR/$(date +'Screenshot_%Y-%m-%d_%H-%M-%S').png"

if [ "$SNAP" = 1 ]; then
    # The usual way: we cut an already shot frame.
    python3 "$CFG/scripts/shotcrop.py" "$SHOT" "$GEOM" "$OUT" || exit 1
else
    # There is no frame - we are filming the area right now, on the live screen.
    grim -g "$GEOM" "$OUT" || exit 1
fi

# To a buffer from a file, not from a stream: so the return code belongs to trimming, not
# wl-copy, for which an empty input would pass for successful operation.
wl-copy -t image/png < "$OUT"
ipc shotCopied "$OUT"
