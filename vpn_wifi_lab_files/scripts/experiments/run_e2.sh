#!/usr/bin/env bash
# E2: what does it cost? Configs B, W, O, I x profiles good, weak.
# Run: bash scripts/experiments/run_e2.sh
# Quick test: REPS=1 DUR=3 bash scripts/experiments/run_e2.sh
set -uo pipefail
source scripts/experiments/lib.sh
REPS=${REPS:-10}; DUR=${DUR:-5}
OUT=results/e2/$(date +%Y%m%d_%H%M); mkdir -p "$OUT"

profile_set() {
  case $1 in
    good) P="delay 10ms 2ms loss 0% rate 100mbit"; RATE=50M ;;
    weak) P="delay 50ms 20ms loss 2% rate 10mbit"; RATE=5M ;;
  esac
  vm gateway ". /etc/lab-env; sudo tc qdisc replace dev \$CAFE_IF root netem $P" >/dev/null
  vm client "sudo tc qdisc replace dev \$(ifname-for-ip 10.10.0.10) root netem $P" >/dev/null
}
profile_clear() {
  vm gateway ". /etc/lab-env; sudo tc qdisc del dev \$CAFE_IF root" >/dev/null
  vm client "sudo tc qdisc del dev \$(ifname-for-ip 10.10.0.10) root" >/dev/null
}

tunnel_down
vm vpnserver "sudo systemctl stop iperf5201 iperf5202 2>/dev/null; pkill iperf3; sleep 1; sudo systemd-run --quiet --collect --unit=iperf5201 iperf3 -s -p 5201; sudo systemd-run --quiet --collect --unit=iperf5202 iperf3 -s -B 10.31.0.1 -p 5202" >/dev/null
put client /tmp/e2.sh "$(cat scripts/experiments/e2_measure.sh)"
echo "profile,config,metric,rep,value" > "$OUT/e2_raw.csv"
sed -i 's/^profile,config/config,profile/' "$OUT/e2_raw.csv"

for prof in good weak; do
  profile_set $prof
  for cfg in ${CFGS:-B W O I}; do
    echo "== $prof / $cfg =="
    tunnel_up $cfg; sleep 3
    case $cfg in B) T=10.20.0.2; PORT=5201;; W) T=10.8.0.1; PORT=5201;; O) T=10.9.0.1; PORT=5201;; I) T=10.31.0.1; PORT=5202;; esac
    vm client "bash /tmp/e2.sh $T $REPS $DUR $RATE $PORT" | while IFS=, read -r metric rep val; do
      echo "$cfg,$prof,$metric,$rep,$val" >> "$OUT/e2_raw.csv"
    done
    tunnel_down
  done
done
profile_clear
echo "Raw data in $OUT/e2_raw.csv. Summary:  python scripts/analysis/e2_analyze.py $OUT"