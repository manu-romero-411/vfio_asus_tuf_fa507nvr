#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="gui_logout"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

asusctl aura effect static -c ff3105

log_title "FIN (args: $*)"
