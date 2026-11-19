#!/usr/bin/env python3
"""usage: python e3_probe.py <results/e3/folder> <outage_seconds>"""
import glob, os, re, sys
out, outage = sys.argv[1], float(sys.argv[2])
leaks = {}
p = os.path.join(out, "leaks.csv")
if os.path.exists(p):
    for line in open(p):
        parts = line.strip().split(",", 3)
        if len(parts) >= 3:
            leaks[parts[0]] = parts[1:]
print("config  recovered  recovery_s  N_leak  W_exp_s  leaked_to")
for f in sorted(glob.glob(os.path.join(out, "probe_*.txt"))):
    cfg = os.path.basename(f)[6:-4]
    ts = [float(m.group(1)) for l in open(f)
          for m in [re.match(r"\[(\d+\.\d+)\] \d+ bytes from", l)] if m]
    if not ts:
        print(f"{cfg:<7} no replies at all"); continue
    gap = max((b - a for a, b in zip(ts, ts[1:])), default=0.0)
    ok = "yes" if ts[-1] - ts[0] > outage + 20 else "NO"
    n, w, *dst = leaks.get(cfg, ["?", "?", ""])
    print(f"{cfg:<7} {ok:<10} {max(0.0, gap - outage):<11.1f} {n:<7} {w:<8} {dst[0] if dst else ''}")