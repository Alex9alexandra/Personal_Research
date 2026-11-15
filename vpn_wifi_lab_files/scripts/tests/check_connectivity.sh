#!/usr/bin/env bash
# Checks that the virtual lab is wired correctly.
# Run it from the repo folder (the one with the Vagrantfile), in Git Bash or PowerShell:
#   bash scripts/tests/check_connectivity.sh
#
# It uses `vagrant ssh -c` to run commands inside each VM.

pass=0
fail=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  [ OK ] $desc"; pass=$((pass+1))
  else
    echo "  [FAIL] $desc"; fail=$((fail+1))
  fi
}

vm() {  # vm <machine> <command...>
  local m="$1"; shift
  vagrant ssh "$m" -c "$*" 2>/dev/null
}

echo "== Connectivity inside the cafe network =="
check "client -> gateway (10.10.0.254)"      vm client   "ping -c 2 -W 2 10.10.0.254"
check "attacker -> gateway (10.10.0.254)"    vm attacker "ping -c 2 -W 2 10.10.0.254"
check "client -> attacker (10.10.0.66)"    vm client   "ping -c 2 -W 2 10.10.0.66"

echo "== Routing to the transit network =="
check "client -> vpnserver (10.20.0.2)"    vm client   "ping -c 2 -W 2 10.20.0.2"
check "vpnserver -> client (10.10.0.10)"   vm vpnserver "ping -c 2 -W 2 10.10.0.10"

echo "== Internet access through the gateway =="
check "client -> 1.1.1.1"                  vm client   "ping -c 2 -W 3 1.1.1.1"
check "client resolves a name"             vm client   "getent hosts example.com"
check "client fetches an HTTPS page"       vm client   "curl -sS -m 10 -o /dev/null https://example.com"
check "vpnserver -> 1.1.1.1"               vm vpnserver "ping -c 2 -W 3 1.1.1.1"

echo "== Client really leaves through the gateway =="
check "client default route is via 10.10.0.254" \
  vm client "ip route show default | head -1 | grep -q 'via 10.10.0.254'"

echo "== Software installed =="
check "iperf3 on client"       vm client    "command -v iperf3"
check "tshark on attacker"     vm attacker  "command -v tshark"
check "wireguard on vpnserver" vm vpnserver "command -v wg"
check "openvpn on vpnserver"   vm vpnserver "command -v openvpn"
check "strongswan on vpnserver" vm vpnserver "command -v ipsec || command -v swanctl"

echo
echo "Passed: $pass   Failed: $fail"
[ "$fail" -eq 0 ]
