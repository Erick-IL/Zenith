#!/usr/bin/env bash
# Backend of the pill explorer.
#
#   list DIR -> string type|name|size|mtime|mime
#                            type: d (catalogue) | f (file)
#   apps PATH -> how to open: desktop file|Name|Icon
#                            The default application comes first
#   open PATH [DESKTOP] -> open (without DESKTOP - default application)
#   mkdir DIR NAME -> create folder
#   rename PATH NEWNAME -> rename
#   trash PATH -> to trash (reversible, unlike rm)
#   places -> bookmarks: key|path|signature
#   copy DST SRC... -> copy to directory
#   move DST SRC... -> move to directory
#
# copy and move print the lines "PROGRESS <percent>" to stdout: pill draws
# a stripe across them. Copying gigabytes otherwise looks like a hangup -
# the file does not appear, and it is impossible to understand whether the work is going on or not.

py() { python3 "$@"; }

# ---------------------------------------------------------------- progress
# Neither cp nor mv can report how much has already been done, so we look at
# sides: once every quarter of a second we measure how much the targets have grown. rsync
# would show the same thing itself, but it is not included in base, but rather a pull dependency
# I don’t want it for the stripes.
#
# We measure precisely the goals, and not the entire destination catalog: the destination can
# be the home folder, and du on it every 250 ms would cost more than itself
# copying.
PROGRESS_PID=""

progress_start() {   # $1 - total size of sources, further than the path of goals
    local total=$1; shift
    [ "$total" -gt 0 ] 2>/dev/null || return 0
    local targets=("$@")
    (
        while :; do
            local cur
            cur=$(du -sbc "${targets[@]}" 2>/dev/null | tail -1 | cut -f1)
            if [ -n "$cur" ]; then
                local pct=$(( cur * 100 / total ))
                [ "$pct" -gt 99 ] && pct=99   # 100 is printed by the call itself
                printf 'PROGRESS %d\n' "$pct"
            fi
            sleep 0.25
        done
    ) &
    PROGRESS_PID=$!
}

progress_kill() {
    [ -n "$PROGRESS_PID" ] && kill "$PROGRESS_PID" 2>/dev/null
    PROGRESS_PID=""
}

progress_stop() {
    progress_kill
    printf 'PROGRESS 100\n'
}

# Name free in the destination directory: do not overwrite the existing one silently,
# and add the number. There are no words here on purpose - the script does not know the language
# interface.
uniq_target() {   # $1 - destination directory, $2 - name
    local dst=$1 name=$2
    local target="$dst/$name"
    [ -e "$target" ] || { printf '%s' "$target"; return; }
    local base="${name%.*}" ext="${name##*.}" n=2
    while [ -e "$target" ]; do
        if [ "$base" = "$name" ]; then target="$dst/$name-$n"
        else                           target="$dst/$base-$n.$ext"; fi
        n=$((n + 1))
    done
    printf '%s' "$target"
}

case "$1" in
    # list <directory> [hidden]
    # hidden — show files from a dot. Almost everything in the home directory
    # the interesting stuff starts with it (.config, .local), and hide them
    # means hiding exactly what they come here for.
    list)
        DIR="${2:-$HOME}"
        DIR="${DIR/#\~/$HOME}"
        py - "$DIR" "${3:-}" <<'EOF'
import os, sys, mimetypes

d = sys.argv[1]
show_hidden = len(sys.argv) > 2 and sys.argv[2] == 'hidden'
try:
    entries = list(os.scandir(d))
except OSError:
    sys.exit(0)

dirs, files = [], []
for e in entries:
    if e.name.startswith('.') and not show_hidden:
        continue
    try:
        st = e.stat()
    except OSError:
        continue
    if e.is_dir():
        dirs.append((e.name, 0, int(st.st_mtime), 'inode/directory'))
    else:
        mime = mimetypes.guess_type(e.name)[0] or 'application/octet-stream'
        files.append((e.name, st.st_size, int(st.st_mtime), mime))

