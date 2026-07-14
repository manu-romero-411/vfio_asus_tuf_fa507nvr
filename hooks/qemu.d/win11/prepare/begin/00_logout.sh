#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="gui_logout"
log_title "INICIO (args: $*)"

asusctl aura effect rainbow-cycle --speed high

# Detener sunshine (puede tener distintos nombres de servicio según versión)
for svc in sunshine.service app-dev.lizardbyte.app.Sunshine.service; do
    systemctl --user -M 1000@ stop "$svc" 2>/dev/null && log "sunshine detenido ($svc)" || true
done

if ! systemctl is-active --quiet display-manager.service; then
    log_warn "No hay display manager activo."
    log_title "FIN (args: $*)"
    return
fi

DISPMGR=$(basename "$(readlink /etc/systemd/system/display-manager.service)")
echo "$DISPMGR" > /tmp/vfio-store-display-manager

log "Deteniendo $DISPMGR..."
systemctl stop "$DISPMGR" || true
while systemctl is-active --quiet "$DISPMGR"; do
    log_warn "Esperando a que $DISPMGR se detenga..."
    sleep 1
done

PROTECTED_RE='^(wpa_supplicant|NetworkManager|systemd-networkd|dhclient|dhcpcd|sshd)$'

gpu_pids() {
    lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true
}

# Mata los PIDs que aún retienen la GPU, saltando los protegidos.
# Si sig=9 y un proceso está en estado D, aborta con instrucciones de reinicio.
kill_gpu_procs() {
    local sig="$1" pid comm stat
    for pid in $(gpu_pids); do
        comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
        echo "$comm" | grep -qE "$PROTECTED_RE" && {
            log_warn "SKIP: PID $pid ($comm) — proceso protegido"
            continue
        }
        if [ "$sig" = "9" ]; then
            stat=$(awk '/^State:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo "?")
            if [ "$stat" = "D" ]; then
                log_err "PID $pid ($comm) en estado D — kill -9 no tendrá efecto"
                log_err "Reinicia el PC (con botonazo si hace falta). Guarda lo que tengas pendiente."
                exit 1
            fi
        fi
        kill -"$sig" "$pid" 2>/dev/null || true
    done
}

# Dar margen a que los procesos suelten la GPU por sí solos
for i in {1..3}; do
    [ -z "$(gpu_pids)" ] && break
    log_warn "GPU aún ocupada por PIDs: $(gpu_pids | tr '\n' ' ') (intento $i/3)"
    sleep 0.5
done

# Escalada: SIGTERM -> espera -> SIGKILL -> verificación final
if [ -n "$(gpu_pids)" ]; then
    kill_gpu_procs 15
    sleep 2
fi

if [ -n "$(gpu_pids)" ]; then
    kill_gpu_procs 9
    sleep 1
fi

if [ -n "$(gpu_pids)" ]; then
    log_err "GPU sigue ocupada tras las señales, matando lo que quede sin miramientos"
    kill_gpu_procs 9
    sleep 0.25
    remaining=$(gpu_pids)
    if [ -n "$remaining" ]; then
        log_err "PIDs $remaining en estado D — kill -9 no tiene efecto"
        log_err "Reinicia el PC (con botonazo si hace falta). Guarda lo que tengas pendiente."
        exit 1
    fi
fi

log_ok "Sesión gráfica cerrada. GPU libre."
log_title "FIN (args: $*)"
