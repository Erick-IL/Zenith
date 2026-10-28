#!/usr/bin/env bash
# Update Zenith from the repository.
#
#   update.sh check - is there a new version; prints the lines key=value
#   update.sh apply - download, put on top and restart the shell
#   update.sh version - what version is currently installed
#
# The installed version is stored in ~/.config/zenith/.version - this is a hash
# commit from which they installed. We compare it with the end of the branch on GitHub.
#
# The installer removes the old directories to .bak and puts the new ones entirely. For
# updating is not possible: the settings would go along with the old directory,
# keyboard shortcuts and wallpapers that the person has been hoarding. Therefore, we
# We take it aside before installation and return it after.
set -u

# Test run: put it in your directory and DO NOT restart the shell.
# Without this, the installer would kill the working shell of the system on which
# there is a check going on, and that’s exactly what happened one day.
DRY="${ZENITH_DRYRUN:-0}"

REPO="${ZENITH_REPO:-EnsixD/Zenith}"
BRANCH="${ZENITH_BRANCH:-main}"
# Where to pull from. By default GitHub; a variable can be substituted with a local
# path - the entire chain is checked on it, without touching the working system.
GIT_URL="${ZENITH_GIT:-https://github.com/$REPO.git}"
# The local path has no history API, everything is taken there by git itself
IS_GITHUB=0
case "$GIT_URL" in https://github.com/*) IS_GITHUB=1 ;; esac
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONF/zenith/.version"

# What belongs to a person, not a repository: it must survive the update.
KEEP=(
    "$CONF/zenith/settings.json"
    "$CONF/zenith/clipboard_pins.json"
    "$CONF/zenith/last_wifi_ssid"
    "$CONF/hypr/lua/binds_data.lua"
    # Screen settings: resolution, frequency, scale. Without them after update
    # The panel scale silently returned to 100%. monitors_data.lua reads
    # linker at startup (Lua path), monitors.conf - fallback for Hyprland
    # without Lua. The list is the same as in install.sh.
    "$CONF/hypr/lua/monitors_data.lua"
    "$CONF/hypr/monitors.conf"
    # Terminal Transparency and Digital Intensity - their derivatives
    # They are also undergoing an update, otherwise they were reset to factory settings.
    "$CONF/hypr/lua/term_data.lua"
    "$CONF/zenith/.vibrance"
    # Saturation shader: the repository has no luck with it, a fresh hypr/ is arriving
    # without it, and the linker complains “Failed to check screen shader path”.
    "$CONF/hypr/shaders/vibrance.frag"
    # Selected wallpaper: in the repository your own wallpaper.conf, and without this line
    # it lay on top - after the update the table returned to factory settings.
    "$CONF/hypr/wallpaper.conf"
    "$CONF/hypr/hyprpaper.conf"
    "$CONF/niri/config.kdl"
    # Пользовательские настройки терминала foot: основной конфиг и overrides
    "$CONF/foot/foot.ini"
    "$CONF/foot/custom.ini"
    "$CONF/foot/zenith-theme"
    # Пользовательские настройки shell fish
    "$CONF/fish/config.fish"
    "$CONF/fish/custom.fish"
    "$CONF/fish/fish_variables"
    # Пользовательские настройки fastfetch
    "$CONF/fastfetch/config.jsonc"
    "$CONF/fastfetch/custom.jsonc"
    # Пользовательский конфиг voxtype
    "$CONF/voxtype/config.toml"
    # Пользовательский конфиг nano
    "$HOME/.nanorc"
)
KEEP_DIRS=(
    "$CONF/hypr/wallpaper"
)

# The same, but softly: we return only what is not in the fresh installation. B
# zenith/assets contains our files (logo, desktop entry), and everything that
# the man put it there himself. When returning the entire catalog, we put the old logo
# over the new one - the shell was updated, but the icon in notifications remained
# the same.
KEEP_DIRS_SOFT=(
    "$CONF/zenith/assets"
)

have() { command -v "$1" >/dev/null 2>&1; }

