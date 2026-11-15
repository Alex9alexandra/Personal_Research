#!/usr/bin/env bash
# VPN server: sits behind the gateway on the transit network (10.20.0.0/24).
# Today we only install the software and fix routing; the VPN configs
# (WireGuard, OpenVPN, strongSwan) are added in the next step.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SERVER_IP=10.20.0.2
GATEWAY_IP=10.20.0.254

# --- send everything through the gateway (low metric beats the NAT adapter) --
IF=$(ifname-for-ip "$SERVER_IP")
ip route replace default via "$GATEWAY_IP" dev "$IF" metric 50

# Make the route survive a reboot via a small systemd unit.
cat >/etc/systemd/system/lab-route.service <<EOF
[Unit]
Description=Lab default route via gateway
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

# --- VPN software (configured later) -----------------------------------------
apt-get install -y wireguard wireguard-tools openvpn easy-rsa \
  strongswan strongswan-pki libcharon-extra-plugins libstrongswan-extra-plugins

# iperf3 server is started on demand by the experiment scripts.

# Allow forwarding so VPN clients can reach the internet through this server.
cat >/etc/sysctl.d/99-lab-forward.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

echo "[vpnserver] done"
