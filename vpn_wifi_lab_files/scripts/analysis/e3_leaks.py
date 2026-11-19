#!/usr/bin/env python3
"""Counts client packets sent to anything other than the VPN server (= leaked)."""
import glob, os, subprocess, sys
FILT = ("ip.src==10.10.0.10 && !(ip.dst==10.20.0.2) && !(ip.dst==255.255.255.255) "
        "&& !(ip.dst==10.10.0.0/24)")
for f in sorted(glob.glob(sys.argv[1] + "/*.pcap")):
    cfg = os.path.basename(f)[:-5]
    out = subprocess.run(["tshark", "-r", f, "-Y", FILT, "-T", "fields",
                          "-e", "frame.time_epoch", "-e", "ip.dst"],
                         capture_output=True, text=True).stdout.splitlines()
    rows = [l.split("\t") for l in out if l]
    ts = [float(r[0]) for r in rows]
    dst = sorted({r[1] for r in rows})
    print(f"{cfg},{len(ts)},{(max(ts) - min(ts)) if ts else 0:.2f},{' '.join(dst)}")