key = lambda t: t[0].lower()
for name, size, mtime, mime in sorted(dirs, key=key):
    print(f"d|{name}|{size}|{mtime}|{mime}")
for name, size, mtime, mime in sorted(files, key=key):
    print(f"f|{name}|{size}|{mtime}|{mime}")
EOF
        ;;

    apps)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        MIME=$(xdg-mime query filetype "$P" 2>/dev/null)
        DEFAULT=$(xdg-mime query default "$MIME" 2>/dev/null)
        py - "$MIME" "$DEFAULT" <<'EOF'
import configparser, os, sys

mime, default = sys.argv[1], sys.argv[2]
dirs = [os.path.expanduser("~/.local/share/applications"),
        "/usr/local/share/applications", "/usr/share/applications"]

group = mime.split("/")[0] + "/" if "/" in mime else ""

exact, similar, rest = {}, {}, {}
for d in dirs:
    if not os.path.isdir(d):
        continue
    for fn in os.listdir(d):
        if not fn.endswith(".desktop"):
            continue
        if fn in exact or fn in similar or fn in rest:
            continue
        cp = configparser.RawConfigParser(strict=False)
        try:
            cp.read(os.path.join(d, fn), encoding="utf-8")
            e = cp["Desktop Entry"]
        except Exception:
            continue
        if e.get("NoDisplay", "false").lower() == "true":
            continue
        if e.get("Type", "Application") != "Application":
            continue

        item = (e.get("Name", fn), e.get("Icon", ""))
        mimes = [m for m in e.get("MimeType", "").split(";") if m]
        if mime and mime in mimes:
            exact[fn] = item
        elif group and any(m.startswith(group) for m in mimes):
            similar[fn] = item
        else:
            # Few programs declare all the types that they support.
            # We show the rest - let the choice be up to the person.
            rest[fn] = item

def emit(fn, table):
    name, icon = table[fn]
    print(f"{fn}|{name}|{icon}")

# the default application is the first line, no matter what group it is in
for table in (exact, similar, rest):
    if default in table:
        emit(default, table)
        break

for table in (exact, similar, rest):
    for fn in sorted(table, key=lambda f: table[f][0].lower()):
        if fn != default:
            emit(fn, table)
