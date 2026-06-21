#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="cpu_pinning"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

## Isolate CPU cores as per set variable
systemctl set-property --runtime -- user.slice AllowedCPUs=$VM_ISOLATED_CPUS
systemctl set-property --runtime -- system.slice AllowedCPUs=$VM_ISOLATED_CPUS
systemctl set-property --runtime -- init.scope AllowedCPUs=$VM_ISOLATED_CPUS

log_title "FIN (args: $*)"
sleep 0.5
