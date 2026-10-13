#!/usr/bin/env bash
# Zenith Cheat Sheet CLI & Pill Launcher
# Sem Rofi - 100% nativo do Zenith / Quickshell
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ -t 1 ] && [ -n "$1" ]; then
    # If run interactively in the terminal with argument, print the result in the terminal

    exec python3 "$SCRIPT_DIR/cheat_worker.py" "$@" | jq -r '
        if .ok then
            "\u001b[1;34m󰞋 " + .query + " (" + .source + ")\u001b[0m\n" +
            "\u001b[90m" + .description + "\u001b[0m\n\n" +
            (.examples[] | "\u001b[37m- " + .desc + ":\u001b[0m\n  \u001b[1;32m" + .cmd + "\u001b[0m\n")
        else
            "\u001b[1;31m󰅖 " + .error + "\u001b[0m"
        end' 2>/dev/null || exec python3 "$SCRIPT_DIR/cheat_worker.py" "$@"
else
    # Otherwise, open directly in the Capsule (Dynamic Island)


    exec qs -c "$HOME/.config/zenith" ipc call pill cheat
fi
