#!/usr/bin/env bash
# Brightness - one input for all machines.
#
#   brightness.sh detect - what kind of car is it and how to adjust the brightness
#   brightness.sh list - controlled screens: id, name, percentage
#   brightness.sh get <id> - percentage of one screen
#   brightness.sh set <id> <pct> - set percentages
#   brightness.sh up|down - step with acceleration while holding the key
#
# A laptop and a PC differ not in settings, but in hardware, and ask about this
# there is no need for a person:
#
#   * there is /sys/class/backlight/* - internal matrix, turn brightnessctl;
#   * otherwise an external monitor, and DDC/CI over I2C remains - ddcutil.
#
# DDC has its own rules: the bus responds slowly (tens of milliseconds per request),
# does not always respond, and `ddcutil detect` with all checks takes seconds.
# Therefore, the “bus → connector” card is counted once and lives in the cache, and requests
# always come with an explicit --bus: without it, ddcutil itself searches for the monitor again.
set -u

RUN="${XDG_RUNTIME_DIR:-/tmp}"
CACHE="$RUN/zenith-brightness.map"
STATE="$RUN/zenith-bright.streak"

MIN=1               # Don’t go any lower, otherwise the screen goes dark completely
MAX=100

have() { command -v "$1" >/dev/null 2>&1; }

# --------------------------------------------------------------- what kind of car
# The battery is the only honest sign of the laptop: the case is in DMI on prefabricated
# in cars it lies, but the battery just doesn’t appear in power_supply.
has_battery() {
    local d
    for d in /sys/class/power_supply/*; do
        [ -r "$d/type" ] || continue
        [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && return 0
    done
    return 1
}

has_touchpad() {
    have hyprctl || return 1
    hyprctl -j devices 2>/dev/null | grep -qiE '"name": *"[^"]*(touchpad|synaptics|trackpad)' && return 0
    grep -qiE 'touchpad|synaptics' /proc/bus/input/devices 2>/dev/null
}

# Internal matrix. Keyboard LEDs have their own class (leds), in backlight
# they don't get there - that's why it's this directory, and not the output of brightnessctl without
# arguments: it shows the first device it comes across, including the backlight
# keys, and on a PC I would lie about the presence of brightness control.
backlight_dev() {
    local d
    for d in /sys/class/backlight/*; do
        [ -d "$d" ] || continue
        basename "$d"; return 0
    done
    return 1
}

backend() {
    backlight_dev >/dev/null 2>&1 && { echo backlight; return; }
    have ddcutil && [ -e /dev/i2c-0 ] && { echo ddc; return; }
    echo none
}

cmd_detect() {
    local b; b="$(backend)"
    echo "backend=$b"
    if has_battery; then echo "battery=1"; echo "chassis=laptop"
    else echo "battery=0"; echo "chassis=desktop"; fi
    has_touchpad && echo "touchpad=1" || echo "touchpad=0"
    have ddcutil && echo "ddcutil=1" || echo "ddcutil=0"
}

# ------------------------------------------------------------------- backlight
bl_get() { brightnessctl -d "$1" -m 2>/dev/null | LC_ALL=C awk -F, '{gsub("%","",$4); print $4}'; }
bl_set() { brightnessctl -d "$1" -q s "$2%" 2>/dev/null; }

# ------------------------------------------------------------------------- DDC
# Tire map. The lines “bus<TAB>connector”; connector - same name as the monitor
# is called in Hyprland (HDMI-A-1, DP-2) so that the Display tab can reduce
# slider with the desired card.
ddc_scan() {
    local bus="" conn=""
    ddcutil detect --brief 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *"I2C bus:"*)       bus="${line##*/dev/i2c-}" ;;
            *"DRM connector:"*)
                conn="${line##*: }"
                conn="$(echo "$conn" | tr -d ' \t')"
                # card1-HDMI-A-1 → HDMI-A-1
                conn="${conn#card*-}"
                [ -n "$bus" ] && [ -n "$conn" ] && printf '%s\t%s\n' "$bus" "$conn"
                bus=""; conn=""
                ;;
        esac
    done
}

