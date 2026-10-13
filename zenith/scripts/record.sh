#!/usr/bin/env bash
# Screen recording for pill (wf-recorder).
#
#   start FPS DIR SYS MIC MIC_DEV -> start
#       SYS/MIC - 0|1, whether to write system sound and microphone
#       MIC_DEV - pactl source name ("" = default source)
#   pause -> pause/continue (SIGSTOP/SIGCONT)
#   stop -> finish, prints the file path
#   status -> idle | rec|PID|START|PAUSE|FILE
#                                         | paused|PID|START|PAUSE|FILE
#   mics -> list of microphones: name|description
#
# The pause is made by stopping the process: wf-recorder does not have its own pause.
# System + microphone simultaneously - through a temporary null-sink, in which
# both sources are wrapped: wf-recorder can only write one
# device.

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/zenith"
STATE="$STATE_DIR/record.state"
mkdir -p "$STATE_DIR"

# The shell launches us via `sh -c`, and PATH is truncated -
# then even the installed wf-recorder (and with it pactl, ffmpeg) is not found, and
# the entry “clicks, but nothing happens.” We supplement PATH with regular
# places where the binaries are located.
PATH="$PATH:/usr/bin:/usr/local/bin:$HOME/.local/bin:/bin:/usr/sbin:/sbin:/opt/bin"
export PATH

