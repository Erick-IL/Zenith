#!/usr/bin/env bash
# Places focus on the application window; if there is no window, it launches the application.
#
#   focusapp.sh <hint>
#
# hint - either desktop entry from the notification (org.telegram.desktop), or name
# applications (Telegram Desktop). Needed to click on the notification: the chat itself
# opens the application (action “default”), and our task is to be
# on the desktop where it lives.

hint="$1"
[ -n "$hint" ] || exit 0
base="${hint%.desktop}"

# We look for a window by class/initialClass/title, without looking at the register. At the same time
# try the last part of the entry: Telegram class = org.telegram.desktop,
# and the application can be called simply “telegram”.
addr=$(hyprctl -j clients 2>/dev/null | jq -r --arg h "$base" '
    ($h | ascii_downcase) as $l
    | ($l | split(".") | last) as $short
    | map(select(
          ((.class // "") | ascii_downcase | contains($l))
          or ((.initialClass // "") | ascii_downcase | contains($l))
          or ((.class // "") | ascii_downcase | contains($short))
          or ((.initialClass // "") | ascii_downcase | contains($short))
          or ((.title // "") | ascii_downcase | contains($short))
      ))
    | .[0].address // empty')

if [ -n "$addr" ]; then
    # focus itself flips to the table where the window lies.
    #
    # The new config parser only accepts the Lua form of dispatchers, while the old one accepts
    # only the former; both of them exit with a zero code upon failure,
    # Therefore, we look at the response itself, and not at the return code.
    out=$(hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" 2>&1)
    case "$out" in
        ok*) ;;
        *) hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 ;;
    esac
    exit 0
fi

# There is no window - launch from the desktop file
for d in "$HOME/.local/share/applications" /usr/share/applications \
         /var/lib/flatpak/exports/share/applications \
         "$HOME/.local/share/flatpak/exports/share/applications"; do
    f="$d/$base.desktop"
    if [ -f "$f" ]; then
        gio launch "$f" >/dev/null 2>&1 &
        exit 0
    fi
done

# Last try: command with this name
short="${base##*.}"
for c in "$base" "$short"; do
    if command -v "$c" >/dev/null 2>&1; then
        setsid "$c" >/dev/null 2>&1 &
        exit 0
    fi
done
exit 0
