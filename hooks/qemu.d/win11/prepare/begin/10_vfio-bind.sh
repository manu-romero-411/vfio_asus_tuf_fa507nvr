#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="vfio_bind"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

load_vfio_modules

# === IOMMU 13 ===
# 01:00.0 VGA: NVIDIA AD107M [GeForce RTX 4060 Max-Q / Mobile] [10de:28e0]
bind_device "0000:01:00.0"
# 01:00.1 Audio: NVIDIA AD107 HD Audio [10de:22be]
bind_device "0000:01:00.1"

# === IOMMU 17 ===
# 05:00.0 Non-Essential Instrumentation: AMD Dummy Function [1002:145a]
bind_device "0000:05:00.0"

# === IOMMU 22 ===
# 05:00.6 Audio: AMD Ryzen HD Audio Controller [1022:15e3]
bind_device "0000:05:00.6"

log_ok "Bind VFIO completado."
log_title "FIN (args: $*)"
sleep 0.5
