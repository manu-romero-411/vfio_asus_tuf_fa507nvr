#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="nvidia"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

FLAG_FILE="/tmp/vfio-is-nvidia"

echo "true" | tee "$FLAG_FILE"

log "unbind vtconsoles"
rm -f /tmp/vfio-bound-consoles
for vt in /sys/class/vtconsole/vtcon*; do
    grep -q "frame buffer" "$vt/name" || continue
    id=${vt##*vtcon}
    echo 0 > "$vt/bind"
    echo "$id" >> /tmp/vfio-bound-consoles
done

log "kill gpu processes"
kill -9 $(lsof -t /dev/dri/* 2>/dev/null | sort -u) 2>/dev/null || true
kill -9 $(lsof -t /dev/nvidia* 2>/dev/null | sort -u) 2>/dev/null || true

log "stop nvidia services"
systemctl stop nvidia-persistenced.service 2>/dev/null || true
systemctl stop systemd-backlight@backlight:nvidia_0.service 2>/dev/null || true
systemctl mask systemd-backlight@backlight:nvidia_0.service 2>/dev/null || true

log "unbind efi fb"
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true

log "unload nvidia modules"
modprobe -r nvidia_drm 2>/dev/null || true
modprobe -r nvidia_modeset 2>/dev/null || true
modprobe -r nvidia_uvm 2>/dev/null || true
modprobe -r nvidia 2>/dev/null || true
modprobe -r i2c_nvidia_gpu 2>/dev/null || true

log_ok "GPU nvidia desacoplada."
