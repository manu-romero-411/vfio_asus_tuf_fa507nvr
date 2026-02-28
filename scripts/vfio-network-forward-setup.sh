#!/usr/bin/env bash
set -e

# --- CONFIGURACIÓN ---
VM_IP="192.168.121.100"
VM_MAC="52:54:00:31:51:7c"
NETWORK_NAME="win_vms"
RDP_EXTERNAL_PORT=33389  # Usamos este para evitar conflictos con el host

echo "🚀 Iniciando configuración unificada de red VFIO..."

# 1. Limpieza de reglas antiguas para evitar duplicados "basura"
echo "[1/5] Limpiando reglas previas de firewalld..."
# Eliminamos el rango masivo si existiera para evitar colisiones
sudo firewall-cmd --permanent --remove-port=1025-65535/tcp 2>/dev/null || true
sudo firewall-cmd --permanent --remove-port=1025-65535/udp 2>/dev/null || true

# Limpiamos forwards antiguos
for f in $(sudo firewall-cmd --permanent --list-forward-ports); do
    sudo firewall-cmd --permanent --remove-forward-port=$f
done

# 2. Configuración de Capacidades del Firewall
echo "[2/5] Activando Masquerade y Forwarding en el host..."
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-forward

# REGLA ORO: Masquerade de retorno para evitar el Error 4 de Sunshine
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.121.0/24" masquerade'

# 3. Mapeo de Puertos (Forwarding)
echo "[3/5] Mapeando puertos para la VM $VM_IP..."

# Función auxiliar
add_fwd() {
    sudo firewall-cmd --permanent --add-forward-port=port=$1:proto=$2:toport=$3:toaddr=$VM_IP
}

# RDP (Externo 33389 -> Interno 3389)
add_fwd $RDP_EXTERNAL_PORT tcp 3389

# Sunshine TCP (1:1)
for p in 57984 57989 57990 58010; do
    add_fwd $p tcp $p
done

# Sunshine UDP (1:1)
for p in 57998 57999 58000 58002; do
    add_fwd $p udp $p
done

# 4. Asegurar Reserva DHCP en Libvirt
echo "[4/5] Verificando reserva IP en Libvirt..."
if ! virsh net-dumpxml $NETWORK_NAME | grep -q "$VM_MAC"; then
    virsh net-update $NETWORK_NAME add ip-dhcp-host \
    "<host mac='$VM_MAC' ip='$VM_IP'/>" --live --config || echo "Nota: No se pudo actualizar DHCP (quizás la VM está apagada)"
fi

# 5. Aplicar cambios
echo "[5/5] Aplicando cambios en el Firewall..."
sudo firewall-cmd --reload

echo -e "\n✅ ¡Hecho! Resumen de conexión:"
echo "--------------------------------------------------"
echo "💻 RDP:      Tu_IP_Fedora:$RDP_EXTERNAL_PORT"
echo "☀️ Sunshine: Tu_IP_Fedora (Puertos estándar)"
echo "--------------------------------------------------"
