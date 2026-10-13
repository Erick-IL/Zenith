#!/usr/bin/env bash
# Wallpaper thumbnails for the theme selection page.
#
# The wallpaper weighs up to 9 MB, and Qt decoded it every time the page was opened
# entirely to get an image 320 px wide - hence the delay.
# Here they are compressed once into ~/.cache/zenith/thumbs and then read
# instantly. Regeneration only if the source is newer than the thumbnail.
#
#   thumb PATH -> prints the path to the thumbnail (creating one if necessary)
#   all -> warm up cache for all wallpapers

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/thumbs"
WALLS="$HOME/.config/hypr/wallpaper"
# 480 was enough for the list under the pill, but in the carousel the preview is stretched almost
# half the screen - and it looked soapy. 1100 closes the card with a margin.
WIDTH=1100

mkdir -p "$CACHE"

make_thumb() {
    local src="$1"
    [ -f "$src" ] || return 1

    local name
    name=$(basename "$src")
    name="${name%.*}.jpg"
    local dst="$CACHE/$name"

    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        # -noautorotate is not needed, wallpaper without EXIF; q=5 is enough for preview
        ffmpeg -loglevel error -y -i "$src" \
               -vf "scale=$WIDTH:-1" -q:v 5 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

# Background for the lock screen: the same wallpaper, but compressed under the screen.
# Sources are 75 megapixels - Qt refuses to decode them
# (256 MB limit per image), and they would take half a second to open.
LOCKBG="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/lockbg"
LOCK_WIDTH=1920

make_lockbg() {
    local src="$1"
    [ -f "$src" ] || return 1
    mkdir -p "$LOCKBG"

    local name
    name=$(basename "$src")
    name="${name%.*}.jpg"
    local dst="$LOCKBG/$name"

    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        # we reduce only what is larger than the screen; do not touch small wallpapers
        ffmpeg -loglevel error -y -i "$src" \
               -vf "scale='min($LOCK_WIDTH,iw)':-2" -q:v 2 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

case "$1" in
    thumb)
        make_thumb "$2"
        ;;
    lockbg)
        make_lockbg "$2"
        ;;
    path)
        # The path to a finished miniature is WITHOUT creation. The wallpaper list calls this
        # for each picture, and one ffmpeg per file turned the opening
        # carousels in minutes of waiting: there are now hundreds of wallpapers, not a dozen and a half.
        src="$2"
        [ -f "$src" ] || exit 1
        name=$(basename "$src"); name="${name%.*}.jpg"
        dst="$CACHE/$name"
        [ -f "$dst" ] && [ ! "$src" -nt "$dst" ] && printf '%s\n' "$dst"
        ;;
    all)
        # The wallpaper catalog now has subdirectories (custom, shell) - we bypass them too
        find "$WALLS" -maxdepth 2 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | while read -r f; do
            make_thumb "$f" >/dev/null
        done
        ;;
    *)
        echo "usage: thumbs.sh thumb <path> | lockbg <path> | all" >&2
        exit 1
        ;;
esac
