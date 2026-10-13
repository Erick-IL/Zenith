#!/usr/bin/env bash
# Pill password storage.
#
# Everything lies in one file, encrypted with AES-256 on the user’s password -
# the same thing that sudo asks. The key is not saved anywhere: the pill holds
# it is remembered while the storage is open, and forgotten after 15 minutes of inactivity.
# If the file is stolen, nothing can be retrieved from it without the password.
#
#   vault.sh load stdin: password stdout: JSON array
#   vault.sh save stdin: password then JSON
#   vault.sh wipe delete entire vault
#
# Return codes: 0 - success, 1 - error, 2 - incorrect password.

set -u

DIR="$HOME/.local/share/zenith"
STORE="$DIR/vault.enc"
ITER=240000

mkdir -p "$DIR"
chmod 700 "$DIR" 2>/dev/null

# We pass the password to openssl through a file in tmpfs, and not as an argument or through
# environment: arguments visible in the process list.
PWFILE=""
cleanup() { [ -n "$PWFILE" ] && rm -f "$PWFILE"; }
trap cleanup EXIT

read_pw() {
    PWFILE="$(mktemp "${XDG_RUNTIME_DIR:-/dev/shm}/zenith-vault.XXXXXX")"
    chmod 600 "$PWFILE"
    IFS= read -r pw || return 1
    printf '%s' "$pw" > "$PWFILE"
    unset pw
}

case "${1:-}" in
load)
    read_pw || exit 1
    if [ ! -s "$STORE" ]; then
        # there is no storage yet - this is not an error, it’s just empty
        echo "[]"
        exit 0
    fi
    out="$(openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" \
            -in "$STORE" -pass file:"$PWFILE" 2>/dev/null)" || exit 2
    # decrypted, but garbage - we also consider it an incorrect password
    printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1 || exit 2
    printf '%s' "$out"
    ;;

save)
    read_pw || exit 1
    body="$(cat)"
    printf '%s' "$body" | jq -e 'type == "array"' >/dev/null 2>&1 || exit 1
    tmp="$STORE.new"
    printf '%s' "$body" | openssl enc -aes-256-cbc -pbkdf2 -iter "$ITER" \
        -salt -out "$tmp" -pass file:"$PWFILE" || { rm -f "$tmp"; exit 1; }
    chmod 600 "$tmp"
    mv "$tmp" "$STORE"
    ;;

wipe)
    rm -f "$STORE"
    ;;

*)
    echo "usage: vault.sh load|save|wipe" >&2
    exit 1
    ;;
esac
