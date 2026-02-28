#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="nvidia"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

FLAG_FILE="/tmp/vfio-is-nvidia"

log "Restaurando GPU NVIDIA…"

if [ -f "$FLAG_FILE" ] && grep -q "true" "$FLAG_FILE"; then

    log "Cargando módulos NVIDIA…"
    modprobe drm
    modprobe drm_kms_helper
    modprobe i2c_nvidia_gpu
    modprobe nvidia
    modprobe nvidia_modeset
    modprobe nvidia_drm
    modprobe nvidia_uvm

    log "Esperando inicialización…"
    sleep 3

    log "Restaurando servicios…"
    systemctl unmask systemd-backlight@backlight:nvidia_0.service || true
    systemctl start nvidia-persistenced.service || true

    rm -f "$FLAG_FILE"

    log_ok "NVIDIA restaurada correctamente"

else
    log_err "Flag VFIO NVIDIA no presente — no se hace nada"
fi
