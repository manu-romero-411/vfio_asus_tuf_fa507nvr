#!/usr/bin/env bash
# SCRIPT DE REVERSIÓN TOTAL

VM_IP="192.168.121.100"
NETWORK_NAME="win_vms"

echo "🧹 Iniciando limpieza total de la configuración de red..."

# 1. Eliminar todos los forward-ports activos
echo "[1/4] Eliminando reglas de reenvío de puertos..."
for f in $(sudo firewall-cmd --permanent --list-forward-ports); do
    sudo firewall-cmd --permanent --remove-forward-port=$f
done

# 2. Eliminar la regla de Masquerade para la subred específica
echo "[2/4] Eliminando Rich Rules (Masquerade de subred)..."
sudo firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="192.168.121.0/24" masquerade' 2>/dev/null || true

# 3. Desactivar Masquerade global y Forwarding de zona
echo "[3/4] Desactivando Masquerade global y Forwarding..."
sudo firewall-cmd --permanent --remove-masquerade 2>/dev/null || true
sudo firewall-cmd --permanent --zone=FedoraWorkstation --remove-forward 2>/dev/null || true

# 4. Limpieza opcional de Libvirt (comentada por seguridad)
# Si quieres borrar la red virtual por completo, descomenta las siguientes líneas:
# echo "[!] Destruyendo red virtual libvirt..."
# sudo virsh net-destroy $NETWORK_NAME 2>/dev/null || true
# sudo virsh net-undefine $NETWORK_NAME 2>/dev/null || true

# 5. Aplicar cambios
echo "[4/4] Recargando firewall para aplicar limpieza..."
sudo firewall-cmd --reload

echo -e "\n✨ Sistema restaurado. El firewall ha vuelto a su estado original."
