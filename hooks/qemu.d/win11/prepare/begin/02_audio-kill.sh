#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_NAME="audio_kill"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

stop_audio() {
    USERNAME=$(get_active_user)
    [ -z "$USERNAME" ] && log_warn "No se encontró usuario activo, omitiendo audio" && return
    USERID=$(id -u "$USERNAME")
    export XDG_RUNTIME_DIR="/run/user/$USERID"

    log "Parando PipeWire para $USERNAME (uid $USERID)"
 
    # Ejecutamos con '|| true' para que systemctl no rompa 'set -e' si los servicios ya estaban parados.
    # Además, redirigimos errores para limpiar el log si no encuentra algún servicio.
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        systemctl --user stop pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

log "Deteniendo audio de usuario"
stop_audio
log_ok "Audio detenido o ya inexistente."
log_title "FIN (args: $*)"
sleep 0.5
set +x
