#!/bin/bash
#
# Power saving mode: suppresses animations, shadows, blur and rounding.
# The second launch brings everything back.
#
# Previously, he also replaced the shell - he killed the pill and put it in its place
# waybar with wob. This was abandoned: it is not memory that saves here, but undone
# redrawing, and it is turned off with these same lines. Second set of panels
# had to be kept on par with the first, and he couldn’t stand it - menu
# Wi-Fi was written on nmcli, although the system is on iwd, and half of the bar buttons
# called programs that never existed in the dependencies.

# Whether the mode is enabled or not, this file is remembered. Previously it was a sign
# commented section in hypr/modules/look_and_feel.conf - but config
# Hyprland has been in lua/ for a long time, and no one reads .conf, so the script
# I commented out lines that didn't affect anything and stored a flag in them.
# It has no place in the runtime directory: the mode must survive a reboot.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zenith"
STATE="$STATE_DIR/battery-mode"
LOG="${XDG_RUNTIME_DIR:-/tmp}/battery_mode.log"
SHELL="qs -c $HOME/.config/zenith"

# Current Monitor: Mode resets it to 120Hz with VRR. Frequency not
# lower it - with VRR, the driver itself drops it to 48 Hz in a static picture,
# and fixed 60 would give less winnings than floating 120.
MONITOR_INFO=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
MONITOR=$(echo "$MONITOR_INFO" | jq -r '.name')
WIDTH=$(echo "$MONITOR_INFO" | jq -r '.width')
HEIGHT=$(echo "$MONITOR_INFO" | jq -r '.height')
RES="${WIDTH}x${HEIGHT}"
POS="$(echo "$MONITOR_INFO" | jq -r '.x')x$(echo "$MONITOR_INFO" | jq -r '.y')"
SCALE=$(echo "$MONITOR_INFO" | jq -r '.scale')

enable_battery() {
    echo "Enabling Battery Savings (120Hz VRR + No Effects)..."
    mkdir -p "$STATE_DIR" && : > "$STATE"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"
    "$HOME/.config/hypr/scripts/switch_theme.sh" black
    sleep 0.5

    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } } })'

    # The shell also has no need to move: the island stops unfolding
    # resizes smoothly and easily.
    $SHELL ipc call pill motion off 2>/dev/null || true
}

disable_battery() {
    echo "Restoring Performance Mode (120Hz VRR + Animations)..."
    rm -f "$STATE"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"

    "$HOME/.config/hypr/scripts/switch_theme.sh" minimal
    sleep 0.5

    hyprctl eval '
    local theme = require("theme")
    hl.config({
        animations = { enabled = true },
        decoration = {
            rounding = theme.rounding,
            shadow = { enabled = theme.shadow_enabled },
            blur = { enabled = theme.blur_enabled }
        }
    })
    '

    $SHELL ipc call pill motion on 2>/dev/null || true
}

{
    echo "Running toggle check..."
    if [ -e "$STATE" ]; then
        echo "Disabling battery"
        disable_battery
    else
        echo "Enabling battery"
        enable_battery
    fi
} >> "$LOG" 2>&1
