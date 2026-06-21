#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="cpu_unpinning"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

## Return CPU cores as per set variable
systemctl set-property --runtime -- user.slice AllowedCPUs=$SYS_TOTAL_CPUS
systemctl set-property --runtime -- system.slice AllowedCPUs=$SYS_TOTAL_CPUS
systemctl set-property --runtime -- init.scope AllowedCPUs=$SYS_TOTAL_CPUS

log_title "FIN (args: $*)"
sleep 0.5
