#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="audio"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

get_active_user() {
    loginctl list-sessions --no-legend | awk '{print $3}' | head -n1
}

stop_audio() {
    USERNAME=$(get_active_user)
    [ -z "$USERNAME" ] && return

    USERID=$(id -u "$USERNAME")
    export XDG_RUNTIME_DIR="/run/user/$USERID"

    log "Parando PipeWire para $USERNAME"
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        systemctl --user stop pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

log "Deteniendo audio de usuario"
stop_audio
log_ok "Audio detenido."
