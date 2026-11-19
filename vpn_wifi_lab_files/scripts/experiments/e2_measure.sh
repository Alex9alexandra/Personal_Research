#!/usr/bin/env bash
# usage: bash e2_measure.sh <target> <reps> <duration_s> <udp_rate>
T=$1; REPS=$2; DUR=$3; RATE=$4; PORT=${5:-5201}
busy() { awk '/^cpu /{print $2+$3+$4+$7+$8+$9}' /proc/stat; }
for r in $(seq 1 "$REPS"); do
  J=$(iperf3 -c "$T" -p "$PORT" -t "$DUR" -J 2>/dev/null)
  echo "tcp_up_mbps,$r,$(echo "$J" | jq '.end.sum_received.bits_per_second/1e6' 2>/dev/null)"
  sleep 1
  b0=$(busy)
  J=$(iperf3 -c "$T" -p "$PORT" -t "$DUR" -R -J 2>/dev/null)
  b1=$(busy)
  echo "tcp_down_mbps,$r,$(echo "$J" | jq '.end.sum_received.bits_per_second/1e6' 2>/dev/null)"
  bytes=$(echo "$J" | jq '.end.sum_received.bytes' 2>/dev/null)
  echo "cpu_s_per_gb,$r,$(awk -v a="$b0" -v b="$b1" -v n="${bytes:-0}" 'BEGIN{if(n+0>0) print (b-a)/100/(n/1e9)}')"
  sleep 1
  J=$(iperf3 -c "$T" -p "$PORT" -u -b "$RATE" -t "$DUR" -J 2>/dev/null)
  echo "udp_jitter_ms,$r,$(echo "$J" | jq '.end.sum.jitter_ms' 2>/dev/null)"
  echo "udp_loss_pct,$r,$(echo "$J" | jq '.end.sum.lost_percent' 2>/dev/null)"
  sleep 1
  echo "rtt_ms,$r,$(ping -c 25 -i 0.2 -q "$T" | awk -F'[/ ]' '/^rtt/{print $8}')"
done