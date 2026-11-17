#!/usr/bin/env bash
# IKEv2/IPsec (strongSwan, swanctl, certificate auth, ESP AES-256-GCM) full tunnel.
# Uses the CA and certificates created by setup_openvpn.sh. Tunnel pool: 10.30.0.0/24.
# Run from the repo folder in Git Bash: bash scripts/vpn/setup_ikev2.sh
set -euo pipefail

vm() { local m="$1"; shift; vagrant ssh "$m" -c "$*" 2>/dev/null | tr -d '\r'; }
put() { # put <machine> <path> <content>
  local b64; b64=$(printf '%s\n' "$3" | base64 -w0)
  vagrant ssh "$1" -c "echo $b64 | base64 -d | sudo tee $2 >/dev/null && sudo chmod 600 $2" 2>/dev/null
}

SRV_IF=$(vm vpnserver "ifname-for-ip 10.20.0.2")

# --- 1. Packages: charon-systemd + swanctl (instead of the legacy ipsec.conf starter) ---
for m in vpnserver client; do
  echo "Installing strongSwan swanctl on $m ..."
  vagrant ssh $m -c "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y charon-systemd strongswan-swanctl; sudo systemctl disable --now strongswan-starter 2>/dev/null; sudo mkdir -p /etc/swanctl/x509 /etc/swanctl/x509ca /etc/swanctl/private" >/dev/null 2>&1 || true
done

# --- 2. Certificates ---
vagrant ssh vpnserver -c "sudo cp /etc/openvpn/pki/ca.crt /etc/swanctl/x509ca/ca.crt && sudo cp /etc/openvpn/pki/server.crt /etc/swanctl/x509/server.crt && sudo cp /etc/openvpn/pki/server.key /etc/swanctl/private/server.key" 2>/dev/null \
  || { echo "OpenVPN PKI missing: run setup_openvpn.sh first"; exit 1; }
put client /etc/swanctl/x509ca/ca.crt     "$(vm vpnserver 'sudo cat /etc/openvpn/pki/ca.crt')"
put client /etc/swanctl/x509/client.crt   "$(vm vpnserver 'sudo cat /etc/openvpn/pki/client.crt')"
put client /etc/swanctl/private/client.key "$(vm vpnserver 'sudo cat /etc/openvpn/pki/client.key')"

# --- 3. Server config ---
SRV_CONF='connections {
  lab {
    version = 2
    local_addrs = 10.20.0.2
    pools = lab-pool
    proposals = aes256gcm16-prfsha256-curve25519
    local {
      auth = pubkey
      certs = server.crt
    }
    remote {
      auth = pubkey
    }
    children {
      lab {
        local_ts = 0.0.0.0/0
        esp_proposals = aes256gcm16-curve25519
      }
    }
  }
}
pools {
  lab-pool {
    addrs = 10.30.0.0/24
  }
}'
put vpnserver /etc/swanctl/swanctl.conf "$SRV_CONF"

# NAT for tunnel clients + a test address (10.31.0.1) on the server, applied at every boot
NATUNIT="[Unit]
Description=Lab NAT and test address for IKEv2
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'iptables -t nat -C POSTROUTING -s 10.30.0.0/24 -o $SRV_IF -j MASQUERADE || iptables -t nat -A POSTROUTING -s 10.30.0.0/24 -o $SRV_IF -j MASQUERADE; ip addr replace 10.31.0.1/32 dev lo'

[Install]
WantedBy=multi-user.target"
put vpnserver /etc/systemd/system/lab-ikev2-nat.service "$NATUNIT"
vagrant ssh vpnserver -c "sudo systemctl daemon-reload && sudo systemctl enable --now lab-ikev2-nat && sudo systemctl enable strongswan >/dev/null 2>&1; sudo systemctl restart strongswan; sleep 3; sudo swanctl --load-all" >/dev/null 2>&1 || true
echo "server strongswan: $(vm vpnserver 'systemctl is-active strongswan')"

# --- 4. Client config: do not let charon install routes (we add them ourselves) ---
CLI_CONF='connections {
  lab {
    version = 2
    remote_addrs = 10.20.0.2
    vips = 0.0.0.0
    proposals = aes256gcm16-prfsha256-curve25519
    local {
      auth = pubkey
      certs = client.crt
    }
    remote {
      auth = pubkey
      id = "CN=server"
    }
    children {
      lab {
        remote_ts = 0.0.0.0/0
        esp_proposals = aes256gcm16-curve25519
        start_action = none
      }
    }
  }
}'
put client /etc/swanctl/swanctl.conf "$CLI_CONF"
put client /etc/strongswan.d/lab.conf 'charon {
  install_routes = no
}
charon-systemd {
  install_routes = no
}'

UP='#!/bin/bash
set -e
swanctl --load-all >/dev/null
swanctl --initiate --child lab >/dev/null
VIP=$(ip -4 -o addr show | grep -o "10\.30\.0\.[0-9]*" | head -1)
GW=10.10.0.254
IF=$(ifname-for-ip 10.10.0.10)
ip route replace 10.20.0.2/32 via $GW dev $IF src 10.10.0.10
ip route replace 0.0.0.0/1 via $GW dev $IF src $VIP
ip route replace 128.0.0.0/1 via $GW dev $IF src $VIP
echo "IKEv2 tunnel up, virtual IP $VIP"'
DOWN='#!/bin/bash
ip route del 0.0.0.0/1 2>/dev/null || true
ip route del 128.0.0.0/1 2>/dev/null || true
ip route del 10.20.0.2/32 2>/dev/null || true
swanctl --terminate --ike lab >/dev/null 2>&1 || true
echo "IKEv2 tunnel down"'
put client /usr/local/bin/ikev2-up "$UP"
put client /usr/local/bin/ikev2-down "$DOWN"
vagrant ssh client -c "sudo chmod 755 /usr/local/bin/ikev2-up /usr/local/bin/ikev2-down; sudo systemctl enable strongswan >/dev/null 2>&1; sudo systemctl restart strongswan" >/dev/null 2>&1 || true
echo "client strongswan: $(vm client 'systemctl is-active strongswan')"
echo "Start on the client with: vagrant ssh client -c 'sudo ikev2-up'"