#!/usr/bin/env bash
# Client: the laptop of the person in the cafe. Its traffic goes through the
# gateway (10.10.0.254), not through the Vagrant NAT adapter.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

CLIENT_IP=10.10.0.10
GATEWAY_IP=10.10.0.254

IF=$(ifname-for-ip "$CLIENT_IP")
ip route replace default via "$GATEWAY_IP" dev "$IF" metric 50

cat >/etc/systemd/system/lab-route.service <<EOF
[Unit]
Description=Lab default route via cafe gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip route replace default via $GATEWAY_IP dev $IF metric 50
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable lab-route.service

# Use a public resolver so DNS goes out through the gateway (visible to the attacker).
mkdir -p /etc/systemd/resolved.conf.d
cat >/etc/systemd/resolved.conf.d/lab.conf <<'EOF'
[Resolve]
DNS=1.1.1.1
FallbackDNS=8.8.8.8
DNSStubListener=yes
EOF
systemctl restart systemd-resolved

# VPN client software (configured later) and tools for the experiments.
apt-get install -y wireguard wireguard-tools openvpn \
  strongswan libcharon-extra-plugins python3 python3-pip

echo "[client] done"
