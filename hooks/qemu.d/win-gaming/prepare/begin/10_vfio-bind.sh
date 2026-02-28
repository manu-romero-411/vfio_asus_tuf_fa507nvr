#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="vfio_bind"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

# Cargar módulos VFIO
log "Cargando módulos VFIO..."
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1

bind_device() {
    local dev="$1"
    local vendor device current_driver

    # Leer vendor y device
    vendor=$(<"/sys/bus/pci/devices/$dev/vendor")
    device=$(<"/sys/bus/pci/devices/$dev/device")
    vendor=${vendor#0x}
    device=${device#0x}

    # Comprobar driver actual
    if [[ -L "/sys/bus/pci/devices/$dev/driver" ]]; then
        current_driver=$(basename "$(readlink "/sys/bus/pci/devices/$dev/driver")")
    else
        current_driver=""
    fi

    # Si ya está en vfio-pci, no hacer nada
    if [[ "$current_driver" == "vfio-pci" ]]; then
        log_warn "$dev ya está vinculado a vfio-pci, omitiendo bind y registro"
        return
    fi

    # Desvincular si estaba en otro driver
    if [[ -n "$current_driver" ]]; then
        log "Desvinculando $dev de $current_driver"
        echo "$dev" > "/sys/bus/pci/drivers/$current_driver/unbind"
    fi

    # Registrar el dispositivo en vfio-pci si no está registrado
    if ! grep -q "^$vendor $device\$" /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null; then
        log "Registrando $vendor:$device en vfio-pci"
        echo "$vendor $device" > /sys/bus/pci/drivers/vfio-pci/new_id
    fi

    # Bind al driver vfio-pci
    log "Vinculando $dev → vfio-pci"
    echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind || true
}

# === IOMMU 13 ===
# 01:00.0 VGA compatible controller: NVIDIA AD107M [GeForce RTX 4060 Max-Q / Mobile] [10de:28e0]
bind_device "0000:01:00.0"

# 01:00.1 Audio device: NVIDIA AD107 High Definition Audio Controller [10de:22be]
bind_device "0000:01:00.1"

# === IOMMU 17 ===
# 05:00.0 Non-Essential Instrumentation: AMD Dummy Function (absent graphics controller) [1002:145a]
bind_device "0000:05:00.0"

# === IOMMU 22 ===
# 05:00.6 Audio device: AMD Ryzen HD Audio Controller [1022:15e3]
bind_device "0000:05:00.6"
bind_device "0000:05:00.4"
bind_device "0000:06:00.4"
