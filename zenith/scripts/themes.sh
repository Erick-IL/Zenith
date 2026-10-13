#!/usr/bin/env bash
# Wallpaper for the selection page.
#
#   list -> lines name|thumbnail|active(yes|no)|own(yes|no)|full_path
#   set NAME -> apply
#   add <path> -> copy the file to your wallpaper and apply
#   del NAME -> delete your wallpaper
#
# There are no more sets of colors: there is only one palette (hypr/palette.conf), and
# “theme” is just a picture. Therefore, the list is taken directly from the catalog
# wallpaper, not from themes/*.conf.

WALL_DIR="$HOME/.config/hypr/wallpaper"
CUSTOM="$WALL_DIR/custom"
STATE="$HOME/.config/hypr/wallpaper.conf"
SWITCH="$HOME/.config/hypr/scripts/switch_theme.sh"
THUMBS="$(dirname "$0")/thumbs.sh"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/thumbs"

current() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

case "$1" in
list)
    cur=$(current)
    # Everything in one loop using built-in commands: hundreds of wallpapers, and subprocesses
    # (basename, thumbs.sh) for each they turned the list into five seconds -
    # The carousel managed to open empty.
    find "$WALL_DIR" -maxdepth 2 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
         | sort | while read -r w; do
        base=${w##*/}
        name=${base%.*}
        [ "$w" = "$cur" ] && act=yes || act=no
        case "$w" in "$CUSTOM"/*) own=yes ;; *) own=no ;; esac
        # Finished miniature, if it exists and is not outdated: the source codes weigh
        # megabytes. You can’t create them here - “warm” does that
        # Until then, we show the source, Qt will compress it by sourceSize.
        thumb="$THUMB_DIR/$name.jpg"
        [ -f "$thumb" ] && [ ! "$w" -nt "$thumb" ] || thumb="$w"
        printf '%s|%s|%s|%s|%s\n' "$name" "$thumb" "$act" "$own" "$w"
    done
    ;;

warm)
    # Let's catch up with the thumbnails for the new wallpapers. Calls from the carousel after opening,
    # therefore, the first opening is quick, and the second is already with miniatures.
    exec "$THUMBS" all
    ;;

set)
    [ -z "$2" ] && exit 1
    exec "$SWITCH" "$2"
    ;;

add)
    src="$2"
    [ -f "$src" ] || { echo "error" >&2; exit 1; }
    mkdir -p "$CUSTOM"

    # Если такой же файл уже добавлен в свои обои — используем его без дубликатов
    for existing in "$CUSTOM"/*; do
        if [ -f "$existing" ] && cmp -s "$src" "$existing"; then
            "$SWITCH" "$existing" >/dev/null 2>&1
            basename "$existing" | sed 's/\.[^.]*$//'
            exit 0
        fi
    done

    base=$(basename "$src")
    slug=$(printf '%s' "${base%.*}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' \
           | tr -cd '[:alnum:]_-')
    [ -z "$slug" ] && slug="wall_$(date +%s)"
    ext="${base##*.}"
    dest="$CUSTOM/$slug.$ext"
    # name is taken - don’t overwrite someone else’s picture silently
    [ -e "$dest" ] && dest="$CUSTOM/${slug}_$(date +%s).$ext"
    cp -f "$src" "$dest" || exit 1
    "$SWITCH" "$dest" >/dev/null 2>&1
    basename "$dest" | sed 's/\.[^.]*$//'
    ;;

del)
    [ -z "$2" ] && exit 1
    rm -f "$CUSTOM/$2".* 2>/dev/null
    ;;

*)
    echo "usage: themes.sh list | set <name> | add <file> | del <name>" >&2
    exit 1
    ;;
esac
