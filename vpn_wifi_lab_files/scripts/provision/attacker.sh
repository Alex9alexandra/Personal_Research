#!/usr/bin/env bash
# Attacker: a passive observer connected to the same cafe network as the client.
# Its network interface is put in promiscuous mode so it can capture frames
# that are not addressed to it.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

ATTACKER_IP=10.10.0.66
GATEWAY_IP=10.10.0.254

IF=$(ifname-for-ip "$ATTACKER_IP")
ip route replace default via "$GATEWAY_IP" dev "$IF" metric 50

cat >/etc/systemd/system/lab-promisc.service <<EOF
[Unit]
Description=Promiscuous mode on cafe interface
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set $IF promisc on
ExecStart=/usr/sbin/ip route replace default via $GATEWAY_IP dev $IF metric 50
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now lab-promisc.service

# Analysis tools used on the captures.
apt-get install -y python3 python3-pip python3-scapy

echo "CAFE_IF=$IF" >/etc/lab-env
echo "[attacker] done (capture interface: $IF)"
