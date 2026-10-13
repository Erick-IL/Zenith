#!/usr/bin/env bash
# Loading the machine in one line - for a summary in quick settings.
#
#   sysload.sh           ->  cpu|mem|gpu|tcpu|tgpu|disk
#   sysload.sh --fast    ->  |mem||||disk  (без задержки сна и nvidia-smi для виджетов рабочего стола)
#
# Percentages are in whole numbers, temperatures are in degrees Celsius. What can't be measured
# came out, comes empty: the panel then hides this line, rather than drawing a zero.
# Zero lies too convincingly here - “the video card is idle” and “the sensor
# no” are indistinguishable to the eye.
#
# Everything counts as one launch, not five: the panel polls once every two
# seconds, and five processes per poll would cost more than the data itself.

# ------------------------------------------------------------------- processor
# There is no instant loading in /proc/stat - there are counters from the moment of loading.
# Therefore, we take two measurements and divide the increase in occupied time by the total.
# loadavg is not suitable here: this is a queue on the processor per minute, not percentages,
# and on eight cores its value and percentages do not coincide at all.
read -r _ a b c prev_idle rest < /proc/stat
prev_total=$((a + b + c + prev_idle))
for x in $rest; do prev_total=$((prev_total + x)); done

# The pause is short: it entirely goes into delaying the panel’s response, and the resolution
# in a third of a second there is more than enough load for a stripe.
if [ "$1" != "--fast" ]; then
    sleep 0.3
    read -r _ a b c idle rest < /proc/stat
    total=$((a + b + c + idle))
    for x in $rest; do total=$((total + x)); done

    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    [ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 100 / dt ))
fi

# ---------------------------------------------------------------------- memory
# MemAvailable, not MemFree: the kernel gives away everything that is not occupied for cache, and
# MemFree any machine in operation looks packed to capacity.
mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
           END{ if (t > 0) printf "%d", (t - a) * 100 / t }' /proc/meminfo)

# -------------------------------------------------------------- CPU temperature
tcpu=""
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in
        k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu)
            v=$(cat "$h/temp1_input" 2>/dev/null)
            [ -n "$v" ] && tcpu=$((v / 1000))
            break
            ;;
    esac
done

# ------------------------------------------------------------------- video card
# First sysfs: for amdgpu and i915 the download is located directly in the file, and read it
# much cheaper than calling someone else's program.
gpu=""
tgpu=""
for d in /sys/class/drm/card*/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    gpu=$(cat "$d/gpu_busy_percent" 2>/dev/null)
    break
done
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in
        amdgpu|nouveau|radeon|i915|nvidia)
            v=$(cat "$h/temp1_input" 2>/dev/null)
            [ -n "$v" ] && tgpu=$((v / 1000))
            break
            ;;
    esac
done

# The proprietary Nvidia driver in sysfs does not post either boot or
# temperature - only nvidia-smi knows them. We call him only when we can’t live without him
# get by: it wakes up noticeably longer than the file is read.
if [ -z "$gpu" ] || [ -z "$tgpu" ]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
        line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
                          --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$line" ]; then
            [ -z "$gpu" ]  && gpu=$(echo "$line"  | cut -d, -f1 | tr -d ' ')
            [ -z "$tgpu" ] && tgpu=$(echo "$line" | cut -d, -f2 | tr -d ' ')
        fi
    fi
fi

printf '%s|%s|%s|%s|%s|%s\n' "$cpu" "$mem" "$gpu" "$tcpu" "$tgpu" "$disk"
