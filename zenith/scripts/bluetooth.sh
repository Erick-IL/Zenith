#!/usr/bin/env bash
# Bluetooth helper script for Zenith shell
#
#   bluetooth.sh toggle
#   bluetooth.sh on
#   bluetooth.sh off
#   bluetooth.sh scan
#   bluetooth.sh connect MAC
#   bluetooth.sh disconnect [MAC]
#   bluetooth.sh pair MAC
#   bluetooth.sh remove MAC
#   bluetooth.sh trust MAC

case "$1" in
toggle)
    if rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes'; then
        rfkill unblock bluetooth
        sleep 0.2
        bluetoothctl power on >/dev/null 2>&1
    elif bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        bluetoothctl power off >/dev/null 2>&1
    else
        rfkill unblock bluetooth
        sleep 0.2
        bluetoothctl power on >/dev/null 2>&1
    fi
    ;;
on)
    rfkill unblock bluetooth
    sleep 0.2
    bluetoothctl power on >/dev/null 2>&1
    ;;
off)
    bluetoothctl power off >/dev/null 2>&1
    ;;
scan)
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &
    ;;
connect)
    [ -z "$2" ] && exit 1
    bluetoothctl trust "$2" >/dev/null 2>&1
    bluetoothctl connect "$2" >/dev/null 2>&1
    ;;
disconnect)
    if [ -n "$2" ]; then
        bluetoothctl disconnect "$2" >/dev/null 2>&1
    else
        bluetoothctl disconnect >/dev/null 2>&1
    fi
    ;;
pair)
    [ -z "$2" ] && exit 1
    bluetoothctl pair "$2" >/dev/null 2>&1
    bluetoothctl trust "$2" >/dev/null 2>&1
    bluetoothctl connect "$2" >/dev/null 2>&1
    ;;
remove|forget)
    [ -z "$2" ] && exit 1
    bluetoothctl disconnect "$2" >/dev/null 2>&1
    bluetoothctl untrust "$2" >/dev/null 2>&1
    bluetoothctl remove "$2" >/dev/null 2>&1
    ;;
trust)
    [ -z "$2" ] && exit 1
    bluetoothctl trust "$2" >/dev/null 2>&1
    ;;
*)
    echo "usage: bluetooth.sh toggle|on|off|scan|connect MAC|disconnect [MAC]|pair MAC|remove MAC|trust MAC" >&2
    exit 1
    ;;
esac
