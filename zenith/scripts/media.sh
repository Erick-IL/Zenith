#!/usr/bin/env bash
# Pill media player maintenance.
#
#   probe PATH -> duration|width|height (duration 0 for images)
#   cut PATH START END [DIR] [X Y W H]
#                               -> cut a piece of video (and, if X Y W H is given,
#                                  crop the frame at the same time), prints the path to the file
#   crop PATH X Y W H [DIR] -> crop area of the image, prints the path
#
# The default DIR is the original folder. The name is not erased: it is added to
# “-cut”/“-crop” and, if one already exists, the number.

out_name() {
    local src="$1" dir="$2" suffix="$3" ext="$4"
    local base
    base=$(basename "$src")
    base="${base%.*}"
    local out="$dir/$base$suffix.$ext"
    local n=2
    while [ -e "$out" ]; do
        out="$dir/$base$suffix-$n.$ext"
        n=$((n + 1))
    done
    printf '%s\n' "$out"
}

case "$1" in
    probe)
        P="${2:?}"
        ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height -show_entries format=duration \
            -of default=nw=1:nk=1 "$P" 2>/dev/null | {
                read -r w; read -r h; read -r d
                printf '%s|%s|%s\n' "${d:-0}" "${w:-0}" "${h:-0}"
            }
        ;;

    cut)
        P="${2:?}"; START="${3:?}"; END="${4:?}"
        # Messengers show videos without audio tracks as “gifs”
        # and crush it into mush. If there is no sound, add silence.
        HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index \
                            -of csv=p=0 "$P" 2>/dev/null | head -1)
        SILENCE=()
        AENC=(-c:a copy)
        if [ -z "$HAS_AUDIO" ]; then
            SILENCE=(-f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000")
            AENC=(-c:a aac -b:a 96k -shortest)
        fi
        DIR="${5:-$(dirname "$P")}"
        DIR="${DIR/#\~/$HOME}"
        X="$6"; Y="$7"; W="$8"; H="$9"
        mkdir -p "$DIR" || exit 1
        ext="${P##*.}"
        OUT=$(out_name "$P" "$DIR" "-cut" "$ext")

        if [ -n "$W" ] && [ "$W" != "0" ]; then
            # cropping a frame requires compression: the stream cannot be copied
            ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                   -vf "crop=$W:$H:$X:$Y" \
                   -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
                   "${AENC[@]}" -movflags +faststart "$OUT" </dev/null || exit 1
        else
            # -c copy cuts by key frames: quickly and without loss of quality.
            # If the container cannot do this, we squeeze it.
            if ! ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                        -c:v copy "${AENC[@]}" -avoid_negative_ts make_zero \
                        -movflags +faststart "$OUT" </dev/null; then
                ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                       -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
                       "${AENC[@]}" -movflags +faststart "$OUT" </dev/null || exit 1
            fi
        fi
        printf '%s\n' "$OUT"
        ;;

    crop)
        P="${2:?}"; X="${3:?}"; Y="${4:?}"; W="${5:?}"; H="${6:?}"
        DIR="${7:-$(dirname "$P")}"
        DIR="${DIR/#\~/$HOME}"
        mkdir -p "$DIR" || exit 1
        ext="${P##*.}"
        case "${ext,,}" in
            gif|png|jpg|jpeg|webp|bmp) : ;;
            *) ext="png" ;;
        esac
        OUT=$(out_name "$P" "$DIR" "-crop" "$ext")
        args=(-v error -y -i "$P" -vf "crop=$W:$H:$X:$Y")
        # We save the GIF animation in its entirety, just cropped to the frame
        [ "${ext,,}" = "gif" ] && args+=(-loop 0)
        ffmpeg "${args[@]}" "$OUT" </dev/null || exit 1
        printf '%s\n' "$OUT"
        ;;

    *)
        echo "usage: media.sh probe P | cut P START END [DIR] | crop P X Y W H [DIR]" >&2
        exit 1
        ;;
esac