EOF
        ;;

    open)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        DESKTOP="$3"
        if [ -n "$DESKTOP" ]; then
            for d in "$HOME/.local/share/applications" /usr/local/share/applications \
                     /usr/share/applications; do
                if [ -f "$d/$DESKTOP" ]; then
                    setsid gio launch "$d/$DESKTOP" "$P" >/dev/null 2>&1 &
                    exit 0
                fi
            done
        fi
        setsid xdg-open "$P" >/dev/null 2>&1 &
        ;;

    mkdir)
        D="${2:?}"; N="${3:?}"
        D="${D/#\~/$HOME}"
        mkdir -p "$D/$N"
        ;;

    rename)
        P="${2:?}"; N="${3:?}"
        P="${P/#\~/$HOME}"
        mv -n "$P" "$(dirname "$P")/$N"
        ;;

    trash)
        shift
        for P; do
            P="${P/#\~/$HOME}"
            gio trash "$P" 2>/dev/null || rm -rf -- "$P"
        done
        ;;

    extract)
        SRC="${2:?}"
        DST="${3:-}"
        SRC="${SRC/#\~/$HOME}"
        [ -f "$SRC" ] || exit 1

        if [ -z "$DST" ]; then
            DST="$(dirname "$SRC")"
        fi
        DST="${DST/#\~/$HOME}"
        mkdir -p "$DST" || exit 1

        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -xf "$SRC" -C "$DST"
        elif [[ "$SRC" =~ \.zip$ ]] && command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$SRC" -d "$DST"
        elif [[ "$SRC" =~ \.7z$ ]] && command -v 7z >/dev/null 2>&1; then
            7z x -y -o"$DST" "$SRC"
        elif [[ "$SRC" =~ \.rar$ ]] && command -v unrar >/dev/null 2>&1; then
            unrar x -y "$SRC" "$DST/"
        else
            tar -xf "$SRC" -C "$DST"
        fi
        ;;

    # The destination directory comes first, the sources are listed: so one call
    # transfers at least one file, even the entire selection, and the bar counts
    # the total volume, and not each file again.
    # What is being dragged is already in the destination directory. Prints by
    # one name per line; empty - no matches.
    #
    # We ask separately, rather than figure it out as copying progresses: the decision on
    # the rewrite is accepted by a person, and it must be accepted BEFORE the first file
    # already overwritten. At the same time, the question is asked once for the entire pack, and not
    # file.
    conflicts)
        DST="${2:?}"; shift 2
        DST="${DST/#\~/$HOME}"
        for src; do
            src="${src/#\~/$HOME}"
            name="$(basename "$src")"
            # The file itself does not overlap: the source and the target are the same.
            [ "$src" = "$DST/$name" ] && continue
            [ -e "$DST/$name" ] && printf '%s\n' "$name"
        done
        ;;

    copy|move)
        op="$1"
        DST="${2:?}"
        # What to do with existing names:
        #   keepboth - next to the number (as always)
        #   overwrite - replace
        #   skip - do not touch, leave as is
        MODE="${3:-keepboth}"
        shift 3
        DST="${DST/#\~/$HOME}"
        [ "$#" -gt 0 ] || exit 0

        srcs=(); targets=()
        for src; do
            src="${src/#\~/$HOME}"
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            case "$MODE" in
                overwrite) target="$DST/$name" ;;
                skip)
                    # Already there - just skip this file, the rest are on their way.
                    [ -e "$DST/$name" ] && [ "$src" != "$DST/$name" ] && continue
                    target="$DST/$name"
                    ;;
                *) target="$(uniq_target "$DST" "$name")" ;;
            esac
            srcs+=("$src")
            targets+=("$target")
        done
        [ "${#srcs[@]}" -gt 0 ] || exit 0

        # The shell can be killed along with the panel, and without this the counter would remain
        # orphan: spin forever, traversing the catalog once every quarter of a second.
        trap progress_kill EXIT INT TERM

        total=$(du -sbc "${srcs[@]}" 2>/dev/null | tail -1 | cut -f1)
        progress_start "${total:-0}" "${targets[@]}"

        for i in "${!srcs[@]}"; do
            # When replacing, we demolish the target in advance rather than relying on -f.
            #
            # Both cp and mv, having met the target CATALOG at the target location, place the source
            # INSIDE it: instead of replacing the Photos folder, you would get
            # “Photo/Photo.” For files -f would work, for directories it would not,
            # Therefore, we remove the target ourselves in both cases.
            if [ "$MODE" = "overwrite" ] && [ -e "${targets[$i]}" ] \
               && [ "${srcs[$i]}" != "${targets[$i]}" ]; then
                rm -rf -- "${targets[$i]}"
            fi

            if [ "$op" = "copy" ]; then
                cp -r --no-clobber "${srcs[$i]}" "${targets[$i]}"
            else
                mv -n "${srcs[$i]}" "${targets[$i]}"
            fi
        done

        progress_stop
        ;;

    copypath)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        printf '%s' "$P" | wl-copy
        ;;

    places)
        # The signatures here are draft: the interface translates them by key itself.
        printf 'home|%s|Home\n' "$HOME"
        for k in Downloads Documents Pictures Videos Music Desktop; do
            [ -d "$HOME/$k" ] && printf '%s|%s/%s|%s\n' "${k,,}" "$HOME" "$k" "$k"
        done
        printf 'root|/|System\n'
        # the basket is last: this is not a place where people go on business
        printf 'trash|%s/Trash/files|Trash\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
        ;;

    disks)
        python3 -c '
import subprocess, json, sys, os, re

seen = set()
results = []

