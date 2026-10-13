#!/usr/bin/env bash
# Live wallpaper: video instead of a picture on the desktop background.
#
#   dir -> prints the live wallpaper directory (having created it)
#   list -> lines name|poster|active(yes|no)|path
#   set <path|name> -> set video background
#   stop -> return normal wallpaper
#   state -> prints the path of the current video or is empty
#   warm -> catch up with posters for all videos
#
# Plays mpvpaper: it puts mpv on the background layer, so windows and pill
# remain on top. hyprpaper is turned off for this time - two background layers
# they would argue for the same screen.
#
# The state lives in wallpaper.conf next to the regular wallpaper ($live). File nobody
# does not connect via source, so changing the background does not affect Hyprland configs.

LIVE_DIR="$HOME/.config/hypr/wallpaper/live"
STATE="$HOME/.config/hypr/wallpaper.conf"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/thumbs"
SWITCH="$(dirname "$0")/switch_theme.sh"

mkdir -p "$LIVE_DIR"

live_state() {
    grep -m1 '^\$live' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}
still_state() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

# We write $live, saving the line with the usual wallpaper: we return to it using stop.
save_live() {
    local v="$1" still
    still=$(still_state)
    {
        printf '# File is generated automatically when switching wallpapers.\n'
        printf '# Hyprland does not include it: changing wallpaper should not touch config.\n'
        printf '$wallpaper = %s\n' "$still"
        [ -n "$v" ] && printf '$live = %s\n' "$v"
    } > "$STATE"
}

poster() {
    # A frame from the middle of the video is a preview for the carousel. Put it in the general cache
    # thumbnails: the carousel reads both pictures and videos from one place.
    local src="$1" name dst dur pos
    name=$(basename "$src"); name="${name%.*}.jpg"
    dst="$THUMBS/$name"
    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        mkdir -p "$THUMBS"
        dur=$(ffprobe -v error -show_entries format=duration \
                      -of default=nw=1:nk=1 "$src" 2>/dev/null)
        pos=$(awk -v d="$dur" 'BEGIN{ if (d > 2) printf "%.1f", d/2; else print 0 }')
        ffmpeg -loglevel error -y -ss "$pos" -i "$src" -frames:v 1 \
               -vf "scale=1100:-1" -q:v 5 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

resolve() {
    local n="$1"
    n="${n/#\~/$HOME}"
    [ -f "$n" ] && { printf '%s\n' "$n"; return 0; }
    find "$LIVE_DIR" -maxdepth 1 -type f -iname "$n.*" -print -quit | grep . && return 0
    return 1
}

case "$1" in
dir)
    printf '%s\n' "$LIVE_DIR"
    ;;

state)
    live_state
    ;;

list)
    cur=$(live_state)
    find "$LIVE_DIR" -maxdepth 1 -type f \
         \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
         | sort | while read -r v; do
        base=${v##*/}
        name=${base%.*}
        [ "$v" = "$cur" ] && act=yes || act=no
        # We give away the poster only if it is already ready: pull out frames from
        # dozens of videos while building a list means seconds of waiting,
        # “warm” catches up with them.
        p="$THUMBS/$name.jpg"
        [ -f "$p" ] && [ ! "$v" -nt "$p" ] || p=""
        printf '%s|%s|%s|%s\n' "$name" "$p" "$act" "$v"
    done
    ;;

warm)
    find "$LIVE_DIR" -maxdepth 1 -type f \
         \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
         | while read -r v; do poster "$v" >/dev/null; done
    ;;

set)
    [ -z "$2" ] && exit 1
    vid=$(resolve "$2") || { echo "video not found: $2" >&2; exit 1; }

    pkill -x hyprpaper >/dev/null 2>&1
    pkill -x mpvpaper  >/dev/null 2>&1
    sleep 0.2

    # mpv options come WITHOUT double hyphens: mpvpaper passes the string to its
    # parser, and “--loop-inf” did not reach mpv - the video played to the end and
    # the screen turned black.
    #   loop-file=inf - wallpaper should not end
    #   keep-open=yes - even if something goes wrong, the last frame remains,
    #                    not blackness
    #   no-audio - wallpaper does not sound
    #   hwdec - decoding goes to the video card, where possible
    MPV_OPTS="loop-file=inf keep-open=yes no-audio hwdec=auto-safe vo=gpu"

    # One copy per monitor, and not one for everything separated by “*”.
    # Autopause for mpvpaper is calculated for the entire instance: with a common one for all outputs
    # a full-screen window on one monitor stopped the wallpaper on the others.
    #
    # -p (and only this): mpv goes to sleep when the wallpaper is closed. Flag -a MAX here
    # no intentionally - it extends the pause to ANY maximized window in the system,
    # and not on what covers the wallpaper itself.
    mons=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')
    [ -n "$mons" ] || mons='*'
    for M in $mons; do
        mpvpaper -f -p -l background -o "$MPV_OPTS" "$M" "$vid" >/dev/null 2>&1
    done

    save_live "$vid"
    ;;

stop)
    pkill -x mpvpaper >/dev/null 2>&1
    save_live ""
    # we return the picture that was before the live wallpaper
    [ -x "$SWITCH" ] && "$SWITCH" --restore >/dev/null 2>&1
    ;;

*)
    echo "usage: live_wallpaper.sh dir|list|set <video>|stop|state|warm" >&2
    exit 1
    ;;
esac
