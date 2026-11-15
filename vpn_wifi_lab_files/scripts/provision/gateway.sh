#!/usr/bin/env bash
# Gateway: connects the "cafe" network (10.10.0.0/24) and the transit network
# (10.20.0.0/24) to the real internet through the default NAT adapter.
set -euo pipefail

CAFE_IP=10.10.0.254
TRANSIT_IP=10.20.0.254

# --- enable IPv4 forwarding (persistent) ------------------------------------
cat >/etc/sysctl.d/99-lab-forward.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# --- find the interfaces by IP (names differ between VMware/VirtualBox) -----
CAFE_IF=$(ifname-for-ip "$CAFE_IP")
TRANSIT_IF=$(ifname-for-ip "$TRANSIT_IP")
# The uplink is the interface that holds the default route (Vagrant NAT adapter).
UPLINK_IF=$(ip -o -4 route show default | awk '{print $5; exit}')

echo "[gateway] cafe=$CAFE_IF transit=$TRANSIT_IF uplink=$UPLINK_IF"

# --- firewall: forward + NAT -------------------------------------------------
iptables -F
iptables -t nat -F
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o "$UPLINK_IF" -j MASQUERADE

# Persist the rules across reboots.
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
netfilter-persistent save

# Remember the interface names for the experiment scripts.
cat >/etc/lab-env <<EOF
CAFE_IF=$CAFE_IF
TRANSIT_IF=$TRANSIT_IF
UPLINK_IF=$UPLINK_IF
EOF

echo "[gateway] done"