# 1. Mounted block devices (via df)
try:
    df_p = subprocess.run(["df", "-B1", "--output=source,target,size,used", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "efivarfs", "-x", "ramfs"], capture_output=True, text=True)
    for line in df_p.stdout.strip().split("\n")[1:]:
        parts = line.split()
        if len(parts) < 4: continue
        src, target, size, used = parts[0], parts[1], parts[2], parts[3]
        if not src.startswith("/dev/"): continue
        if any(target.startswith(p) for p in ["/boot", "/efi", "/var/lib/docker", "/snap"]): continue
        if src in seen: continue
        seen.add(src)
        
        lbl = subprocess.run(["lsblk", "-d", "-no", "LABEL", src], capture_output=True, text=True).stdout.strip()
        if not lbl:
            lbl = "System" if target == "/" else os.path.basename(target)
            
        info = subprocess.run(["lsblk", "-d", "-no", "RM,HOTPLUG,TRAN,SUBSYSTEMS", src], capture_output=True, text=True).stdout.lower()
        pk = subprocess.run(["lsblk", "-no", "PKNAME", src], capture_output=True, text=True).stdout.strip()
        p_info = subprocess.run(["lsblk", "-d", "-no", "RM,HOTPLUG,TRAN,SUBSYSTEMS", f"/dev/{pk}"], capture_output=True, text=True).stdout.lower() if pk else ""
        
        is_rem = target.startswith("/run/media/") or target.startswith("/media/") or "usb" in info or "usb" in p_info or "mmc" in info or "1" in info.split()[:2]
        kind = "removable" if is_rem else "disk"
        results.append(f"{kind}|{target}|{lbl}|{size}|{used}|{src}")
except Exception:
    pass

# 2. Unmounted removable devices (USB drives, memory cards, external drives)
try:
    res = subprocess.run(["lsblk", "-J", "-b", "-o", "PATH,KNAME,TYPE,RM,HOTPLUG,TRAN,SUBSYSTEMS,SIZE,FSTYPE,LABEL,MOUNTPOINT,PKNAME,MODEL"], capture_output=True, text=True)
    devs = json.loads(res.stdout).get("blockdevices", [])
    
    def flatten(nodes):
        out = []
        for n in nodes:
            out.append(n)
            if "children" in n:
                out.extend(flatten(n["children"]))
        return out

    all_devs = flatten(devs)
    dev_map = {d.get("kname") or d.get("path", "").replace("/dev/", ""): d for d in all_devs}

    for d in all_devs:
        p = d.get("path", "")
        if not p.startswith("/dev/") or p.startswith(("/dev/zram", "/dev/loop", "/dev/sr")): continue
        fstype = d.get("fstype")
        if not fstype or fstype == "swap": continue
        mp = d.get("mountpoint")
        if mp or p in seen: continue
        
        tran = (d.get("tran") or "").lower()
        subs = (d.get("subsystems") or "").lower()
        rm = d.get("rm")
        hp = d.get("hotplug")
        
        pk = d.get("pkname")
        p_dev = dev_map.get(pk, {})
        p_tran = (p_dev.get("tran") or "").lower()
        p_subs = (p_dev.get("subsystems") or "").lower()
        p_rm = p_dev.get("rm")
        
        is_rem = (tran == "usb" or p_tran == "usb" or "usb" in subs or "usb" in p_subs or rm or hp or p_rm)
        if is_rem:
            seen.add(p)
            lbl = d.get("label") or d.get("model") or p_dev.get("model") or os.path.basename(p)
            size = d.get("size") or 0
            results.append(f"removable||{lbl}|{size}|0|{p}")
except Exception:
    pass

