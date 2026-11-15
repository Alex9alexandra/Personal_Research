#!/usr/bin/env bash
# Packages and helpers installed on every VM.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  curl wget iproute2 iputils-ping net-tools dnsutils traceroute \
  iperf3 tcpdump tshark sysstat jq ca-certificates \
  iptables

# tshark asks whether non-root users may capture; allow it for the vagrant user.
usermod -aG wireshark vagrant || true

# Helper: print the name of the interface that carries a given IPv4 address.
cat >/usr/local/bin/ifname-for-ip <<'EOF'
#!/usr/bin/env bash
ip -o -4 addr show | awk -v ip="$1" '$4 ~ "^"ip"/" {print $2}'
EOF
chmod +x /usr/local/bin/ifname-for-ip

echo "[common] done on $(hostname)"
