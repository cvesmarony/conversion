#!/usr/bin/env python3
"""Collect Genus report numbers into results/summary.csv.

usage: parse_reports.py <reports_dir> KEY=VAL ...
Report formats differ slightly between Genus versions; check the first run
against the raw reports in <run_dir>/reports and tweak the regexes if needed.
Missing values are written as NA.
"""
import csv, os, re, sys

rep = sys.argv[1]
meta = dict(a.split("=", 1) for a in sys.argv[2:])


def read(name):
    p = os.path.join(rep, name)
    return open(p, errors="replace").read() if os.path.exists(p) else ""


# ---- area ------------------------------------------------------------------
# rows: instance  module  cell_count  cell_area  net_area  total_area ...
area_txt = read("area.rpt")
rows = []
in_table = False
for line in area_txt.splitlines():
    if "Cell Count" in line:
        in_table = True
        continue
    if not in_table:
        continue
    # the module column is absent on some rows (e.g. the top), so make it optional
    m = re.match(r"^\s*(\S+)(?:\s+(\S+))?\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", line)
    if m:
        rows.append(dict(inst=m[1], mod=m[2] or "", cells=int(m[3]), total=float(m[6])))

total = rows[0]["total"] if rows else None
cells = rows[0]["cells"] if rows else None
banks = [r for r in rows[1:] if "bank" in r["inst"].lower() or r["mod"].startswith("TTable")]
tables = sum(r["total"] for r in banks) if rows else None
logic = (total - tables) if rows else None

# ---- timing ----------------------------------------------------------------
t_txt = read("timing.rpt")
slack_ps = None
m = re.search(r"Path 1:\s*(?:MET|VIOLATED)\s*\((-?[\d.]+)\s*ps\)", t_txt)
if m:
    slack_ps = float(m[1])
else:
    m = re.search(r"Slack:=\s*(-?[\d.]+)", t_txt)
    if m:
        slack_ps = float(m[1])  # Genus normally prints ps; verify on first run
CLK = float(meta.get("CLK_PERIOD", "nan"))
slack_ns = slack_ps / 1000.0 if slack_ps is not None else None
achieved = (CLK - slack_ns) if slack_ns is not None else None
fmax = (1000.0 / achieved) if achieved and achieved > 0 else None

# ---- power (default activity: use read_tcf/read_vcd for real numbers) -------
p_txt = read("power.rpt")
power_mw = None
for m in re.finditer(r"^\s*Total\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)",
                     p_txt, re.M):
    power_mw = float(m[4]) * 1e3  # W -> mW (Genus default power unit is W)

# ---- derived ---------------------------------------------------------------
n = int(meta["SHARES"]); w = int(meta["H_WIDTH"]); q = int(meta["Q"])
domain = q if meta["MODE"] == "A2B" else 2 ** w
mem_bits = 2 * domain * n * w
cycles = (n - 1) * (domain + 1) + domain + 3   # confirm against simulation
latency_us = cycles * achieved / 1000.0 if achieved else None


def fmt(v, p=3):
    return "NA" if v is None else (f"{v:.{p}f}" if isinstance(v, float) else str(v))


header = ["mode", "shares", "h_width", "q", "ttable", "CLK_ns", "slack_ns", "achieved_ns",
          "fmax_mhz", "area_total", "area_tables", "area_logic", "cells", "power_mw",
          "table_bits", "est_cycles", "est_latency_us"]
row = [meta["MODE"], n, w, q, meta.get("TTABLE", ""), fmt(CLK), fmt(slack_ns), fmt(achieved),
       fmt(fmax, 1), fmt(total, 1), fmt(tables, 1), fmt(logic, 1), fmt(cells), fmt(power_mw),
       mem_bits, cycles, fmt(latency_us, 1)]

os.makedirs("results", exist_ok=True)
path = "results/summary.csv"
new = not os.path.exists(path)
with open(path, "a", newline="") as f:
    wr = csv.writer(f, lineterminator="\n")
    if new:
        wr.writerow(header)
    wr.writerow(row)
print("  ".join(f"{h}={v}" for h, v in zip(header, row)))
