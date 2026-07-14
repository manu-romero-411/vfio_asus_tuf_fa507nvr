#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="hugepages_disable"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

## Remove Hugepages
log "Releasing hugepage memory back to the host..."
echo 0 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

## Advise if successful
ALLOC_PAGES=$(cat /proc/sys/vm/nr_hugepages)

if [ "$ALLOC_PAGES" -eq 0 ]
then
    log_ok "Memory successfully released!"
fi

log_title "FIN (args: $*)"
sleep 0.5
