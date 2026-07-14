#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="nvidia_kill"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

FLAG_FILE="/tmp/vfio-is-nvidia"
echo "true" > "$FLAG_FILE"

# Desatar vtconsoles
log "Unbind vtconsoles..."
rm -f /tmp/vfio-bound-consoles
for vt in /sys/class/vtconsole/vtcon*; do
    grep -q "frame buffer" "$vt/name" || continue
    id=${vt##*vtcon}
    echo 0 > "$vt/bind"
    echo "$id" >> /tmp/vfio-bound-consoles
done

# Matar procesos GPU residuales (excluyendo red y SSH)
PROTECTED="wpa_supplicant|NetworkManager|systemd-networkd|dhclient|dhcpcd|sshd"
log "Matando procesos GPU residuales..."
PROCS=$(lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true)
if [ -n "$PROCS" ]; then
    for pid in $PROCS; do
        comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
        stat=$(awk '/^State:/{print $2}' /proc/$pid/status 2>/dev/null || echo "?")
        if echo "$comm" | grep -qE "^($PROTECTED)$"; then
            log_warn "SKIP: PID $pid ($comm) — proceso protegido"
            continue
        fi
        if [ "$stat" = "D" ]; then
            log_err "PID $pid ($comm) en estado D — kill -9 no tendrá efecto"
            exit 1
	else
            log_warn "KILL: PID $pid ($comm) estado=$stat"
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 0.5
fi

# Verificar que la GPU está realmente libre
PROCS=$(lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true)
if [ -n "$PROCS" ]; then
    log_warn "GPU aún ocupada — rmmod probablemente fallará:"
    for pid in $PROCS; do
        ps -p "$pid" -o pid,stat,comm --no-headers 2>/dev/null || true
    done
fi

# Servicios nvidia
log "Deteniendo servicios nvidia..."
systemctl stop nvidia-persistenced.service 2>/dev/null || true
systemctl stop systemd-backlight@backlight:nvidia_0.service 2>/dev/null || true
systemctl mask systemd-backlight@backlight:nvidia_0.service 2>/dev/null || true

# EFI framebuffer
log "Unbind EFI framebuffer..."
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true

# Forzar GPU a modo D0
#cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
#cat /sys/bus/pci/devices/0000:01:00.0/power/control
#cat /proc/driver/nvidia/gpus/0000:01:00.0/power 2>/dev/null

log "Forzando GPU a D0 (deshabilitando runtime PM)..."
echo on > /sys/bus/pci/devices/0000:01:00.0/power/control
echo on > /sys/bus/pci/devices/0000:01:00.1/power/control
sleep 0.5

# Matar procesos del host que tengan secuestrada la dGPU antes del unbind
log "Destruyendo últimos procesos que usen la gpu..."
if ls /dev/nvidia* >/dev/null 2>&1; then
    fuser -k -9 /dev/nvidia* 2>/dev/null || true
fi
sleep 0.5

# Descargar módulos en orden
log "Descargando módulos nvidia..."
for mod in nvidia_drm nvidia_modeset nvidia_uvm nvidia i2c_nvidia_gpu; do
    if lsmod | grep -q "^$mod "; then
        if modprobe -r "$mod" 2>/dev/null; then
            log "  $mod descargado"
        else
            log_err "  $mod NO se pudo descargar — GPU passthrough fallará"
            exit 1
        fi
    else
        log "  $mod no estaba cargado, omitiendo"
    fi
done

log_ok "Fase nvidia completada."
log_title "FIN (args: $*)"
