#!/bin/bash
# Volume in even steps, with acceleration when holding the key.
#
# Basic step 5%. Hyprland, while holding the key, calls the script again and again,
# Therefore, we measure the pause between calls: if they come in a row, the step increases.
#
# wpctl can do relative steps (5%+), but if the current value is not a multiple
# five, it will remain like this: 43 -> 48 -> 53. Therefore, we count ourselves:
# We round the current level to a multiple of the step and move from there.

SINK="@DEFAULT_AUDIO_SINK@"
MAX=100

STATE="${XDG_RUNTIME_DIR:-/tmp}/zenith-vol.streak"
GAP_MS=280          # a pause longer than this - the hold is considered interrupted

now_ms() { date +%s%3N; }

# --- determine the length of a series of consecutive clicks
streak=0
if [ -f "$STATE" ]; then
    read -r last prev_streak < "$STATE" 2>/dev/null
    if [ -n "$last" ] && [ $(( $(now_ms) - last )) -lt $GAP_MS ]; then
        streak=$(( prev_streak + 1 ))
    fi
fi
echo "$(now_ms) $streak" > "$STATE"

# --- the step increases as you hold
if   [ "$streak" -lt 4 ];  then STEP=5
elif [ "$streak" -lt 10 ]; then STEP=10
else                            STEP=20
fi

cur_pct() {
    # "Volume: 0.45" or "Volume: 0.45 [MUTED]"
    wpctl get-volume "$SINK" | LC_ALL=C awk '{printf "%d", $2 * 100 + 0.5}'
}

set_pct() {
    local p=$1
    [ "$p" -lt 0 ]    && p=0
    [ "$p" -gt $MAX ] && p=$MAX
    wpctl set-volume "$SINK" "${p}%"
}

case "$1" in
    up)
        cur=$(cur_pct)
        set_pct $(( (cur / STEP) * STEP + STEP ))
        # turning up the volume removes the muteness - otherwise it’s unclear why it’s quiet
        wpctl set-mute "$SINK" 0
        ;;
    down)
        cur=$(cur_pct)
        set_pct $(( ( (cur + STEP - 1) / STEP ) * STEP - STEP ))
        ;;
    mute)
        wpctl set-mute "$SINK" toggle
        ;;
    *)
        echo "usage: smart_volume.sh up|down|mute" >&2
        exit 1
        ;;
esac

# The level is shown by the pill itself: it monitors the Pipewire and draws a strip,
# and does this in any mode - a separate indicator for energy saving
# no more.