# We look for wf-recorder anywhere: in PATH, in typical directories, in flatpak, and in
# Lastly, a full (but limited) disk search. We lay the path
# in WF_REC. This is how the recording works no matter where the binary is located.
find_recorder() {
    local p
    p=$(command -v wf-recorder 2>/dev/null) && { printf '%s\n' "$p"; return 0; }
    for p in /usr/bin/wf-recorder /usr/local/bin/wf-recorder \
             "$HOME/.local/bin/wf-recorder" /opt/*/bin/wf-recorder \
             /var/lib/flatpak/exports/bin/*wf-recorder* \
             "$HOME/.local/share/flatpak/exports/bin/"*wf-recorder*; do
        [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    p=$(find /usr /opt "$HOME/.local" -maxdepth 5 -name 'wf-recorder' -type f \
            2>/dev/null | head -1)
    [ -n "$p" ] && { printf '%s\n' "$p"; return 0; }
    return 1
}

read_state() {
    PID=""; STARTED=""; PAUSED_AT=""; PAUSED_TOTAL=0; FILE=""; MODULES=""
    [ -f "$STATE" ] || return 1
    # shellcheck disable=SC1090
    . "$STATE"
    [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

write_state() {
    cat > "$STATE" <<EOF
PID=$PID
STARTED=$STARTED
PAUSED_AT=$PAUSED_AT
PAUSED_TOTAL=$PAUSED_TOTAL
FILE="$FILE"
MODULES="$MODULES"
EOF
}

# current output monitor = "system sound"
default_monitor() {
    local sink
    sink=$(pactl get-default-sink 2>/dev/null)
    [ -n "$sink" ] && printf '%s.monitor\n' "$sink"
}

default_mic() { pactl get-default-source 2>/dev/null; }

unload_modules() {
    local ids="$1"
    for id in $ids; do pactl unload-module "$id" 2>/dev/null; done
}

# Finalizing the finished file.
#
# Messengers (Telegram and not only) consider mp4 WITHOUT an audio track not a video,
# but an animation, and show it as a GIF: no sound, no player, looped.
# Therefore, if they wrote without sound, we file silence. Video is not re-encoded
# (-c:v copy), this is fast and without loss of quality.
#
# At the same time, the moov-atom goes to the beginning (+faststart): without this, previews in chats and
# rewind appear only after the file has been completely downloaded.
finalize() {
    f="$1"
    [ -s "$f" ] || return 0
    command -v ffmpeg >/dev/null 2>&1 || return 0

    has_audio=""
    if command -v ffprobe >/dev/null 2>&1; then
        has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index \
                            -of csv=p=0 "$f" 2>/dev/null | head -1)
    fi

    tmp="${f%.mp4}.tmp.mp4"
    if [ -n "$has_audio" ]; then
        ffmpeg -y -v error -i "$f" -c copy -movflags +faststart "$tmp" 2>/dev/null
    else
        ffmpeg -y -v error -i "$f" \
               -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
               -shortest -c:v copy -c:a aac -b:a 96k \
               -movflags +faststart "$tmp" 2>/dev/null
    fi

    if [ -s "$tmp" ]; then mv -f "$tmp" "$f"; else rm -f "$tmp"; fi
}

case "$1" in
    start)
        if read_state; then echo "already" >&2; exit 1; fi

        WF_REC=$(find_recorder) || {
            echo "no-recorder" >&2
            command -v notify-send >/dev/null 2>&1 && notify-send -a Zenith \
                -u critical "Запись недоступна" "wf-recorder не установлен"
            exit 1
        }

        FPS="${2:-60}"
        DIR="${3:-$HOME/Videos}"
        SYS="${4:-0}"
        MIC="${5:-0}"
        MIC_DEV="${6:-}"
        OUTPUT="${7:-}"      # what screen to write (eDP-1, HDMI-A-1); "" = will ask himself

        DIR="${DIR/#\~/$HOME}"
        mkdir -p "$DIR" || exit 1
        FILE="$DIR/zenith-$(date +%Y%m%d-%H%M%S).mp4"

        [ -z "$MIC_DEV" ] && MIC_DEV=$(default_mic)
        SYS_DEV=$(default_monitor)

        MODULES=""
        AUDIO_DEV=""

        if [ "$SYS" = "1" ] && [ "$MIC" = "1" ]; then
            # both sources: we combine them into a separate null-sink
            m=$(pactl load-module module-null-sink sink_name=zenith_mix \
                    sink_properties=device.description=ZenithMix 2>/dev/null) || m=""
            if [ -n "$m" ]; then
                MODULES="$m"
                l1=$(pactl load-module module-loopback source="$SYS_DEV" \
                        sink=zenith_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l1"
                l2=$(pactl load-module module-loopback source="$MIC_DEV" \
                        sink=zenith_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l2"
                AUDIO_DEV="zenith_mix.monitor"
            else
                # the mixer didn’t go up - at least we’re writing a system
                AUDIO_DEV="$SYS_DEV"
            fi
        elif [ "$SYS" = "1" ]; then
            AUDIO_DEV="$SYS_DEV"
        elif [ "$MIC" = "1" ]; then
            AUDIO_DEV="$MIC_DEV"
        fi

        base=(-f "$FILE" -r "$FPS")
        [ -n "$AUDIO_DEV" ] && base+=("--audio=$AUDIO_DEV")
        # Multiple screens (laptop + HDMI TV): without -o wf-recorder
        # asks for a choice in stdin, and we are running in the background without input - it exited
        # with "Failed to select output". The panel sends the selected screen here.
        [ -n "$OUTPUT" ] && base+=(-o "$OUTPUT")

        # Running and checking that the process lived for half a second: wf-recorder when
        # failure (no required codec, wrong pixel format, won’t start
        # capture) silently comes out immediately - and the record is “pressed in vain.”
        attempt() {
            "$WF_REC" "${base[@]}" "$@" >"$STATE_DIR/record.log" 2>&1 &
            PID=$!
            sleep 0.5
            kill -0 "$PID" 2>/dev/null
        }

        # Is there an encoder in the ffmpeg assembly with which wf-recorder is linked.
        have_enc() {
            command -v ffmpeg >/dev/null 2>&1 || return 1
            ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw "$1"
        }

        # Sorting codecs from the best to the one that definitely exists. libx264 (on Arch
        # comes with ffmpeg) - preferred; it’s not there or with the wrong options -
        # We take the next available one, and at the end we give the choice to wf-recorder itself.
        started=0
        if have_enc libx264; then
            attempt -c libx264 -p preset=veryfast -p crf=23 && started=1
            [ "$started" = 0 ] && { attempt -c libx264 && started=1; }
        fi
        if [ "$started" = 0 ] && have_enc libvpx-vp9; then
            attempt -c libvpx-vp9 && started=1
        fi
        if [ "$started" = 0 ] && have_enc libvpx; then
            attempt -c libvpx && started=1
        fi
        # Last try - the default codec of the wf-recorder build.
        [ "$started" = 0 ] && { attempt && started=1; }

        if [ "$started" = 0 ]; then
            unload_modules "$MODULES"
            echo "failed" >&2
            tail -4 "$STATE_DIR/record.log" >&2
            # Show the real reason: the panel is itself a notification daemon, so
            # which can be seen from quick settings, and not just on the entry page.
            err=$(tail -2 "$STATE_DIR/record.log" 2>/dev/null | tr '\n' ' ')
            command -v notify-send >/dev/null 2>&1 && \
                notify-send -a Zenith -u critical "Запись не началась" "$err"
            exit 1
        fi

        STARTED=$(date +%s)
        PAUSED_AT=""
        PAUSED_TOTAL=0
        write_state
        echo "$FILE"
        ;;

    pause)
        read_state || { echo "idle" >&2; exit 1; }
        if [ -n "$PAUSED_AT" ]; then
            kill -CONT "$PID"
            PAUSED_TOTAL=$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))
            PAUSED_AT=""
        else
            kill -STOP "$PID"
            PAUSED_AT=$(date +%s)
        fi
        write_state
        ;;

    stop)
        read_state || { echo "idle" >&2; exit 1; }
        [ -n "$PAUSED_AT" ] && kill -CONT "$PID"
        kill -INT "$PID" 2>/dev/null
        # we wait until the container is added: otherwise the file will be broken
        for _ in $(seq 1 50); do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -0 "$PID" 2>/dev/null && kill -TERM "$PID" 2>/dev/null
        unload_modules "$MODULES"
        rm -f "$STATE"
        finalize "$FILE"
        echo "$FILE"
        ;;

    status)
        if read_state; then
            if [ -n "$PAUSED_AT" ]; then
                echo "paused|$PID|$STARTED|$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))|$FILE"
            else
                echo "rec|$PID|$STARTED|$PAUSED_TOTAL|$FILE"
            fi
        else
            # the process died on its own (for example, the space ran out) - we clean up after it
            if [ -f "$STATE" ]; then
                # shellcheck disable=SC1090
                . "$STATE"
                unload_modules "$MODULES"
                rm -f "$STATE"
            fi
            echo "idle"
        fi
        ;;

    mics)
        pactl -f json list sources 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for s in data:
    name = s.get("name", "")
    # Output monitors are “system sound”, not microphones
    if name.endswith(".monitor") or s.get("monitor_source_name"):
        continue
    if name.startswith("zenith_mix"):
        continue
    desc = (s.get("description") or name)
    print(f"{name}|{desc}")
'
        ;;

    *)
        echo "usage: record.sh start FPS DIR SYS MIC [MIC_DEV] | pause | stop | status | mics" >&2
        exit 1
        ;;
esac
