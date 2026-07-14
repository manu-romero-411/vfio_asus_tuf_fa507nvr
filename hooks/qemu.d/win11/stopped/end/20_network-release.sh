#!/bin/bash
# Eliminar port forwards para VM Sunshine + RDP

VM_IP="192.168.122.100"

# --- RDP ---
RDP_HOST_PORT=43389
RDP_VM_PORT=3389

/usr/sbin/firewall-cmd --permanent \
  --remove-forward-port=port=$RDP_HOST_PORT:proto=tcp:toaddr=$VM_IP:toport=$RDP_VM_PORT

# --- Sunshine TCP ---
for port in 47984 47989 47990 48010; do
    /usr/sbin/firewall-cmd --permanent \
      --remove-forward-port=port=$port:proto=tcp:toaddr=$VM_IP:toport=$port
done

# --- Sunshine UDP ---
for port in 47998 47999 48000 48010; do
    /usr/sbin/firewall-cmd --permanent \
      --remove-forward-port=port=$port:proto=udp:toaddr=$VM_IP:toport=$port
done

# Recargar firewalld
/usr/sbin/firewall-cmd --reload

echo "Forwards eliminados para RDP y Sunshine en $VM_IP"
