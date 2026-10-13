#!/usr/bin/env bash
# Change the wallpaper - and only the wallpaper.
#
#   switch_theme.sh --restore return the latest wallpaper (autorun)
#   switch_theme.sh <name> wallpaper from ~/.config/hypr/wallpaper (without .jpg)
#   switch_theme.sh <path> any file
#
# Asks nothing without arguments: the choice of wallpaper lives in the pill itself
# (Super + Shift + T), and keep the second menu on tofi for the same reason
# would mean holding tofi.
#
# Colors are not involved here: there is only one palette and it is in palette.conf, its
# lays out palette.sh. So changing the picture no longer recolors
# terminals and does not touch a single file that Hyprland itself reads -
# Previously, because of this, desktops were shaken up on every topic.

WALL_DIR="$HOME/.config/hypr/wallpaper"
# A separate file, not theme.conf: no one connects it via source,
# Therefore, Hyprland remains undisturbed when changing wallpaper.
STATE="$HOME/.config/hypr/wallpaper.conf"

# Path to wallpaper: either a ready-made file or a name without an extension. We are looking all over
# wallpaper catalog, and not just in its root: the downloaded sets are in
# subdirectories (shell, custom), and previously selecting such an image silently
# ended in nothing.
resolve() {
    local n="$1"
    n="${n/#\~/$HOME}"
    if [ -f "$n" ]; then printf '%s\n' "$n"; return 0; fi
    find "$WALL_DIR" -maxdepth 2 -type f \
         \( -iname "$n.jpg" -o -iname "$n.jpeg" -o -iname "$n.png" -o -iname "$n.webp" \) \
         -print -quit 2>/dev/null | grep . && return 0
    return 1
}

current() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

if [ "$1" = "--restore" ]; then
    # the last thing was the live wallpaper - give it to your script and exit
    LIVE=$(grep -m1 '^\$live' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//')
    LIVE="${LIVE/#\~/$HOME}"
    if [ -n "$LIVE" ] && [ -f "$LIVE" ]; then
        exec "$(dirname "$0")/live_wallpaper.sh" set "$LIVE"
    fi
    WALL=$(current)
    [ -n "$WALL" ] || WALL=$(ls "$WALL_DIR"/*.jpg "$WALL_DIR"/*.png 2>/dev/null | head -1)
elif [ -n "$1" ]; then
    WALL=$(resolve "$1")
else
    echo "usage: switch_theme.sh --restore | <имя> | <путь>" >&2
    exit 1
fi

WALL="${WALL/#\~/$HOME}"
[ -n "$WALL" ] && [ -f "$WALL" ] || { echo "wallpaper not found: $1" >&2; exit 1; }

# Live wallpapers and static wallpapers are the same background, so including the picture
# turns off the video. Otherwise, mpvpaper would remain spinning under it.
if grep -q '^\$live' "$STATE" 2>/dev/null || pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper >/dev/null 2>&1
fi

# remember the choice: from here it is read by the pill, lock screen and autorun
mkdir -p "$(dirname "$STATE")"
{
    printf '# File is generated automatically when switching wallpapers.\n'
    printf '# Hyprland does not include it: changing wallpaper should not touch config.\n'
    printf '$wallpaper = %s\n' "$WALL"
} > "$STATE"

# ------------------------------------------------------------- hyprpaper
# In 0.8, hyprpaper changed its config format: instead of the preload/wallpaper pair
# now the block wallpaper { monitor, path, fit_mode }.
#
# The tricky thing is that he doesn’t complain about the old format - he just doesn’t
# sees: “Monitor eDP-1 has no target, no wp will be created.” Picture at
# This was installed, but only through IPC, that is, while you are sitting in the system. After
# reboot hyprpaper rose with an empty config, and the table remained
# black until you select the wallpaper again.
#
# An empty monitor in the new format means “all screens” - this also removes
# dependence on the list of monitors at the time of recording: connected later
# the screen will receive the same wallpaper.
hyprpaper_new_format() {
    local v maj min
    v=$(hyprpaper --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v" ] || return 1
    maj=${v%%.*}
    min=$(printf '%s' "$v" | cut -d. -f2)
    [ "$maj" -gt 0 ] || [ "$min" -ge 8 ]
}

{
    if hyprpaper_new_format; then
        printf 'wallpaper {\n'
        printf '    monitor =\n'
        printf '    path = %s\n' "$WALL"
        printf '    fit_mode = cover\n'
        printf '}\n'
    else
        printf 'preload = %s\n' "$WALL"
        # one line per monitor: ",path" does not work on this version
        hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
            printf 'wallpaper = %s,%s\n' "$M" "$WALL"
        done
    fi
    printf 'splash = false\nipc = on\n'
} > "$HOME/.config/hypr/hyprpaper.conf"

# setsid: the script is called both from the shell and from autorun - hyprpaper should not
# stay on our pin and keep the channel open after we leave
pgrep -x hyprpaper >/dev/null || { setsid hyprpaper >/dev/null 2>&1 & sleep 1; }
hyprctl hyprpaper preload "$WALL" >/dev/null 2>&1
hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
    hyprctl hyprpaper wallpaper "$M,$WALL" >/dev/null 2>&1
done

# --------------------------------------------------------- login screen background
# Greeter runs as user sddm and cannot look into ~/: home
# the directory is closed. We put the finished blurred copy in a shared directory, which
# created install.sh. Blur in advance: QML blur on greeter costs frames.
SDDM_DIR=/var/lib/zenith
if [ -d "$SDDM_DIR" ] && [ -w "$SDDM_DIR" ] && command -v ffmpeg >/dev/null; then
    # Reducing to 1280 before blur: faster and softer blur
    ffmpeg -y -loglevel error -i "$WALL" \
        -vf "scale=1280:-1,gblur=sigma=28,eq=saturation=0.9" \
        -frames:v 1 "$SDDM_DIR/sddm-bg.jpg" 2>/dev/null \
        && chmod 644 "$SDDM_DIR/sddm-bg.jpg"
fi
