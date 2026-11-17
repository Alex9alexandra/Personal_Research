#!/usr/bin/env bash
# OpenVPN (UDP 1194, TLS + AES-256-GCM) full tunnel: client -> vpnserver. Tunnel net 10.9.0.0/24.
# Run from the repo folder in Git Bash: bash scripts/vpn/setup_openvpn.sh
set -euo pipefail

vm() { local m="$1"; shift; vagrant ssh "$m" -c "$*" 2>/dev/null | tr -d '\r'; }
put() { # put <machine> <path> <content>
  local b64; b64=$(printf '%s\n' "$3" | base64 -w0)
  vagrant ssh "$1" -c "echo $b64 | base64 -d | sudo tee $2 >/dev/null && sudo chmod 600 $2" 2>/dev/null
}

SRV_IF=$(vm vpnserver "ifname-for-ip 10.20.0.2")

# --- 1. Small private CA + server and client certificates (lab use only) ---
PKI='set -e
rm -rf /etc/openvpn/pki; mkdir -p /etc/openvpn/pki; cd /etc/openvpn/pki
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -subj "/CN=lab-ca" -days 365
for n in server client; do
  openssl req -newkey rsa:2048 -nodes -keyout $n.key -out $n.csr -subj "/CN=$n"
  if [ $n = server ]; then eku=serverAuth; else eku=clientAuth; fi
  printf "keyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=%s\n" $eku > $n.ext
  openssl x509 -req -in $n.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out $n.crt -days 365 -extfile $n.ext
done
chmod 600 *.key'
put vpnserver /tmp/pki.sh "$PKI"
vagrant ssh vpnserver -c "sudo bash /tmp/pki.sh" >/dev/null || { echo "PKI generation failed"; exit 1; }

# --- 2. Server config ---
SRV_CONF='port 1194
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/server.crt
key /etc/openvpn/pki/server.key
dh none
topology subnet
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1"
data-ciphers AES-256-GCM
keepalive 10 60
explicit-exit-notify 1
persist-key
persist-tun
verb 3'
put vpnserver /etc/openvpn/server/server.conf "$SRV_CONF"

# NAT for tunnel clients, re-applied every time the service starts
DROPIN="[Service]
ExecStartPost=/bin/sh -c 'iptables -t nat -C POSTROUTING -s 10.9.0.0/24 -o $SRV_IF -j MASQUERADE || iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o $SRV_IF -j MASQUERADE'"
vagrant ssh vpnserver -c "sudo mkdir -p /etc/systemd/system/openvpn-server@server.service.d" 2>/dev/null
put vpnserver /etc/systemd/system/openvpn-server@server.service.d/nat.conf "$DROPIN"

vagrant ssh vpnserver -c "sudo systemctl daemon-reload && sudo systemctl enable openvpn-server@server >/dev/null 2>&1 && sudo systemctl restart openvpn-server@server" 2>/dev/null
echo "server service: $(vm vpnserver 'systemctl is-active openvpn-server@server')"

# --- 3. Client config (certificates inline) ---
CA=$(vm vpnserver "sudo cat /etc/openvpn/pki/ca.crt")
CRT=$(vm vpnserver "sudo cat /etc/openvpn/pki/client.crt")
KEY=$(vm vpnserver "sudo cat /etc/openvpn/pki/client.key")
CLI_CONF="client
dev tun
proto udp
remote 10.20.0.2 1194
nobind
persist-key
persist-tun
remote-cert-tls server
data-ciphers AES-256-GCM
verb 3
<ca>
$CA
</ca>
<cert>
$CRT
</cert>
<key>
$KEY
</key>"
put client /etc/openvpn/client/lab.conf "$CLI_CONF"

echo "OpenVPN configured. Start on the client with:"
echo "  vagrant ssh client -c 'sudo systemctl start openvpn-client@lab'"