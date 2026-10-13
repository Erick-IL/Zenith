#!/usr/bin/env bash
# Zenith Notes launcher
# Opens a dedicated note app (Obsidian, Logseq, MarkText, Typora) or falls back to foot + nano

NOTES_DIR="${XDG_DOCUMENTS_DIR:-$HOME/Documents}/Notes"
[ -d "$NOTES_DIR" ] || NOTES_DIR="$HOME/Notes"
mkdir -p "$NOTES_DIR"

NOTE_FILE="$NOTES_DIR/notes.md"
[ -f "$NOTE_FILE" ] || [ -f "$NOTES_DIR/notes.txt" ] || touch "$NOTE_FILE"
[ -f "$NOTES_DIR/notes.txt" ] && [ ! -f "$NOTE_FILE" ] && NOTE_FILE="$NOTES_DIR/notes.txt"

# 1. Check for dedicated GUI note-taking apps
for app in obsidian logseq marktext typora; do
    if command -v "$app" >/dev/null 2>&1; then
        exec "$app" "$NOTES_DIR"
    fi
done

# 2. Terminal-based note editor
EDITOR_CMD="${EDITOR:-nano}"
if command -v footclient >/dev/null 2>&1; then
    exec footclient -T "Notes — Zenith" -e "$EDITOR_CMD" "$NOTE_FILE"
elif command -v foot >/dev/null 2>&1; then
    exec foot -T "Notes — Zenith" -e "$EDITOR_CMD" "$NOTE_FILE"
elif command -v xdg-open >/dev/null 2>&1; then
    exec xdg-open "$NOTE_FILE"
fi
