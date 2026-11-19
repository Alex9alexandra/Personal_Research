#!/usr/bin/env python3
"""E1: what does a passive attacker recover from each capture?
usage: e1_analyze.py <capture_dir> <ground_truth.csv>"""
import csv, glob, os, subprocess, sys, collections

CAP_DIR, TRUTH = sys.argv[1], sys.argv[2]
CLIENT = "10.10.0.10"
ORDER = ["B", "D", "W", "O", "I"]

truth = {}
with open(TRUTH) as f:
    for row in csv.reader(f):
        if len(row) >= 6:
            truth[row[0]] = row  # name,cfg,site,rep,code,ip

def vpn_signature(pkts):
    sig = set()
    for p in pkts:
        if p["src"] != CLIENT:
            continue
        if p["proto"] == "50":
            sig.add("ESP")
        elif p["dport"] == "51820":
            sig.add("WireGuard")
        elif p["dport"] == "1194":
            sig.add("OpenVPN")
        elif p["dport"] in ("500", "4500"):
            sig.add("IKE")
    return "+".join(sorted(sig)) or "none"

rows = []
for path in sorted(glob.glob(os.path.join(CAP_DIR, "*.pcap"))):
    name = os.path.basename(path)[:-5]
    if name not in truth:
        continue
    _, cfg, site, rep, code, ip = truth[name][:6]
    cmd = ["tshark", "-r", path, "-T", "fields",
           "-e", "ip.src", "-e", "ip.dst", "-e", "ip.proto",
           "-e", "udp.srcport", "-e", "udp.dstport", "-e", "frame.len",
           "-e", "dns.qry.name", "-e", "tls.handshake.extensions_server_name"]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    pkts = []
    for line in out.splitlines():
        p = line.split("\t")
        p += [""] * (8 - len(p))
        pkts.append(dict(src=p[0], dst=p[1], proto=p[2], sport=p[3], dport=p[4],
                         length=int(p[5] or 0), dns=p[6], sni=p[7]))
    dns_names = {n.lower() for p in pkts for n in p["dns"].split(",") if n}
    sni_names = {n.lower() for p in pkts for n in p["sni"].split(",") if n}
    dst_ips = {p["dst"] for p in pkts if p["src"] == CLIENT}
    rows.append(dict(
        name=name, cfg=cfg, site=site, rep=rep, http_code=code,
        packets=len(pkts), bytes=sum(p["length"] for p in pkts),
        dns_name=int(site.lower() in dns_names),
        sni=int(site.lower() in sni_names),
        dst_ip=int(bool(ip) and ip in dst_ips),
        vpn_signature=vpn_signature(pkts)))

with open(os.path.join(CAP_DIR, "runs.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

def label(r):
    return "visible" if r >= 0.9 else "hidden" if r <= 0.1 else "partial"

matrix = []
for cfg in ORDER:
    ok = [r for r in rows if r["cfg"] == cfg and r["http_code"] != "000"]
    if not ok:
        continue
    n = len(ok)
    sigs = collections.Counter(r["vpn_signature"] for r in ok).most_common(1)[0][0]
    rec = {"config": cfg, "runs": n}
    for k in ("dns_name", "sni", "dst_ip"):
        v = sum(r[k] for r in ok) / n
        rec["r_" + k] = round(v, 2)
        rec[k + "_label"] = label(v)
    rec["vpn_signature"] = sigs
    rec["mean_packets"] = round(sum(r["packets"] for r in ok) / n)
    matrix.append(rec)

with open(os.path.join(CAP_DIR, "matrix.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(matrix[0].keys()))
    w.writeheader(); w.writerows(matrix)

print("config  runs  DNS-name      SNI           dst-IP        VPN seen        pkts")
for m in matrix:
    print(f"{m['config']:<7} {m['runs']:<5} "
          f"{m['r_dns_name']:<4}{m['dns_name_label']:<9} "
          f"{m['r_sni']:<4}{m['sni_label']:<9} "
          f"{m['r_dst_ip']:<4}{m['dst_ip_label']:<9} "
          f"{m['vpn_signature']:<15} {m['mean_packets']}")