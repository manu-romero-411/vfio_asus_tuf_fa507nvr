#!/usr/bin/env bash
set -euo pipefail

USUARIO=${SUDO_USER:-$(logname)}
ROOTDIR="$(
  cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null
  pwd -P
)"

install_virt(){
  echo "[INFO] Instalando virtualización Fedora..."
  sudo dnf -y install @virtualization virt-install virt-manager libvirt-daemon-config-network

  echo "[INFO] Activando servicio libvirt..."
  sudo systemctl enable --now libvirtd

  echo "[INFO] Añadiendo usuario a grupos..."
  for g in libvirt kvm input; do
      sudo usermod -aG "$g" "$USUARIO"
  done

  echo "[INFO] Instalando hooks de libvirt y añadiendo ACLs..."
  sudo mkdir -p /etc/libvirt /etc/libvirt/hooks
  sudo cp -r "$ROOTDIR/hooks/"* /etc/libvirt/hooks
  sudo mv /etc/libvirt/qemu.conf  /etc/libvirt/qemu.conf.old
  sudo cp -r "$ROOTDIR/qemu.conf" /etc/libvirt

  echo "[INFO] Definiendo red virtual personalizada..."
  sudo virsh net-define "$ROOTDIR/network-xml/win-vms.xml" || true
  sudo virsh net-autostart win-vms
  sudo virsh net-start win-vms || true

  echo "[INFO] Instalando XML de VMs (no se arrancan aún)..."
  for vm in "$ROOTDIR"/vm-xml/*.xml; do
      sudo virsh define "$vm"
  done

  echo "[INFO] Poniendo al día los puertos de firewall"
  bash "$ROOTDIR"/scripts/vfio-network-forward-setup.sh

  echo "[INFO] Ajustando contexto SELinux para hooks..."
  sudo restorecon -R /etc/libvirt || true

  echo "[OK] Instalación completada."
  echo "Reinicia para dejar todo listo."
}

install_virt
