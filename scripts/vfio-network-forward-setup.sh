#!/usr/bin/env bash
set -e

# --- CONFIGURACIÓN ---
VM_IP="192.168.121.100"
VM_MAC="52:54:00:31:51:7c"
NETWORK_NAME="win_vms"
RDP_EXTERNAL_PORT=13389

echo "Iniciando configuración de red para VMs..."

# 1. Limpieza de reglas antiguas para evitar duplicados
#echo "[1/4] Limpiando reglas previas de firewalld..."
#sudo firewall-cmd --permanent --remove-port=1025-65535/tcp 2>/dev/null || true
#sudo firewall-cmd --permanent --remove-port=1025-65535/udp 2>/dev/null || true
#for f in $(sudo firewall-cmd --permanent --list-forward-ports 2>/dev/null); do
#    sudo firewall-cmd --permanent --remove-forward-port="$f" 2>/dev/null || true
#done

# 2. Capacidades de forwarding
echo "[2/4] Activando masquerade y forwarding..."
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-forward
# Masquerade de retorno: necesario para que las respuestas de la VM
# lleguen correctamente al cliente externo (evita error 0x204 en RDP)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.121.0/24" masquerade'

# 3. Port forwarding
echo "[3/4] Mapeando puertos para la VM $VM_IP..."

add_fwd() {
    sudo firewall-cmd --permanent --add-forward-port=port=$1:proto=$2:toport=$3:toaddr=${VM_IP}
}

# RDP
add_fwd ${RDP_EXTERNAL_PORT} tcp 3389

# Sunshine TCP
for p in 57984 57989 57990 58010; do
    add_fwd $p tcp $p
done

# Sunshine UDP
for p in 57998 57999 58000 58002; do
    add_fwd $p udp $p
done

# 4. Reserva DHCP en libvirt
echo "[4/4] Verificando reserva IP en libvirt..."
if ! sudo virsh net-dumpxml $NETWORK_NAME | grep -q "$VM_MAC"; then
    sudo virsh net-update $NETWORK_NAME add ip-dhcp-host \
      "<host mac='$VM_MAC' ip='$VM_IP'/>" --live --config \
      || echo "Nota: No se pudo actualizar DHCP (quizás la VM está apagada)"
fi

sudo firewall-cmd --reload

echo -e "\n✅ ¡Hecho!"
echo "💻 RDP:      192.168.1.12:${RDP_EXTERNAL_PORT} → VM:3389"
echo "☀️  Sunshine: 192.168.1.12:#### -> VM:#### mapeo 1:1 - hay que configurar los puertos de Sunshine bien"
