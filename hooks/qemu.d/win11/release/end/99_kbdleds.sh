#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="kbdleds"
#exec >> /tmp/vfio-hook.log 2>&1
log_title "INICIO (args: $*)"

asusctl aura effect static -c 0082a6

log_title "FIN (args: $*)"
