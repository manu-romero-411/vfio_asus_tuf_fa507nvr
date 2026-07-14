#!/bin/bash

VM_IP="192.168.122.100"
ZONE=$(firewall-cmd --get-zone-of-interface=virbr0)

# Forward RDP
firewall-cmd --zone=$ZONE --add-forward-port=port=43389:proto=tcp:toaddr=$VM_IP:toport=3389

# Forward Sunshine TCP
for port in 47984 47989 47990 48010; do
    firewall-cmd --zone=$ZONE --add-forward-port=port=$port:proto=tcp:toaddr=$VM_IP:toport=$port
done

# Forward Sunshine UDP
for port in 47998 47999 48000 48010; do
    firewall-cmd --zone=$ZONE --add-forward-port=port=$port:proto=udp:toaddr=$VM_IP:toport=$port
done
