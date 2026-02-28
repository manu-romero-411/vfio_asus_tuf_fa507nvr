#!/usr/bin/env bash
set -euo pipefail

USUARIO=${SUDO_USER:-$(logname)}
ROOTDIR="$(
  cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null
  pwd -P
)"

remove_virt(){
  echo "[INFO] Eliminando VMs..."
  for vm in $(virsh list --all --name); do
      sudo virsh undefine "$vm" --nvram || true
  done

  echo "[INFO] Eliminando red win-vms..."
  sudo virsh net-destroy win-vms || true
  sudo virsh net-undefine win-vms || true

  echo "[INFO] Eliminando hooks..."
  sudo rm -rf /etc/libvirt/hooks
  sudo rm -rf /etc/libvirt/qemu.d

  echo "[INFO] Eliminando reglas spice..."
  sudo rm -f /etc/udev/rules.d/50-spice.rules
  sudo rm -f /usr/share/polkit-1/actions/org.spice-space.lowlevelusbaccess.policy

  echo "[INFO] Desinstalando virtualización..."
  sudo dnf -y remove @virtualization virt-manager virt-install

  echo "[OK] Eliminación completada."
}

remove_virt
exit 0
