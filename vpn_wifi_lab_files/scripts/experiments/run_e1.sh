#!/usr/bin/env bash
# E1: what does the attacker see?
# Configs: B = HTTPS only, D = HTTPS + DoH, W = WireGuard, O = OpenVPN, I = IKEv2.
# Run from the repo folder in Git Bash:  bash scripts/experiments/run_e1.sh
# Quick test: REPS=1 bash scripts/experiments/run_e1.sh
set -uo pipefail
REPS=${REPS:-5}
SITES=$(grep -v '^#' config/sites.txt | tr -d '\r' | grep .)
OUT=results/e1/$(date +%Y%m%d_%H%M)
mkdir -p "$OUT"
: > "$OUT/ground_truth.csv"

vm() { local m="$1"; shift; vagrant ssh "$m" -c "$*" 2>/dev/null | tr -d '\r'; }
put() { # put <machine> <path> <content>
  local b64; b64=$(printf '%s\n' "$3" | base64 -w0)
  vagrant ssh "$1" -c "echo $b64 | base64 -d | sudo tee $2 >/dev/null && sudo chmod 644 $2" 2>/dev/null
}

tunnel_down() {
  vm client "sudo wg-quick down wg0; sudo systemctl stop openvpn-client@lab; sudo ikev2-down" >/dev/null
}
tunnel_up() {
  case $1 in
    W) vm client "sudo wg-quick up wg0" >/dev/null ;;
    O) vm client "sudo systemctl start openvpn-client@lab; for i in \$(seq 1 30); do ip link show tun0 >/dev/null 2>&1 && break; sleep 1; done" >/dev/null ;;
    I) vm client "sudo ikev2-up" >/dev/null ;;
  esac
}

vm attacker "sudo pkill tcpdump; sudo rm -rf /tmp/e1; sudo mkdir -p /tmp/e1; sudo chmod 777 /tmp/e1" >/dev/null
tunnel_down

for cfg in B D W O I; do
  echo "== config $cfg =="
  tunnel_up $cfg; sleep 3
  DOH=""; [ "$cfg" = "D" ] && DOH="--doh-url https://1.1.1.1/dns-query"
  echo "sanity check: $(vm client "curl -s -m 15 -o /dev/null -w '%{http_code}' $DOH https://example.com")"
  for site in $SITES; do
    for rep in $(seq 1 "$REPS"); do
      name="${cfg}__${site}__${rep}"
            vagrant ssh attacker -c "sudo systemd-run --quiet --collect --unit=e1cap tcpdump -i eth1 -nn -U -w /tmp/e1/$name.pcap host 10.10.0.10" >/dev/null 2>&1
      sleep 2
      res=$(vm client "sudo resolvectl flush-caches; curl -s -m 20 -A 'Mozilla/5.0' -o /dev/null -w '%{http_code} %{remote_ip}' $DOH https://$site/" | tail -1)
      sleep 1
            vm attacker "sudo systemctl stop e1cap; sleep 1" >/dev/null
      echo "$name,$cfg,$site,$rep,${res%% *},${res##* }" >> "$OUT/ground_truth.csv"
      echo "  $name -> $res"
    done
  done
  tunnel_down
done

echo "== analysing captures on the attacker =="
put attacker /tmp/e1_truth.csv "$(cat "$OUT/ground_truth.csv")"
put attacker /tmp/e1_analyze.py "$(cat scripts/analysis/e1_analyze.py)"
vm attacker "sudo python3 /tmp/e1_analyze.py /tmp/e1 /tmp/e1_truth.csv" | tee "$OUT/summary.txt"
vm attacker "sudo cat /tmp/e1/runs.csv"   > "$OUT/runs.csv"
vm attacker "sudo cat /tmp/e1/matrix.csv" > "$OUT/matrix.csv"
echo "Results saved in $OUT"