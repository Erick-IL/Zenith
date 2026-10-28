#!/usr/bin/env bash
#
# Gaming Mode (Maximum Performance)


#
# Eliminates all composer and system overhead to focus on the game:

# - Disables animations, blur, shadows and rounded corners (rounding = 0)


# - Removes spacing between windows (gaps_in = 0, gaps_out = 0)


# - Enables immediate tearing (allow_tearing = true, immediate = true) for lower latency


# - Set power profile for performance via D-Bus

# - Pause live wallpapers (mpvpaper) to free up GPU/VRAM


# - Reduz movimento na interface Quickshell (motion off)
# - Ao desativar, restaura perfeitamente o estado anterior
#
# Usage: gamemode.sh [toggle|on|off|status]


STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zenith"
STATE_FILE="$STATE_DIR/gaming-mode"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CMD="qs -c $HOME/.config/zenith ipc call pill"

send_notif() {
    local title="$1"
    local msg="$2"
    busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
        org.freedesktop.Notifications Notify susssasa{sv}i \
        "Zenith" 0 "input-gaming" "$title" "$msg" 0 0 2500 >/dev/null 2>&1 || true
}

enable_gamemode() {
    [ -f "$STATE_FILE" ] && exit 0

    mkdir -p "$STATE_DIR"

    # Salva o perfil de energia atual
    PREV_POWER=$("$SCRIPTS_DIR/power.sh" get 2>/dev/null || echo "balanced")
    [ -z "$PREV_POWER" ] && PREV_POWER="balanced"

    # Saves if live wallpaper is running


    PREV_LIVE=""
    if [ -x "$HOME/.config/hypr/scripts/live_wallpaper.sh" ]; then
        PREV_LIVE=$("$HOME/.config/hypr/scripts/live_wallpaper.sh" state 2>/dev/null || true)
    fi

    cat <<EOF > "$STATE_FILE"
PREV_POWER="$PREV_POWER"
PREV_LIVE="$PREV_LIVE"
EOF

    # 1. Hyprland: Disables animations, blur, shadows, corners, gaps and activates tearing


    hyprctl eval '
    hl.config({
        animations = { enabled = false },
        decoration = {
            rounding = 0,
            shadow = { enabled = false },
            blur = { enabled = false }
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            allow_tearing = true
        },
        misc = {
            vrr = 1
        }
    })
    hl.window_rule({ name = "gaming-tearing", match = { class = ".*" }, immediate = true })
    ' >/dev/null 2>&1

    # 2. Perfil de energia: Performance
    "$SCRIPTS_DIR/power.sh" set performance >/dev/null 2>&1 || true

    # 3. Pause mpvpaper (animated wallpaper) if running


    pkill -STOP -x mpvpaper >/dev/null 2>&1 || true

    # 4. Quickshell: Disable bar animations and notify status


    $SHELL_CMD motion off >/dev/null 2>&1 || true
    $SHELL_CMD gameModeSet on >/dev/null 2>&1 || true

    # 5.Visual notification


    send_notif "🎮 Modo Gaming Ativado" "Desempenho máximo, tearing ativo, sem efeitos ou distrações."
}

disable_gamemode() {
    [ ! -f "$STATE_FILE" ] && exit 0

    # Carrega estado anterior
    PREV_POWER="balanced"
    PREV_LIVE=""
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        . "$STATE_FILE"
    fi

    # 1. Hyprland: Restores theme and animations


    hyprctl eval '
    local theme = require("theme")
    hl.config({
        animations = { enabled = true },
        decoration = {
            rounding = theme.rounding,
            rounding_power = theme.rounding_power,
            active_opacity = theme.active_opacity,
            inactive_opacity = theme.inactive_opacity,
            shadow = {
                enabled = theme.shadow_enabled,
                range = theme.shadow_range,
                render_power = theme.shadow_render_power,
                color = theme.shadow_color
            },
            blur = {
                enabled = theme.blur_enabled,
                size = theme.blur_size,
                passes = theme.blur_passes,
                vibrancy = theme.blur_vibrancy
            }
        },
        general = {
            gaps_in = theme.gaps_in,
            gaps_out = theme.gaps_out,
            allow_tearing = false
        }
    })
    hl.window_rule({ name = "gaming-tearing", match = { class = ".*" }, immediate = false })
    local a = require("lua.animations")
    if a and a.apply then a.apply() end
    ' >/dev/null 2>&1

    # 2. Restaura perfil de energia
    "$SCRIPTS_DIR/power.sh" set "${PREV_POWER:-balanced}" >/dev/null 2>&1 || true

    # 3. Retoma papel de parede animado se foi pausado
    pkill -CONT -x mpvpaper >/dev/null 2>&1 || true
    if [ -n "$PREV_LIVE" ] && ! pgrep -x mpvpaper >/dev/null 2>&1; then
        if [ -x "$HOME/.config/hypr/scripts/live_wallpaper.sh" ]; then
            "$HOME/.config/hypr/scripts/live_wallpaper.sh" set "$PREV_LIVE" >/dev/null 2>&1 || true
        fi
    fi

    # 4. Quickshell: Reactivate animations and notify status


    $SHELL_CMD motion on >/dev/null 2>&1 || true
    $SHELL_CMD gameModeSet off >/dev/null 2>&1 || true

    # Remove arquivo de estado
    rm -f "$STATE_FILE"

    # 5.Visual notification


    send_notif "🎮 Modo Gaming Desativado" "Efeitos visuais e perfil padrão restaurados."
}

case "$1" in
    on|enable)
        enable_gamemode
        ;;
    off|disable)
        disable_gamemode
        ;;
    toggle|"")
        if [ -f "$STATE_FILE" ]; then
            disable_gamemode
        else
            enable_gamemode
        fi
        ;;
    status)
        if [ -f "$STATE_FILE" ]; then
            echo "on"
            exit 0
        else
            echo "off"
            exit 1
        fi
        ;;
    *)
        echo "Uso: $(basename "$0") [toggle|on|off|status]" >&2
        exit 1
        ;;
esac
