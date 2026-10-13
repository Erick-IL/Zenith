#!/usr/bin/env bash
# Zenith Native Color Picker
HIST_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/zenith/colors.txt"
mkdir -p "$(dirname "$HIST_FILE")"

COLOR=$(hyprpicker -l 2>/dev/null)
if [ -n "$COLOR" ]; then
    printf '%s' "$COLOR" | wl-copy
    # Saves to history (single, top, up to 20 colors)


    sed -i "/^$COLOR\$/d" "$HIST_FILE" 2>/dev/null || true
    printf '%s\n' "$COLOR" | cat - "$HIST_FILE" 2>/dev/null | head -n 20 > "$HIST_FILE.tmp" && mv "$HIST_FILE.tmp" "$HIST_FILE"
    
    hyprctl notify 1 3500 0 "Cor copiada: $COLOR" >/dev/null 2>&1 || true
    command -v notify-send >/dev/null 2>&1 && notify-send -a Zenith "Color Picker" "Cor $COLOR copiada para a área de transferência!"
    (sleep 0.15; command -v wtype >/dev/null 2>&1 && wtype "$COLOR") &
    printf '%s' "$COLOR"
fi
