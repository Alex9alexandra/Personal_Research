#!/usr/bin/env bash
# Checks whether the attacker VM sees the client's traffic (the key assumption of the
# threat model). Run from the repo folder:
#   bash scripts/tests/check_attacker_visibility.sh
#
# 1. starts a 10 s capture on the attacker's cafe interface
# 2. makes the client resolve a name and fetch a page
# 3. counts the packets from/to the client that the attacker captured

CLIENT_IP=10.10.0.10

echo "Starting capture on attacker..."
vagrant ssh attacker -c "source /etc/lab-env; sudo timeout 12 tcpdump -i \$CAFE_IF -nn -w /tmp/visibility.pcap host $CLIENT_IP" >/dev/null 2>&1 &
CAP_PID=$!
sleep 3

echo "Generating traffic from client..."
vagrant ssh client -c "curl -sS -m 8 -o /dev/null https://example.com; dig +short example.com @1.1.1.1" >/dev/null 2>&1

wait $CAP_PID 2>/dev/null

N=$(vagrant ssh attacker -c "tcpdump -nn -r /tmp/visibility.pcap 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r')
echo "Packets from/to client seen by attacker: ${N:-0}"

if [ "${N:-0}" -gt 5 ]; then
  echo "[ OK ] The attacker sees the client's traffic."
else
  echo "[FAIL] The attacker does NOT see the client's traffic."
  echo "       Check: promiscuous mode in VMware, or capture on the gateway instead"
  echo "       (see docs/SETUP.md, section 'If the attacker sees nothing')."
  exit 1
fi
