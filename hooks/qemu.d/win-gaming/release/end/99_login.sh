#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="login"

log(){ if [ "$1" == "-v" ]; then echo "[*] (unbind - $SCRIPT_NAME) $*"; fi; }
log_warn(){ if [ "$1" == "-v" ]; then echo "[!] (unbind - $SCRIPT_NAME) $*"; fi; }
log_ok(){ if [ "$1" == "-v" ]; then echo "[✓] (unbind - $SCRIPT_NAME) $*"; fi; }
log_err(){ if [ "$1" == "-v" ]; then echo "[x] (unbind - $SCRIPT_NAME) $*"; fi; }

log "Iniciando sesión gráfica..."

# Leer el display manager guardado
if [[ -f /tmp/vfio-store-display-manager ]]; then
    DISPMGR=$(cat /tmp/vfio-store-display-manager)

    # Cambiar a modo gráfico
    systemctl isolate graphical.target

    # Iniciar el display manager
    log "Iniciando $DISPMGR..."
    systemctl start "$DISPMGR"

    # Esperar a que esté activo
#    while ! systemctl is-active --quiet "$DISPMGR"; do
#        log_warn "Esperando a que $DISPMGR se inicie..."
#        sleep 1
#    done
    rm "/tmp/vfio-store-display-manager"
    log_ok "Sesión gráfica iniciada correctamente."
else
    log_err "No se encontró display manager guardado en /tmp/vfio-store-display-manager."
fi
