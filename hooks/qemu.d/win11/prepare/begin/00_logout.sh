#!/bin/bash

set -euo pipefail

SCRIPT_NAME="logout"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

log "Cerrando sesión gráfica..."

# Detectar display manager activo
if systemctl is-active --quiet display-manager.service; then
    DISPMGR=$(basename "$(readlink /etc/systemd/system/display-manager.service)")
    systemctl --user -M 1000@ stop sunshine.service || true
    log "Display manager detectado: $DISPMGR"

    # Guardar el display manager para reiniciar luego
    if ! grep -qsF "$DISPMGR" "/tmp/vfio-store-display-manager"; then
        echo "$DISPMGR" >/tmp/vfio-store-display-manager
    fi

    # Detener el display manager
    log "Deteniendo $DISPMGR..."
    systemctl stop "$DISPMGR"

    # Esperar a que se detenga
    while systemctl is-active --quiet "$DISPMGR"; do
        log_warn "Esperando a que $DISPMGR se detenga..."
        sleep 1
    done

    # Opcional: cambiar a modo multi-user (sin GUI)
    systemctl isolate multi-user.target
    log_ok "Sesión gráfica cerrada correctamente."
else
    log_warn "No se detecta ningún display manager activo."
fi

