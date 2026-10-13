#!/usr/bin/env bash
# Syntax check of the QML pill - before it is launched.
#
# A typo in QML drops the entire shell, and learn about it on a live system,
# being left without a panel is unpleasant. qmllint reads files without running them.
#
# Only syntax is checked. Deep mode (-U) is useless here: types
# There is no Quickshell in qmltypes, and it produces hundreds of “Process was not found” -
# in such noise the real mistake is lost.
#
# qmllint from Qt 6.11.1 reports an error only with a return code: no line,
# It no longer prints any text (it did in 6.9). Therefore the script calls
# file, and follow the line to the shell itself - `qs -c zenith` will print it
# with a position.
#
# Qt 6.11 cannot handle two files at all: qmllint and qmlformat stumble over
# the annotation `function foo(): void`, although it is legal and required - without
# Quickshell type instructions do not expose the function externally, but go through IPC
# all combinations of Hyprland. This is a tool bug, not a code bug, so
# files are skipped with an explicit mark, and are not corrected for the parser.
#
#   check.sh check ~/.config/zenith
#   check.sh DIR check another directory

DIR="${1:-$HOME/.config/zenith}"
cd "$DIR" 2>/dev/null || { echo "missing directory $DIR" >&2; exit 2; }

command -v qmllint >/dev/null || { echo "qmllint is not installed" >&2; exit 2; }

fail=0
skipped=()

for f in *.qml; do
    [ -e "$f" ] || continue
    # `): void` and `): var` - what the Qt 6.11 parser crashes on
    if grep -qE '\): (void|var)\b' "$f"; then
        skipped+=("$f")
        continue
    fi
    if ! out=$(qmllint "$f" 2>&1); then
        echo "✗ $f"
        [ -n "$out" ] && printf '%s\n' "$out"
        fail=1
    fi
done

if [ "${#skipped[@]}" -gt 0 ]; then
    printf '· пропущено (Qt не разбирает «: void»): %s\n' "${skipped[*]}"
fi

if [ "$fail" -eq 0 ]; then
    echo "✓ syntax is OK"
fi

# ------------------------------------------------------------- translations
# The "what's new" screen shows commit titles while history is being kept
# in English: without a line in the WhatsNewView dictionary, the title will not appear on
# interface language. It’s easy to forget - the commit and the dictionary are in different places,
# so we check here until it’s launched.
#
# Only startup from a clone is checked: there is no history in ~/.config/zenith.
if [ -d .git ] && command -v git >/dev/null && [ -f zenith/WhatsNewView.qml ]; then
    # Only what has not yet left: the released commits have already shown the screen,
    # and there is no need to translate them retroactively. Without upstream we take everything after
    # the last version raised is the last release.
    range="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
    if [ -n "$range" ]; then
        range="$range..HEAD"
    else
        last_rel="$(git log --format='%H %s' -200 \
                    | grep -im1 '^[0-9a-f]* shell: bump version' | cut -d' ' -f1)"
        range="${last_rel:+$last_rel..HEAD}"
    fi

    missing=0
    while IFS= read -r subject; do
        [ -n "$subject" ] || continue
        grep -qF "\"$subject\":" zenith/WhatsNewView.qml || {
            [ "$missing" -eq 0 ] && echo "missing translation in WhatsNewView.qml:"
            echo "    $subject"
            missing=$((missing + 1))
        }
    done < <(git log --format=%s $range 2>/dev/null \
             | grep -v '^Merge ' \
             | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
             | grep -viE '^(update|bump) (the )?(readme|docs|version)\b')

    if [ "$missing" -gt 0 ]; then
        fail=1
    else
        echo "✓ all unreleased commits have translations"
    fi

    # The downside: the dictionary should not accumulate translations to what is already
    # will never be shown. No one will look beyond forty significant commits -
    # exactly on them update.sh truncates the list (changelog_filter, head -40),
    # no matter how many versions a person misses.
    stale=0
    window="$(git log --format=%s -300 \
              | grep -v '^Merge ' \
              | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
              | grep -viE '^(update|bump) (the )?(readme|docs|version)\b' \
              | head -40)"
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        printf '%s\n' "$window" | grep -qxF "$entry" || {
            [ "$stale" -eq 0 ] && echo "obsolete in WhatsNewView.qml (can be removed):"
            echo "    $entry"
            stale=$((stale + 1))
        }
    done < <(grep -oP '^\s+"\K[^"]+(?=":$)' zenith/WhatsNewView.qml)

    [ "$stale" -eq 0 ] && echo "✓ dictionary has no obsolete entries"

    # The list of unnecessary packages is kept for the sake of those who installed the shell before
    # how they were no longer needed. After several versions there are no such copies
    # remains, and the list itself becomes the garbage for the sake of cleaning
    # started. We remind you that it is not our business to delete the author.
    ver="$(grep -oP 'property string version: "\K[^"]+' zenith/shell.qml)"
    if [ -n "$ver" ] && [ -f install.sh ]; then
        cur_patch="${ver##*.}"
        rot=0
        while IFS='|' read -r pkg since; do
            [ -n "$since" ] || continue
            # we compare only the last digit: the version increases by 0.0.1
            age=$(( cur_patch - ${since##*.} ))
            if [ "$age" -ge 5 ]; then
                [ "$rot" -eq 0 ] && echo "obsolete unnecessary package list in install.sh:"
                echo "    $pkg (не нужен с $since, сейчас $ver — прошло $age выпусков)"
                rot=$((rot + 1))
            fi
        done < <(sed -n '/^OBSOLETE_PKGS=(/,/^)/p' install.sh \
                 | grep -oP '^\s+"\K[^"]+')
        [ "$rot" -eq 0 ] && echo "✓ unnecessary package list still valid"
    fi
fi

exit "$fail"