current() { [ -f "$STATE" ] && cat "$STATE" || echo ""; }

# Hash and header of the last commit. Via API - with one request we receive and
# both; without it, ls-remote remains, which returns only the hash.
remote_info() {
    local sha="" subject=""
    if [ "$IS_GITHUB" != "1" ]; then
        # local repository: both the hash and the header are provided by git itself
        sha="$(git ls-remote "$GIT_URL" "$BRANCH" 2>/dev/null | cut -f1)"
        subject="$(git --git-dir="$GIT_URL/.git" log -1 --format=%s "$BRANCH" 2>/dev/null \
                   || git -C "$GIT_URL" log -1 --format=%s "$BRANCH" 2>/dev/null)"
        printf '%s\t%s\n' "$sha" "$subject"
        return
    fi
    if have curl; then
        local json
        json="$(curl -fsSL --max-time 8 \
            "https://api.github.com/repos/$REPO/commits/$BRANCH" 2>/dev/null)"
        if [ -n "$json" ]; then
            sha="$(printf '%s' "$json" | sed -n 's/.*"sha": *"\([0-9a-f]\{40\}\)".*/\1/p' | head -1)"
            # In a commit message, the header is separated from the body by the pair \n -
            # This is the only one suitable for notification.
            subject="$(printf '%s' "$json" \
                | tr '\n' ' ' \
                | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p' | head -1 \
                | sed 's/\\n.*//')"
        fi
    fi
    if [ -z "$sha" ] && have git; then
        sha="$(git ls-remote "$GIT_URL" "$BRANCH" 2>/dev/null | cut -f1)"
    fi
    printf '%s\t%s\n' "$sha" "$subject"
}

cmd_check() {
    local cur_ver rem_ver cur_sha sha subject
    cur_ver="$(current_version)"
    rem_ver="$(remote_version)"
    cur_sha="$(current)"
    IFS=$'\t' read -r sha subject <<<"$(remote_info)"

    if [ -z "$rem_ver" ] && [ -z "$sha" ]; then
        echo "status=offline"
        echo "current=${cur_sha:-$cur_ver}"
        exit 2
    fi
    echo "current=$cur"
    echo "latest=$sha"
    echo "subject=$subject"
    # Version unknown (not installed by the installer) - offer update
    # You can’t do it at random: a person won’t understand why.
    if [ -z "$cur" ]; then
        echo "status=unknown"
    elif [ -n "$rem_ver" ] && [ -n "$cur_ver" ]; then
        # Обновление срабатывает только когда меняется версия в репозитории!
        if version_gt "$rem_ver" "$cur_ver"; then
            echo "status=behind"
        else
            echo "status=current"
        fi
    elif [ "$active_ver" = "$target_ver" ]; then
        echo "status=current"
    else
        echo "status=behind"
    fi
}

# A snapshot of the live state of the screens in settings.json.
#
# The scale can also be set outside the Display panel - by editing the config or one-time
# hyprctl. Then it is not in either monOverrides or monitors_data.lua, and save
# nothing: update returns 100%. Here, before installation, we add in
# monOverrides the current scale of those monitors that are not there yet - and it
# goes into stash along with settings.json, and after the update the shell will roll back
# him herself. We touch only screens with a scale other than 100%: there is no need for default ones
# nail to a specific regime.
snapshot_live_monitors() {
    have hyprctl && have jq || return 0
    local cfg="$CONF/zenith/settings.json"
    [ -f "$cfg" ] || return 0
    local live; live="$(hyprctl -j monitors 2>/dev/null)" || return 0
    [ -n "$live" ] && [ "$live" != "null" ] || return 0

    # monOverrides is a string with JSON inside; empty - take {}
    local cur; cur="$(jq -r '.monOverrides // ""' "$cfg")"
    case "$cur" in ""|null) cur="{}" ;; esac

    local merged
    merged="$(jq -cn --argjson cur "$cur" --argjson live "$live" '
        reduce $live[] as $m ($cur;
            if has($m.name) then .
            elif ((($m.scale * 100) | round) == 100) then .
            else . + { ($m.name): {
                w:  $m.width,
                h:  $m.height,
                rr: ($m.refreshRate | round),
                scale: $m.scale,
                transform: ($m.transform // 0),
                vrr: false,
                pos: "\($m.x)x\($m.y)"
            } } end)
    ' 2>/dev/null)" || return 0
    [ -n "$merged" ] && [ "$merged" != "$cur" ] || return 0

    local tmp; tmp="$(mktemp)"
    if jq --arg mo "$merged" '.monOverrides = $mo' "$cfg" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$cfg"
        # Rebuild the linker config from the updated settings.json so that
        # the new monitors_data.lua was also stashed and survived the installation.
        [ -x "$CONF/zenith/scripts/genmonitors.sh" ] \
            && "$CONF/zenith/scripts/genmonitors.sh" >/dev/null 2>&1
    else
        rm -f "$tmp"
    fi
}

