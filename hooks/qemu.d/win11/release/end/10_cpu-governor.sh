#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="cpu_governor"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

## Reset CPU governor to mode indicated by variable
CPU_COUNT=0
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
    echo $VM_OFF_GOVERNOR > $file;
    echo "CPU $CPU_COUNT governor: $VM_OFF_GOVERNOR";
    let CPU_COUNT+=1
done

## Set system power profile back to powersave
powerprofilesctl set $VM_OFF_PWRPROFILE

log_title "FIN (args: $*)"
sleep 0.5