ddc_map() {
    # The cache lives until a reboot or rescanning: monitors do not
    # move between tires on their own, and pay in seconds for each
    # Settings cannot be shown.
    [ -s "$CACHE" ] || ddc_scan > "$CACHE" 2>/dev/null
    cat "$CACHE" 2>/dev/null
}

ddc_get() { ddcutil --bus "$1" getvcp 10 --brief 2>/dev/null | LC_ALL=C awk '{print $4}'; }
ddc_set() { ddcutil --bus "$1" setvcp 10 "$2" >/dev/null 2>&1; }

# ---------------------------------------------------------------------- general
clamp() {
    local p="$1"
    [ "$p" -lt "$MIN" ] && p="$MIN"
    [ "$p" -gt "$MAX" ] && p="$MAX"
    echo "$p"
}

cmd_list() {
    case "$(backend)" in
        backlight)
            local d; d="$(backlight_dev)" || return 0
            printf 'bl:%s\t%s\t%s\n' "$d" "$(tr -d '\n' <<<"${DISPLAY_LABEL:-Встроенный экран}")" "$(bl_get "$d")"
            ;;
        ddc)
            local bus conn pct
            while IFS=$'\t' read -r bus conn; do
                [ -n "$bus" ] || continue
                pct="$(ddc_get "$bus")"
                # The monitor may be visible on the bus but not respond to VCP 0x10
                # (cheap panels and almost all laptop docking stations). Such
                # the screen is not included in the list - the slider has no feedback
                # worse than not having one.
                [ -n "$pct" ] || continue
                printf 'ddc:%s\t%s\t%s\n' "$bus" "$conn" "$pct"
            done < <(ddc_map)
            ;;
    esac
}

cmd_get() {
    case "$1" in
        bl:*)  bl_get "${1#bl:}" ;;
        ddc:*) ddc_get "${1#ddc:}" ;;
    esac
}

cmd_set() {
    local id="$1" pct; pct="$(clamp "$2")"
    case "$id" in
        bl:*)  bl_set "${id#bl:}" "$pct" ;;
        ddc:*) ddc_set "${id#ddc:}" "$pct" ;;
    esac
    echo "$pct"
}

# The first controllable screen: the brightness keys have nothing to choose from.
first_id() { cmd_list | head -1 | cut -f1; }

# Step with acceleration: we measure the pause between calls, with a series of consecutive calls
# Pressing the step increases. The logic is the same as smart_volume.sh.
step_now() {
    local now streak=0 last prev
    now="$(date +%s%3N)"
    if [ -f "$STATE" ]; then
        read -r last prev < "$STATE" 2>/dev/null
        if [ -n "${last:-}" ] && [ $(( now - last )) -lt 280 ]; then
            streak=$(( ${prev:-0} + 1 ))
        fi
    fi
    echo "$now $streak" > "$STATE"
    if   [ "$streak" -lt 4 ];  then echo 5
    elif [ "$streak" -lt 10 ]; then echo 10
    else                            echo 20
    fi
}

cmd_step() {
    local dir="$1" id cur step pct
    id="$(first_id)"; [ -n "$id" ] || exit 1
    cur="$(cmd_get "$id")"; [ -n "$cur" ] || exit 1
    step="$(step_now)"
    if [ "$dir" = up ]; then
        pct=$(( (cur / step) * step + step ))
    else
        pct=$(( ( (cur + step - 1) / step ) * step - step ))
    fi
    pct="$(cmd_set "$id" "$pct")"

    # The level is drawn by the pill: the brightness goes past the Pipewire, and it itself
    # she won’t recognize the change - so we tell her about it.
    if pgrep -x qs >/dev/null 2>&1; then
        qs -c "$HOME/.config/zenith" ipc call pill brightness "$pct" 2>/dev/null &
    fi
}

case "${1:-}" in
    detect)  cmd_detect ;;
    list)    cmd_list ;;
    rescan)  rm -f "$CACHE"; ddc_map >/dev/null; cmd_list ;;
    get)     cmd_get "${2:-}" ;;
    set)     cmd_set "${2:-}" "${3:-0}" ;;
    up)      cmd_step up ;;
    down)    cmd_step down ;;
    *)       echo "usage: brightness.sh detect|list|rescan|get <id>|set <id> <pct>|up|down" >&2; exit 1 ;;
esac
