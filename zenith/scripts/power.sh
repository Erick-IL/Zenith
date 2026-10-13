#!/usr/bin/env bash
# Power profiles via power-profiles-daemon.
#
#   get          -> power-saver | balanced | performance
#   set PROFILE -> switch profile
#
# The standard powerprofilesctl does not work on this system: it needs
# python-gobject, which doesn't exist. The demon is active, so
# we talk to him directly via D-Bus via busctl (included in systemd).
# Switching is allowed to the user of the active session, sudo is not needed.

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"

case "$1" in
    get)
        busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null \
            | sed 's/^s //; s/"//g'
        ;;
    set)
        [ -z "$2" ] && exit 1
        busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$2" 2>/dev/null
        ;;
    *)
        echo "usage: power.sh get | set <power-saver|balanced|performance>" >&2
        exit 1
        ;;
esac
