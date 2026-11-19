#!/usr/bin/env bash
# E3a: a network outage while the tunnel is up. Configs W, O, I.
# Run: bash scripts/experiments/run_e3.sh (OUTAGE=30 bash ... for another duration)
set -uo pipefail
source scripts/experiments/lib.sh
OUTAGE=${OUTAGE:-15}
WAIT=${WAIT:-40}
TOTAL=$((OUTAGE + WAIT + 30))
OUT=results/e3/$(date +%Y%m%d_%H%M); mkdir -p "$OUT"
DROP_ON="iptables -I FORWARD 1 -s 10.10.0.10 -j DROP; iptables -I FORWARD 1 -d 10.10.0.10 -j DROP"
DROP_OFF="iptables -D FORWARD -s 10.10.0.10 -j DROP; iptables -D FORWARD -d 10.10.0.10 -j DROP"

vm gateway "sudo sh -c '$DROP_OFF' 2>/dev/null; true" >/dev/null
vm attacker "sudo systemctl stop e1cap e3cap 2>/dev/null; sudo rm -rf /tmp/e3; sudo mkdir -p /tmp/e3; sudo chmod 777 /tmp/e3" >/dev/null
tunnel_down

for cfg in W O I; do
  echo "== $cfg =="
  tunnel_up $cfg; sleep 5
  vagrant ssh attacker -c "sudo systemd-run --quiet --collect --unit=e3cap tcpdump -i eth1 -nn -U -w /tmp/e3/$cfg.pcap host 10.10.0.10" >/dev/null 2>&1
  vagrant ssh client -c "sudo systemd-run --quiet --collect --unit=e3probe sh -c 'ping -D -O -i 0.2 -w $TOTAL 1.1.1.1 > /tmp/probe_$cfg.txt 2>&1'" >/dev/null 2>&1
  sleep 10
  echo "  outage ON for $OUTAGE s"
  vm gateway "sudo sh -c '$DROP_ON; sleep $OUTAGE; $DROP_OFF'" >/dev/null
  echo "  outage OFF, waiting for recovery"
  sleep $WAIT
  vm attacker "sudo systemctl stop e3cap" >/dev/null
  vm client "sudo systemctl stop e3probe; true" >/dev/null
  vm client "cat /tmp/probe_$cfg.txt" > "$OUT/probe_$cfg.txt"
  tunnel_down
done

put attacker /tmp/e3_leaks.py "$(cat scripts/analysis/e3_leaks.py)"
vm attacker "sudo python3 /tmp/e3_leaks.py /tmp/e3" > "$OUT/leaks.csv"
python scripts/analysis/e3_probe.py "$OUT" "$OUTAGE" | tee "$OUT/summary.txt"