# 3. MTP devices & GVFS
try:
    if os.path.isfile("/proc/mounts"):
        with open("/proc/mounts", "r") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) < 3: continue
                fs_src, fs_target, fs_type = parts[0], parts[1], parts[2]
                if fs_type in ["fuse.mtpfs", "mtpfs", "jmtpfs", "simple-mtpfs"]:
                    if os.path.isdir(fs_target):
                        results.append(f"removable|{fs_target}|{os.path.basename(fs_target)}|0|0|mtp")
                elif fs_type == "fuse.gvfsd-fuse":
                    if os.path.isdir(fs_target):
                        for dev_name in os.listdir(fs_target):
                            dev_path = os.path.join(fs_target, dev_name)
                            if os.path.isdir(dev_path):
                                pretty = re.sub(r"^[a-zA-Z0-9+.-]*:host=", "", dev_name)
                                pretty = re.sub(r"%2C.*$", "", pretty).replace("%20", " ").replace("_", " ")
                                if not pretty: pretty = dev_name
                                results.append(f"removable|{dev_path}|{pretty}|0|0|gvfs")
except Exception:
    pass

for r in results:
    print(r)
'
        ;;

    mountdisk)
        dev="$2"
        [ -n "$dev" ] || exit 1
        mp=$(findmnt -n -o TARGET "$dev" 2>/dev/null | head -1)
        if [ -n "$mp" ] && [ -d "$mp" ]; then
            printf '%s\n' "$mp"
            exit 0
        fi
        out=$(udisksctl mount -b "$dev" 2>&1)
        if [ $? -eq 0 ]; then
            mp=$(printf '%s' "$out" | sed -n 's/^Mounted .* at \(.*\)\./\1/p' | sed 's/\.$//')
            if [ -n "$mp" ] && [ -d "$mp" ]; then
                printf '%s\n' "$mp"
                exit 0
            fi
        fi
        gio mount -d "$dev" 2>/dev/null
        mp=$(findmnt -n -o TARGET "$dev" 2>/dev/null | head -1)
        if [ -n "$mp" ] && [ -d "$mp" ]; then
            printf '%s\n' "$mp"
            exit 0
        fi
        ;;

    unmountdisk)
        target="$2"
        [ -n "$target" ] || exit 1
        if [ -b "$target" ]; then
            udisksctl unmount -b "$target" 2>/dev/null || gio mount -u "$target" 2>/dev/null
        else
            udisksctl unmount -p "$target" 2>/dev/null || udisksctl unmount -b "$(findmnt -n -o SOURCE "$target" 2>/dev/null)" 2>/dev/null || gio mount -u "$target" 2>/dev/null
        fi
        ;;

    ejectdisk)
        target="$2"
        [ -n "$target" ] || exit 1
        if [ -b "$target" ]; then
            dev="$target"
        else
            dev=$(findmnt -n -o SOURCE "$target" 2>/dev/null)
        fi
        if [ -n "$dev" ] && [ -b "$dev" ]; then
            udisksctl unmount -b "$dev" 2>/dev/null || gio mount -u "$dev" 2>/dev/null
            parent=$(lsblk -no PKNAME "$dev" 2>/dev/null | head -1)
            if [ -n "$parent" ]; then
                udisksctl power-off -b "/dev/$parent" 2>/dev/null
            else
                udisksctl power-off -b "$dev" 2>/dev/null
            fi
        elif [ -n "$target" ]; then
            gio mount -e "$target" 2>/dev/null || gio mount -u "$target" 2>/dev/null
        fi
        ;;

    emptytrash)
        base="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
        case "$base" in
            */Trash) ;;
            *) exit 1 ;;
        esac
        for d in files info expunged; do
            [ -d "$base/$d" ] || continue
            find "$base/$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        done
        ;;

    trashcount)
        d="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
        [ -d "$d" ] || { echo 0; exit 0; }
        find "$d" -mindepth 1 -maxdepth 1 | wc -l
        ;;

    *)
        echo "usage: files.sh list DIR | disks | apps P | open P [D] | mkdir D N | rename P N | trash P | copy S D | move S D | copypath P | places | emptytrash | trashcount | mountdisk | unmountdisk | ejectdisk" >&2
        exit 1
        ;;
esac
