#!/bin/bash
set -euo pipefail

SCRIPT_NAME="gui_login"
exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"
set -x

log()     { echo "[*] ($SCRIPT_NAME) $*"; }
log_warn(){ echo "[!] ($SCRIPT_NAME) $*"; }
log_ok()  { echo "[✓] ($SCRIPT_NAME) $*"; }
log_err() { echo "[x] ($SCRIPT_NAME) $*"; }

if [[ ! -f /tmp/vfio-store-display-manager ]]; then
    log_err "No se encontró display manager guardado."
    echo "=== $(date +%T) FIN $SCRIPT_NAME ==="
    exit 1
fi

DISPMGR=$(cat /tmp/vfio-store-display-manager)
log "Iniciando $DISPMGR (sin isolate)..."

# Arrancar el DM directamente — systemd resuelve las dependencias
# hacia graphical.target sin necesidad de isolate
systemctl start "$DISPMGR"

while ! systemctl is-active --quiet "$DISPMGR"; do
    echo -n "."
    sleep 1
done
echo -e "\n"

rm -f /tmp/vfio-store-display-manager
log_ok "Sesión gráfica iniciada correctamente."
echo "=== $(date +%T) FIN $SCRIPT_NAME ==="
