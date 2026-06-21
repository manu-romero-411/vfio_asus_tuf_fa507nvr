#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="vfio_usb_unbind"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

unload_vfio_modules

# === USB controllers ===
# 05:00.4 USB: Rembrandt USB4 XHCI #4 [1022:161e]
unbind_device "0000:05:00.4"
# 06:00.4 USB: Rembrandt USB4 XHCI #6 [1022:15d7]
unbind_device "0000:06:00.4"

log_title "FIN (args: $*)"
