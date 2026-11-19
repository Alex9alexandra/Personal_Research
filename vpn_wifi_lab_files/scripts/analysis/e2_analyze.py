#!/usr/bin/env python3
"""E2 summary. usage: python e2_analyze.py <results/e2/folder>"""
import csv, math, statistics as st, sys, collections
d = sys.argv[1]
T95 = [0, 12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
       2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086, 2.080,
       2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042]
data = collections.defaultdict(list)
with open(f"{d}/e2_raw.csv") as f:
    for r in csv.DictReader(f):
        try:
            v = float(r["value"])
        except ValueError:
            continue
        data[(r["profile"], r["config"], r["metric"])].append(v)
ORDER = {"B": 0, "W": 1, "O": 2, "I": 3}
rows = []
for (p, c, m), xs in data.items():
    n = len(xs)
    mean = st.mean(xs)
    sd = st.stdev(xs) if n > 1 else 0.0
    ci = (T95[n - 1] if n - 1 < len(T95) else 1.96) * sd / math.sqrt(n) if n > 1 else 0.0
    rows.append(dict(profile=p, config=c, metric=m, n=n, mean=mean, sd=sd, ci95=ci))
base = {(r["profile"], r["metric"]): r["mean"] for r in rows if r["config"] == "B"}
for r in rows:
    b = base.get((r["profile"], r["metric"]))
    if r["config"] == "B" or b is None:
        r["vs_B"] = ""
    elif r["metric"].startswith("tcp"):
        r["vs_B"] = f"{100 * (b - r['mean']) / b:.1f} % slower"
    else:
        r["vs_B"] = f"{r['mean'] - b:+.2f}"
rows.sort(key=lambda r: (r["profile"], r["metric"], ORDER[r["config"]]))
with open(f"{d}/e2_summary.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["profile", "config", "metric", "n", "mean", "sd", "ci95", "vs_B"])
    w.writeheader()
    for r in rows:
        w.writerow({**r, "mean": round(r["mean"], 3), "sd": round(r["sd"], 3), "ci95": round(r["ci95"], 3)})
print(f"{'profile':<8}{'metric':<15}{'cfg':<4}{'n':<4}{'mean':>10} {'+/-95%CI':>9}  vs B")
for r in rows:
    print(f"{r['profile']:<8}{r['metric']:<15}{r['config']:<4}{r['n']:<4}{r['mean']:>10.2f} {r['ci95']:>9.2f}  {r['vs_B']}")