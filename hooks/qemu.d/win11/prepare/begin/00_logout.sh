#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="gui_logout"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

# Detener sunshine antes de tocar la sesión
systemctl --user -M 1000@ stop sunshine.service 2>/dev/null && \
    log "sunshine detenido" || true

# ahora el servicio de sunshine se llama así, joder qué lío siempre...
systemctl --user -M 1000@ stop app-dev.lizardbyte.app.Sunshine.service 2>/dev/null && \
    log "sunshine detenido" || true

# vemos si ya está matado el display manager (ej. haber arrancado en modo texto).
# En caso de ser así dejamos atrás este script
if ! systemctl is-active --quiet display-manager.service; then
    log_warn "No hay display manager activo."
    echo "=== $(date +%T) FIN $SCRIPT_NAME ==="
    exit 0
fi

DISPMGR=$(basename "$(readlink /etc/systemd/system/display-manager.service)")
#log "Display manager: $DISPMGR"
echo "$DISPMGR" > /tmp/vfio-store-display-manager

# 1. Parar compositor y shell de Plasma limpiamente
#log "Parando compositor y shell de Plasma..."
#systemctl --user -M 1000@ stop plasma-plasmashell.service kwin_wayland.service 2>/dev/null || true

# 2. Terminar solo sesiones gráficas (wayland/x11), no SSH
#log "Terminando sesiones gráficas del usuario 1000..."
#while read -r session; do
#    stype=$(loginctl show-session "$session" -p Type --value 2>/dev/null || echo "")
#    suser=$(loginctl show-session "$session" -p User --value 2>/dev/null || echo "")
#    if [ "$suser" = "1000" ] && [ "$stype" = "wayland" -o "$stype" = "x11" ]; then
#        log "Terminando sesión $session (tipo: $stype)"
#        loginctl terminate-session "$session" 2>/dev/null || true
#    fi
#done < <(loginctl list-sessions --no-legend | grep -v "pty" | grep -v "ssh" | awk '{print $1}')

# 6. Detener el display manager
log "Deteniendo $DISPMGR..."
systemctl stop "$DISPMGR" || true
while systemctl is-active --quiet "$DISPMGR"; do
    log_warn "Esperando a que $DISPMGR se detenga..."
    sleep 1
done


# 3. Esperar a que los procesos suelten la GPU
WAIT=0
while [ $WAIT -lt 3 ]; do
    PROCS=$(lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true)
    [ -z "$PROCS" ] && break
    log_warn "GPU aún ocupada por PIDs: $(echo $PROCS | tr '\n' ' ') (intento $((WAIT+1))/10)"
    sleep 0.5
    WAIT=$((WAIT + 1))
done

# 4. Matar restos con SIGTERM primero
PROTECTED="wpa_supplicant|NetworkManager|systemd-networkd|dhclient|dhcpcd|sshd"
PROCS=$(lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true)
if [ -n "$PROCS" ]; then
    for pid in $PROCS; do
        comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
        if echo "$comm" | grep -qE "^($PROTECTED)$"; then
            log_warn "SKIP: PID $pid ($comm) — proceso protegido"
            continue
        fi
        #log_warn "SIGTERM: PID $pid ($comm)"
        kill -15 "$pid" 2>/dev/null || true
    done
    sleep 2
fi

# 5. SIGKILL a lo que quede
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
		log_err "Recomendamos que reinicies el PC (con botonazo si es necesario). Guarda todo lo que tengas por guardar, y asegúrate de que no hay operaciones de I/O activas."
		exit 1
	else
            #log_warn "SIGKILL: PID $pid ($comm)"
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 1
fi

# 7. Verificación final
PROCS=$(lsof -t /dev/dri/* /dev/nvidia* 2>/dev/null | sort -u || true)
if [ -n "$PROCS" ]; then
    log_err "GPU todavía ocupada tras logout:"
    for pid in $PROCS; do
        ps -p "$pid" -o pid,stat,comm,args --no-headers 2>/dev/null || true
    done
    log_err "Los módulos nvidia pueden no descargarse limpiamente."
else
    log_ok "Sesión gráfica cerrada. GPU libre."
fi

log_title "FIN (args: $*)"
