#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="vfio_unbind"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

unbind_device() {
    local dev="$1"
    local vendor device

    vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
    device=$(cat /sys/bus/pci/devices/$dev/device)
    vendor=${vendor#0x}
    device=${device#0x}

    log "Reasignando driver original a $dev"
    echo "$dev" > /sys/bus/pci/drivers_probe
}

# Descargar módulos VFIO si nadie más los usa
log "Descargando módulos VFIO..."
modprobe -r vfio_pci || true
modprobe -r vfio_iommu_type1 || true
modprobe -r vfio || true

# === IOMMU 13 ===
unbind_device "0000:01:00.0"
unbind_device "0000:01:00.1"

# === IOMMU 17 ===
unbind_device "0000:05:00.0"

# === IOMMU 22 ===
unbind_device "0000:05:00.6"
