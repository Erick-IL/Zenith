#!/usr/bin/env bash
# File properties for pill explorer.
#
#   props.sh PATH -> lines "key<TAB>value" (keys in Russian/English decides
#                      the panel itself; here are universal machine values)
#
# Outputs: name, type (MIME), size (in bytes and human), modification date,
# date of creation (if the FS stores), rights, owner. For pictures and videos -
# resolution, and for video/audio - duration.

f="$1"
[ -e "$f" ] || { echo "error	no such file"; exit 1; }

emit() { printf '%s\t%s\n' "$1" "$2"; }

emit name    "$(basename "$f")"
emit path    "$f"

if [ -d "$f" ]; then
    emit kind "inode/directory"
    # number of elements inside
    n=$(find "$f" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    emit items "$n"
else
    mime=$(file -b --mime-type "$f" 2>/dev/null)
    emit kind "${mime:-unknown}"
fi

# size
if command -v stat >/dev/null 2>&1; then
    bytes=$(stat -c '%s' "$f" 2>/dev/null)
    [ -n "$bytes" ] && emit size_bytes "$bytes"
    emit size_human "$(numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || echo "$bytes")"
    emit modified "$(stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)"
    # creation date (birth); on some FS is not available - then “-”
    birth=$(stat -c '%w' "$f" 2>/dev/null)
    case "$birth" in ""|"-") : ;; *) emit created "$(echo "$birth" | cut -d. -f1)" ;; esac
    emit perms "$(stat -c '%A' "$f" 2>/dev/null)"
    emit owner "$(stat -c '%U:%G' "$f" 2>/dev/null)"
fi

# resolution/duration via ffprobe - available in player dependencies
case "${mime:-}" in
    image/*)
        if command -v ffprobe >/dev/null 2>&1; then
            wh=$(ffprobe -v error -select_streams v:0 \
                 -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null)
            [ -n "$wh" ] && emit resolution "$wh"
        fi
        ;;
    video/*|audio/*)
        if command -v ffprobe >/dev/null 2>&1; then
            if [ "${mime%%/*}" = "video" ]; then
                wh=$(ffprobe -v error -select_streams v:0 \
                     -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null)
                [ -n "$wh" ] && emit resolution "$wh"
            fi
            dur=$(ffprobe -v error -show_entries format=duration \
                  -of default=nw=1:nk=1 "$f" 2>/dev/null)
            [ -n "$dur" ] && emit duration "$dur"
        fi
        ;;
esac
