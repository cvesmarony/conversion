#!/usr/bin/env python3
"""List the cells, areas and pins (with bus widths) of a liberty (.lib) file.

usage: sram_info.py <file.lib> [substring-of-cell-name]
Pure python, no awk/grep tricks:   python3 scripts/sram_info.py $LIB 512X45
"""
import re, sys

def block_end(t, i):
    """index just past the '}' matching the '{' at t[i]"""
    d = 0
    for j in range(i, len(t)):
        c = t[j]
        if c == "{":
            d += 1
        elif c == "}":
            d -= 1
            if d == 0:
                return j + 1
    return len(t)

txt = re.sub(r"/\*.*?\*/", "", open(sys.argv[1], errors="replace").read(), flags=re.S)
flt = sys.argv[2] if len(sys.argv) > 2 else ""

# bus types -> bit width
widths = {}
for m in re.finditer(r'\btype\s*\(\s*"?([^")\s]+)"?\s*\)\s*\{', txt):
    b = txt[m.end():block_end(txt, m.end() - 1)]
    w = re.search(r'\bbit_width\s*:\s*(\d+)', b)
    if w:
        widths[m[1]] = int(w[1])

for m in re.finditer(r'\bcell\s*\(\s*"?([^")\s]+)"?\s*\)\s*\{', txt):
    name = m[1]
    if flt and flt not in name:
        continue
    blk = txt[m.end():block_end(txt, m.end() - 1)]
    a = re.search(r'\barea\s*:\s*([\d.eE+-]+)', blk)
    print(f"{name}   area={a[1] if a else '?'}")
    if not flt:
        continue
    seen = set()
    for p in re.finditer(r'\b(pin|bus)\s*\(\s*"?([^")\s]+)"?\s*\)\s*\{', blk):
        pn = p[2]
        if "[" in pn or pn in seen:
            continue
        seen.add(pn)
        pb = blk[p.end():block_end(blk, p.end() - 1)]
        d = re.search(r'\bdirection\s*:\s*"?(\w+)', pb)
        bt = re.search(r'\bbus_type\s*:\s*"?([^";\s]+)', pb)
        w = widths.get(bt[1], "?") if bt else 1
        print(f"    {pn:10s} {d[1] if d else '?':8s} width={w}")
