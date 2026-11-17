#!/usr/bin/env bash
# WireGuard full tunnel: client (10.8.0.2) -> vpnserver (10.8.0.1).
# Run from the repo folder in Git Bash: bash scripts/vpn/setup_wireguard.sh
set -euo pipefail

vm() { local m="$1"; shift; vagrant ssh "$m" -c "$*" 2>/dev/null | tr -d '\r'; }
put() { # put <machine> <path> <content>
  local b64; b64=$(printf '%s\n' "$3" | base64 -w0)
  vagrant ssh "$1" -c "echo $b64 | base64 -d | sudo tee $2 >/dev/null && sudo chmod 600 $2" 2>/dev/null
}

SRV_PRIV=$(vm vpnserver "wg genkey")
SRV_PUB=$(vm vpnserver "echo $SRV_PRIV | wg pubkey")
CLI_PRIV=$(vm client "wg genkey")
CLI_PUB=$(vm client "echo $CLI_PRIV | wg pubkey")
SRV_IF=$(vm vpnserver "ifname-for-ip 10.20.0.2")

SRV_CONF="[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $SRV_PRIV
PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $SRV_IF -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $SRV_IF -j MASQUERADE

[Peer]
PublicKey = $CLI_PUB
AllowedIPs = 10.8.0.2/32"

CLI_CONF="[Interface]
Address = 10.8.0.2/24
PrivateKey = $CLI_PRIV

[Peer]
PublicKey = $SRV_PUB
Endpoint = 10.20.0.2:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25"

put vpnserver /etc/wireguard/wg0.conf "$SRV_CONF"
put client    /etc/wireguard/wg0.conf "$CLI_CONF"

vagrant ssh vpnserver -c "sudo systemctl enable wg-quick@wg0 && sudo systemctl restart wg-quick@wg0" 2>/dev/null
echo "WireGuard configured. Start the tunnel on the client with:"
echo "  vagrant ssh client -c 'sudo wg-quick up wg0'"