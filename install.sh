#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN DE ENTORNO Y USUARIO
# ──────────────────────────────────────────────────────────────────────────────
USUARIO=${SUDO_USER:-$(logname)}
ROOTDIR="$(
  cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null
  pwd -P
)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Validar que el script maestro se ejecute con privilegios elevados
if [[ $EUID -ne 0 ]]; then
    error "Este script de setup maestro debe ejecutarse con sudo."
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# LOGICA DE OPTIMIZACIÓN DEL SISTEMA (TELEMETRÍA, COREDUMPS Y PERMISOS)
# ──────────────────────────────────────────────────────────────────────────────
optimize_system_vfio() {
  info "Configurando persistencia (Linger) para lanzar VMs sin sudo..."
  loginctl enable-linger "$USUARIO"

  info "Capando permanentemente ABRT (Telemetría nativa de Fedora)..."
  systemctl stop abrt-journal-core abrt-xorg abrt-oops abrtd 2>/dev/null || true
  systemctl disable abrt-journal-core abrt-xorg abrt-oops abrtd 2>/dev/null || true
  systemctl mask abrt-journal-core.service abrt-oops.service abrtd.service abrt-pstoreoops.service abrt-vmcore.service 2>/dev/null || true

  info "Capando permanentemente Dr. Konqi (Procesador de cuelgues de KDE)..."
  # Sellar el socket a nivel de sistema para evitar que despierte hilos de GDB como root
  systemctl stop drkonqi-coredump-processor.socket 2>/dev/null || true
  systemctl mask drkonqi-coredump-processor.socket 2>/dev/null || true

  # Sellar el socket a nivel de usuario para el entorno local del usuario real
  sudo -u "$USUARIO" systemctl --user stop drkonqi-coredump-processor.socket 2>/dev/null || true
  sudo -u "$USUARIO" systemctl --user mask drkonqi-coredump-processor.socket 2>/dev/null || true

  info "Configurando Systemd-Coredump para descartar volcados de memoria pesados..."
  sudo mkdir -p /etc/systemd/coredump.conf.d
  sudo tee /etc/systemd/coredump.conf.d/99-vfio-disable.conf > /dev/null << 'EOF'
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
  systemctl daemon-reload

  info "Liquidando procesos residuales de análisis de caídas..."
  killall -9 drkonqi drkonqi-coredump-processor abrt-action-coredump abrt-handle-event gdb abrt-server 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────────────────
# LOGICA DE CONFIGURACIÓN ESTRICTA DE SELINUX
# ──────────────────────────────────────────────────────────────────────────────
setup_selinux_passthrough() {
  info "Iniciando configuración avanzada de SELinux para Passthrough..."

  if ! command -v semanage &>/dev/null; then
      info "Instalando herramientas requeridas para semanage..."
      dnf install -y policycoreutils-python-utils policycoreutils
  fi

  info "Relajando el confinamiento estricto de Sandboxing en Virt-QEMU..."
  setsebool -P virt_sandbox_use_all_caps 1 || true
  setsebool -P virt_transition_userdomain 0 || true
  setsebool -P virt_unconfined 1 || true

  info "Configurando virtqemud_t como dominio permissive local..."
  if semanage permissive -l 2>/dev/null | grep -q 'virtqemud_t'; then
      warn "virtqemud_t ya estaba en permissive."
  else
      semanage permissive -a virtqemud_t
      info "virtqemud_t añadido a permissive con éxito."
  fi

  # Rutas de hooks nativas de tu distribución en Fedora
  HOOK_PATH="/etc/libvirt/hooks"

  info "Configurando contexto SELinux para hooks de libvirt en ${HOOK_PATH}..."
  if semanage fcontext -l 2>/dev/null | grep -q "${HOOK_PATH}"; then
      semanage fcontext -m -t virt_hook_t "${HOOK_PATH}(/.*)?"
  else
      semanage fcontext -a -t virt_hook_t "${HOOK_PATH}(/.*)?"
  fi

  if [[ -d "${HOOK_PATH}" ]]; then
      restorecon -Rv "${HOOK_PATH}"
  else
      warn "${HOOK_PATH} no existe físicamente todavía. Se aplicará restorecon más adelante."
  fi
}

desktop_entry(){
  cat << 'EOF' > /home/$USUARIO/.local/share/applications/win11-vfio.desktop
[Desktop Entry]
Name=Windows 11 (VFIO)
Comment=Arrancar VM con Single GPU Passthrough
Exec=bash -c "$HOME/.local/bin/vfio-start-vm win11"
Icon=distributor-logo-windows
Terminal=false
Type=Application
Categories=System;Emulator;
Keywords=virtual;kvm;qemu;win11;vfio;
EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# LOGICA PRINCIPAL DE INSTALACIÓN VIRTUALIZACIÓN
# ──────────────────────────────────────────────────────────────────────────────
install_virt(){
  info "Instalando virtualización Fedora..."
  dnf -y install @virtualization virt-install virt-manager libvirt-daemon-config-network

  info "Activando daemons libvirt (arquitectura modular)..."
  systemctl enable --now virtqemud virtnetworkd virtstoraged
  systemctl disable --now libvirtd 2>/dev/null || true

  info "Añadiendo usuario '$USUARIO' a grupos de sistema..."
  for g in libvirt kvm input libinput audio video; do
      usermod -aG "$g" "$USUARIO"
  done

  info "Configurando acceso sin sudo a qemu:///system (Polkit)..."
  sudo tee /etc/polkit-1/rules.d/50-libvirt.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
EOF

  info "Exportando URI por defecto en .bashrc.d/06_libvirt..."
  BASHRC_D_DIR="/home/$USUARIO/.bashrc.d"
  sudo -u "$USUARIO" mkdir -p "$BASHRC_D_DIR"
  sudo -u "$USUARIO" tee "$BASHRC_D_DIR/06_libvirt" > /dev/null << 'EOF'
#!/bin/bash

export LIBVIRT_DEFAULT_URI="qemu:///system"
EOF
  sudo -u "$USUARIO" chmod +x "$BASHRC_D_DIR/06_libvirt"

  info "Instalando hooks de libvirt y forzando exclusión de drivers de seguridad..."
  mkdir -p /etc/libvirt/hooks
  if [ -d "$ROOTDIR/hooks" ]; then
      cp -r "$ROOTDIR/hooks/"* /etc/libvirt/hooks
  fi

  # Si existe el archivo qemu.conf local, lo inyectamos asegurando la anulación del driver de seguridad
  if [ -f "$ROOTDIR/qemu.conf" ]; then
      mv /etc/libvirt/qemu.conf /etc/libvirt/qemu.conf.old 2>/dev/null || true
      cp -r "$ROOTDIR/qemu.conf" /etc/libvirt
  fi
  # Garantía absoluta en el fichero qemu.conf para evadir restricciones de aislamiento
  sed -i 's/^#\?security_driver =.*/security_driver = "none"/' /etc/libvirt/qemu.conf

  info "Definiendo red virtual personalizada..."
  if [ -f "$ROOTDIR/network-xml/win-vms.xml" ]; then
      virsh net-define "$ROOTDIR/network-xml/win-vms.xml" || true
      virsh net-autostart win_vms || true
      virsh net-start win_vms || true
  fi

  info "Asignando bridges a zona libvirt en firewalld..."
  firewall-cmd --zone=libvirt --add-interface=virbr0 --permanent 2>/dev/null || true
  firewall-cmd --zone=libvirt --add-interface=virbr1 --permanent 2>/dev/null || true
  firewall-cmd --reload

  info "Instalando XML de VMs..."
  if [ -d "$ROOTDIR/vm-xml" ]; then
      for vm in "$ROOTDIR"/vm-xml/*.xml; do
          [ -e "$vm" ] && virsh define "$vm" || true
      done
  fi

  info "Configurando puertos de red para VMs..."
  if [ -f "$ROOTDIR/scripts/vfio-network-forward-setup.sh" ]; then
      bash "$ROOTDIR/scripts/vfio-network-forward-setup.sh"
  fi

  # ────────────────────────────────────────────────────────────────────────────
  # LLAMADAS A SUB-MÓDULOS UNIFICADOS
  # ────────────────────────────────────────────────────────────────────────────
  setup_selinux_passthrough
  optimize_system_vfio

  info "Ajustando contexto SELinux final para hooks..."
  restorecon -R /etc/libvirt || true

  # Verificación final limpia de SELinux
  echo ""
  info "=== Verificación Final de SELinux ==="
  echo -n "  virtqemud_t permissive: "
  if semanage permissive -l 2>/dev/null | grep -q 'virtqemud_t'; then
      echo -e "${GREEN}OK${NC}"
  else
      echo -e "${RED}FALLO${NC}"
  fi

  desktop_entry

  info "Instalación completada con éxito."
  warn "Reinicia el equipo imperativamente para aplicar el aislamiento de la GPU y los cambios de grupo."
}

# Ejecutar el proceso completo
install_virt
