# VFIO ASUS TUF FA507NVR Setup

Complete automation toolkit for configuring GPU passthrough virtual machines on a Fedora host using libvirt, QEMU, and VFIO.

---

## Overview

This repository contains scripts, hooks, and configuration files to fully automate a VFIO virtual machine environment optimized for Windows gaming and testing setups. It is designed specifically for ASUS TUF A15 F507NVR, but can be adapted to other hardware .

It handles:

* libvirt + QEMU setup
* VM definitions
* Custom virtual network
* CPU pinning
* Hugepages
* GPU binding/unbinding
* Audio isolation
* and more to come

---

## Host System Specifications

* **Laptop model:** ASUS TUF FA507NVR
* **CPU:** AMD Ryzen 7435HS
* **GPU:** Nvidia RTX 4060 Laptop
* **iGPU:** nothing
* **RAM:** 32 GB DDR5
* **Storage:** 1 TB NVMe
* **Host OS:** Fedora 43 KDE Plasma Edition
* **Kernel:** 6.18.12-200.fc43.x86_64

---

## Repository Structure

```
.
├── hooks/                # libvirt hook scripts
├── network-xml/          # custom virtual networks
├── vm-xml/               # virtual machine definitions
└── README.md
```

### hooks/

Installed into:

```
/etc/libvirt/
```

Contains lifecycle automation scripts executed when VMs start/stop.

---

### network-xml/

Defines custom libvirt networks.

* `win-vms.xml` → specific non-NAT network for Windows guests

---

### vm-xml/

Preconfigured VM definitions:

* **win11.xml** → Windows 11 with GPU passthrough
* **win11-nogpu.xml** → fallback VM without passthrough
* **win-gaming.xml** → optimized gaming profile

---

## Installation

After cloning, run:

```bash
chmod +x install.sh
./install.sh --install
```

This will:

* Install virtualization packages
* Enable libvirt
* Configure permissions
* Deploy hooks
* Define networks
* Register VMs

Then log out and log back in.

---

## Troubleshooting
### Hooks not executing

Check permissions:

```
sudo chmod -R +x /etc/libvirt/hooks
```

and SELinux logs:

```
sudo ausearch -m avc -ts recent
```