stash_user_state() {
    # Before the stash, remove the live scale in settings.json - otherwise it will be set bypass
    # the panel would disappear: there would be nothing to save.
    snapshot_live_monitors

    # Stash next to the config, and not in /tmp: tmpfs is almost everywhere, that is
    # RAM. From the one who downloaded the wallpaper set, in hypr/wallpaper
    # hundreds of megabytes lie - they went into memory entirely, and on a machine without
    # the reserve went into pumping. We transfer directories: within one
    # section is a renaming and does not depend on the volume.
    STASH="$CONF/.zenith-update-stash"
    rm -rf "$STASH"; mkdir -p "$STASH"
    local f
    for f in "${KEEP[@]}"; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        mkdir -p "$STASH/$(dirname "${f#$HOME/}")"
        cp -a "$f" "$STASH/${f#$HOME/}"
    done
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$f" ] || continue
        mkdir -p "$STASH/$(dirname "${f#$HOME/}")"
        mv "$f" "$STASH/${f#$HOME/}" 2>/dev/null \
            || cp -a "$f" "$STASH/${f#$HOME/}"
    done
}

restore_user_state() {
    [ -n "${STASH:-}" ] && [ -d "$STASH" ] || return 0
    local f
    for f in "${KEEP[@]}"; do
        if [ -e "$STASH/${f#$HOME/}" ] || [ -L "$STASH/${f#$HOME/}" ]; then
            mkdir -p "$(dirname "$f")"
            if [ "$f" = "$CONF/zenith/settings.json" ] && command -v jq >/dev/null 2>&1 && [ -f "$f" ]; then
                local tmp_json
                tmp_json="$(mktemp)"
                if jq -s '.[0] * .[1]' "$f" "$STASH/${f#$HOME/}" > "$tmp_json" 2>/dev/null; then
                    mv "$tmp_json" "$f"
                else
                    rm -f "$tmp_json"
                    cp -a "$STASH/${f#$HOME/}" "$f"
                fi
            else
                cp -a "$STASH/${f#$HOME/}" "$f"
            fi
        fi
    done
    # We return directories with their contents, not their entirety: the installer has already created
    # an empty directory with the same name, and `cp -r dir dst` would put our files
    # inside it at the second level - the person’s wallpaper went into wallpaper/wallpaper.
    # The files from the fresh installation remain: we put ours on top.
    local item base
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$STASH/${f#$HOME/}" ] || continue
        # soft directory: fresh shell files stay in place
        local soft=0 d
        for d in "${KEEP_DIRS_SOFT[@]}"; do [ "$d" = "$f" ] && soft=1; done
        mkdir -p "$f"
        # One at a time and transfer: a set of wallpapers is returned instantly.
        for item in "$STASH/${f#$HOME/}"/* "$STASH/${f#$HOME/}"/.[!.]*; do
            [ -e "$item" ] || [ -L "$item" ] || continue
            base="$(basename "$item")"
            rm -rf "$f/$base"
            mv "$item" "$f/$base" 2>/dev/null || cp -a "$item" "$f/$base"
        done
    done
    rm -rf "$STASH"
}

# Headers of commits between two versions - one per line.
# What to show a person after the update. The commit headers are the input, and
# not all of them are news: version upgrades, README and .gitignore changes
# absolutely nothing for him. We weed them out, and at the same time we remove repetitions: after
# rebasing, the same header is compared twice.
changelog_filter() {
    grep -v '^Merge ' \
        | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
        | grep -viE '^(update|bump) (the )?(readme|docs|version)\b' \
        | awk '!seen[$0]++' \
        | head -40
}

write_changelog() {
    local from="$1" to="$2" out="$CONF/zenith/.whatsnew"
    [ -n "$from" ] || return 0
    if [ "$IS_GITHUB" != "1" ]; then
        {
            printf '%s\n' "$to"
            git -C "$GIT_URL" log --format=%s "$from..$to" 2>/dev/null | changelog_filter
        } > "$out"
        return 0
    fi
    have curl || return 0

    # We take the latest commits of the branch, and not compare with...to.
    #
    # The comparison also returned the full diffs of each file in each
    # commit, so the answer grew along with the lag: 0.4 MB for forty
    # commits, 2 MB on two hundred. Whose shell has not been updated for six months,
    # The update was delayed on this request for seconds. Even worse, the comparison
    # there is a limit of 250 commits - then the list came silently truncated.
    #
    # The changelog is still cut off at forty lines, so ask
    # There is no need for more than sixty commits under any lag. Reply to
    # such a request is always the same size - about 0.3 MB - and does not depend on
    # how long ago a person was renewed.
    local json
    json="$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/$REPO/commits?sha=$BRANCH&per_page=60" 2>/dev/null)" \
        || return 0
    [ -n "$json" ] || return 0

    # We go from fresh to old and stop at the version that is in
    # human: everything that is higher than it is new. Not found (more behind
    # than sixty commits) - we show everything that arrived, and the filter
    # will cut to forty.
    {
        printf '%s\n' "$to"
        if have jq; then
            printf '%s' "$json" \
                | jq -r '.[] | "\(.sha)\t\(.commit.message | split("\n")[0])"' 2>/dev/null \
                | awk -F'\t' -v from="$from" '$1 == from { exit } { print $2 }' \
                | changelog_filter
        else
            # Without jq - line by line. The order of the fields in the response is constant: sha
            # Each commit comes before its message.
            printf '%s' "$json" \
                | grep -oE '"sha": *"[0-9a-f]{40}"|"message": *"[^"]*"' \
                | sed 's/"sha": *"/S/; s/"message": *"/M/; s/"$//; s/\\n.*//' \
                | awk -v from="$from" '
                    /^S/ { sha = substr($0, 2); next }
                    /^M/ {
                        # Each commit has sha repeated twice in a row
                        # (the commit itself and its tree) - take the first
                        if (sha == from) exit
                        print substr($0, 2)
                    }' \
                | changelog_filter
        fi
    } > "$out"
}

cmd_apply() {
    have git || { echo "status=error"; echo "error=nogit"; exit 1; }

    # Сразу сообщаем оболочке о начале скачивания, чтобы шкала не замирала на 0%
    echo "step=download"

    local sha subject
    IFS=$'\t' read -r sha subject <<<"$(remote_info)"
    [ -n "$sha" ] || { echo "status=error"; echo "error=offline"; exit 1; }

    # the variable is deliberately not local: trap is triggered when exiting the script,
    # when the function's scope is already closed
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}"' EXIT

    # The clone could come from a previous copy of the script - when self-updating it
    # I've already downloaded everything. We check that this is really our directory and not
    # left over from someone else's launch: without install.sh there is nothing further to do.
    if [ -n "${ZENITH_SRC:-}" ] && [ -f "$ZENITH_SRC/install.sh" ]; then
        rm -rf "$tmp"
        tmp="$(dirname "$ZENITH_SRC")"
        trap 'rm -rf "${tmp:-}"' EXIT
    else
        echo "step=download"
        # --no-tags: tags in the shell are not used, but are taken along with
        # branches. One commit without history is all that is needed for installation.
        git clone --depth 1 --single-branch --no-tags --branch "$BRANCH" \
            "$GIT_URL" "$tmp/src" >/dev/null 2>&1 \
            || { echo "status=error"; echo "error=download"; exit 1; }
    fi

    # The script updates itself.
    #
    # Everything that follows - saving settings, list of changes, restarting -
    # makes the copy that the person already has, that is, the OLD one. So
    # any change in the update itself would take effect only from the next
    # times, and until then it would have been repaired manually. Therefore, if in a fresh clone
    # the script is different, we transfer the work to him - once, according to the flag, so as not
    # loop.
    if [ "${ZENITH_SELFEXEC:-0}" != "1" ] && [ -f "$0" ] \
       && [ -f "$tmp/src/zenith/scripts/update.sh" ] \
       && ! cmp -s "$tmp/src/zenith/scripts/update.sh" "$0"; then
        echo "step=selfupdate"
        fresh="$(mktemp)"
        cp "$tmp/src/zenith/scripts/update.sh" "$fresh"
        trap - EXIT
        # We give the already downloaded clone to the fresh script, rather than force it to download
        # second time. Cloning is the longest update step, and when changing
        # update.sh itself it went twice in a row, doubling the wait on the flat
        # place. The catalog is taken away by the person who finished it.
        ZENITH_SRC="$tmp/src" ZENITH_SELFEXEC=1 bash "$fresh" apply
        rc=$?
        rm -f "$fresh"
        rm -rf "$tmp"
        return $rc
    fi

    echo "step=backup"
    # We are reading the previous version now: the installer will stamp .version again,
    # and after it there will be nothing to compare with.
    local was
    was="$(current)"
    stash_user_state

    # We install with the same installer as from scratch: one logic for installation and
    # update means that an updated car is no different from a fresh one.
    # The packages, login theme and bootloader are not touched: they are installed once.
    # --no-restart is required, not just in the test run.
    #
    # The installer restarts the shell itself: pkill -x qs. But this script
    # launched FROM the shell and died along with it right here - until recovery
    # settings, to the list of changes and to the version mark. From the side update
    # looked broken and was offered again every time it was launched. Therefore
    # The installer does not touch the shell, but we do the restart ourselves at the very end.
    echo "step=install"
    if ! (cd "$tmp/src" && bash ./install.sh --no-deps --no-sddm --no-grub \
            --no-services --no-wallpapers --no-restart --no-backup --yes >"$tmp/log" 2>&1); then
        restore_user_state
        echo "status=error"
        echo "error=install"
        echo "log=$tmp/log"
        exit 1
    fi

    # The login screen theme lives in /usr/share, and the update did not touch it: it
    # is installed with sudo, but there is nowhere to ask for the password for the update - it comes from
    # panels, without terminal. It turned out that the topic died down on the version with
    # which it was installed once, and all the edits to the login screen are up to the person
    # they just didn’t get there.
    #
    # Update via pkexec: the shell has a polkit agent, and it will show
    # a regular password request window. Refused or there is no agent - we pass
    # silently, the update should not crash because of this.
    if [ -d /usr/share/sddm/themes/zenith ] \
       && [ -d "$tmp/src/sddm/zenith" ] \
       && ! diff -rq /usr/share/sddm/themes/zenith "$tmp/src/sddm/zenith" >/dev/null 2>&1
    then
        echo "step=greeter"
        if command -v pkexec >/dev/null 2>&1; then
            pkexec sh -c '
                rm -rf /usr/share/sddm/themes/zenith &&
                cp -r "$1" /usr/share/sddm/themes/zenith
            ' _ "$tmp/src/sddm/zenith" >/dev/null 2>&1 || true
        fi
    fi

    echo "step=restore"
    restore_user_state

    # The new version could add dependencies, but we installed it with --no-deps:
    # grab packages without asking, and even through sudo from under the button in
    # settings is not what is expected from the update. Therefore we only call
    # them, but the person will install them himself. We take the list from the installer so that he does not
    # parted ways with the present.
    #
    # We put it in a file next to the list of changes: shell after update
    # restarts, and there will be no one to read the output of this script. Screen
    # “What’s new” will show both news at once and delete both files.
    missing="$(cd "$tmp/src" && bash ./install.sh --print-missing 2>/dev/null | tr '\n' ' ')"
    missing="${missing% }"
    if [ -n "$missing" ]; then
        printf '%s\n' "$missing" > "$CONF/zenith/.missingdeps"
        echo "missing=$missing"
    else
        rm -f "$CONF/zenith/.missingdeps"
    fi

    # And the opposite: what the shell installed before, but now does not use. Delete
    # we won’t do it ourselves - a person could install a waybar or tofi for himself, and someone else’s
    # they don't touch him. We just call it.
    obsolete="$(cd "$tmp/src" && bash ./install.sh --print-obsolete 2>/dev/null | tr '\n' ' ')"
    obsolete="${obsolete% }"
    if [ -n "$obsolete" ]; then
        printf '%s\n' "$obsolete" > "$CONF/zenith/.obsoletedeps"
        echo "obsolete=$obsolete"
    else
        rm -f "$CONF/zenith/.obsoletedeps"
    fi

    # List of changes between what was standing and what was standing. Shell
    # will show it once after a restart and the file will be erased. History is taken
    # from GitHub: the clone is made small, it does not contain it.
    write_changelog "$was" "$sha"
    printf '%s\n' "$sha" > "$STATE"
    local new_ver
    new_ver="$(current_version)"
    [ -n "$new_ver" ] && printf '%s\n' "$new_ver" > "$CONF/zenith/VERSION"

    # Пользовательские post-update скрипты
    local hook
    for hook in "$CONF/zenith/custom/post-update.sh" "$CONF/zenith/post-update.sh"; do
        if [ -x "$hook" ]; then
            "$hook" >/dev/null 2>&1 || true
        fi
    done

    echo "step=restart"
    if [ "$DRY" = "1" ]; then
        echo "status=done"
        echo "version=$sha"
        return 0
    fi
    # We print the result BEFORE restarting: the shell reads the output of this script, and
    # After pkill there will be no one left to read it.
    echo "status=done"
    echo "version=$sha"

    # Restart in a separate session: it will survive the death of both the shell and us
    # themselves. The pause allows the shell to finish reading the output and close like a human.
    if have hyprctl && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        setsid sh -c '
            sleep 1
            hyprctl reload >/dev/null 2>&1
            [ -x "'"$CONF"'/hypr/scripts/switch_theme.sh" ] \
                && "'"$CONF"'/hypr/scripts/switch_theme.sh" --restore >/dev/null 2>&1
            pkill -x qs >/dev/null 2>&1
            sleep 1
            exec qs -c "'"$CONF"'/zenith"
        ' >/dev/null 2>&1 &
    elif [ -n "${NIRI_SOCKET:-}" ] || [ "${XDG_CURRENT_DESKTOP,,}" = "niri" ]; then
        setsid sh -c '
            sleep 1
            command -v niri >/dev/null 2>&1 && niri msg action load-config >/dev/null 2>&1
            pkill -x qs >/dev/null 2>&1
            sleep 1
            exec qs -c "'"$CONF"'/zenith"
        ' >/dev/null 2>&1 &
    else
        setsid sh -c '
            sleep 1
            pkill -x qs >/dev/null 2>&1
            sleep 1
            exec qs -c "'"$CONF"'/zenith"
        ' >/dev/null 2>&1 &
    fi
}

case "${1:-check}" in
    check)   cmd_check ;;
    apply)   cmd_apply ;;
    version) current_version ;;
    *) echo "usage: update.sh [check|apply|version]" >&2; exit 1 ;;
esac
