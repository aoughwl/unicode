#!/usr/bin/env python3
"""Generate src/aowlunicode/unidata.nim: case mappings and normalization data.

Run with a Python whose unicodedata matches the target Unicode version
(ES2025 / test262 expect Unicode 16):  python3 tools/gen_unidata.py
or from UCD text files of a newer version (test262 now tests Unicode 17):
    python3 tools/gen_unidata.py --ucd DIR 17.0.0
"""
import sys, unicodedata, os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "aowlunicode", "unidata.nim")

def is_surrogate(c):
    return 0xD800 <= c <= 0xDFFF

def read_ucd(d):
    """Tables from the UCD text files in directory `d` (UnicodeData.txt,
    SpecialCasing.txt, DerivedNormalizationProps.txt), for a Unicode version
    newer than this Python's unicodedata."""
    data = {}
    with open(os.path.join(d, "UnicodeData.txt"), encoding="utf-8") as f:
        for ln in f:
            p = ln.rstrip("\n").split(";")
            if len(p) < 15 or p[1].endswith("Last>") or p[1].endswith("First>"):
                continue   # (the ranges carry no mappings or decompositions)
            data[int(p[0], 16)] = p
    special_u, special_l = {}, {}
    with open(os.path.join(d, "SpecialCasing.txt"), encoding="utf-8") as f:
        for ln in f:
            ln = ln.split("#", 1)[0].strip()
            if not ln:
                continue
            p = [x.strip() for x in ln.split(";")]
            if len(p) >= 5 and p[4]:
                continue   # conditional (Final_Sigma, locale): handled in code
            cp = int(p[0], 16)
            special_l[cp] = [int(x, 16) for x in p[1].split()]
            special_u[cp] = [int(x, 16) for x in p[3].split()]
    fce = set()
    with open(os.path.join(d, "DerivedNormalizationProps.txt"), encoding="utf-8") as f:
        for ln in f:
            ln = ln.split("#", 1)[0].strip()
            if not ln:
                continue
            p = [x.strip() for x in ln.split(";")]
            if p[1] != "Full_Composition_Exclusion":
                continue
            if ".." in p[0]:
                a, b = p[0].split("..")
                fce.update(range(int(a, 16), int(b, 16) + 1))
            else:
                fce.add(int(p[0], 16))
    t = dict(upper_simple=[], lower_simple=[], upper_multi=[], lower_multi=[],
             decomp=[], ccc=[], compose=[])
    for c in sorted(data):
        p = data[c]
        up = special_u.get(c) or ([int(p[12], 16)] if p[12] else [c])
        lo = special_l.get(c) or ([int(p[13], 16)] if p[13] else [c])
        if up != [c]:
            if len(up) == 1: t["upper_simple"].append((c, up[0]))
            else: t["upper_multi"].append((c, up))
        if lo != [c]:
            if len(lo) == 1: t["lower_simple"].append((c, lo[0]))
            else: t["lower_multi"].append((c, lo))
        if p[5]:
            parts = p[5].split()
            compat = 0
            if parts[0].startswith("<"):
                compat = 1
                parts = parts[1:]
            ps = [int(x, 16) for x in parts]
            t["decomp"].append((c, compat, ps))
            if compat == 0 and len(ps) == 2 and c not in fce:
                t["compose"].append((ps[0], ps[1], c))
        if int(p[3]):
            t["ccc"].append((c, int(p[3])))
    return t

def main():
    upper_simple, lower_simple = [], []     # (from, to)
    upper_multi, lower_multi = [], []       # (from, [to...])
    decomp = []                             # (cp, compat(0/1), [parts])
    ccc = []                                # (cp, class)
    compose = []                            # (a, b, c)
    version = unicodedata.unidata_version
    if len(sys.argv) > 2 and sys.argv[1] == "--ucd":
        t = read_ucd(sys.argv[2])
        upper_simple, lower_simple = t["upper_simple"], t["lower_simple"]
        upper_multi, lower_multi = t["upper_multi"], t["lower_multi"]
        decomp, ccc, compose = t["decomp"], t["ccc"], t["compose"]
        version = sys.argv[3] if len(sys.argv) > 3 else "(UCD files)"
    for c in (range(0x110000) if len(sys.argv) <= 2 else []):
        if is_surrogate(c):
            continue
        ch = chr(c)
        u = ch.upper()
        if u != ch:
            if len(u) == 1:
                upper_simple.append((c, ord(u)))
            else:
                upper_multi.append((c, [ord(x) for x in u]))
        l = ch.lower()
        if l != ch:
            if len(l) == 1:
                lower_simple.append((c, ord(l)))
            else:
                lower_multi.append((c, [ord(x) for x in l]))
        d = unicodedata.decomposition(ch)
        if d:
            parts = d.split()
            compat = 0
            if parts[0].startswith("<"):
                compat = 1
                parts = parts[1:]
            decomp.append((c, compat, [int(p, 16) for p in parts]))
            if compat == 0 and len(parts) == 2:
                a, b = int(parts[0], 16), int(parts[1], 16)
                if unicodedata.normalize("NFC", chr(a) + chr(b)) == ch:
                    compose.append((a, b, c))
        k = unicodedata.combining(ch)
        if k:
            ccc.append((c, k))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("## Generated by tools/gen_unidata.py from Unicode %s. Do not edit.\n\n" % version)
        def flat_pairs(name, pairs):
            f.write("const %s* = [\n" % name)
            line = "  "
            for a, b in pairs:
                item = "%d'i32, %d'i32, " % (a, b)
                if len(line) + len(item) > 100:
                    f.write(line.rstrip() + "\n")
                    line = "  "
                line += item
            f.write(line.rstrip().rstrip(",") + "]\n\n")
        def flat_multi(name, rows):
            # cp, n, parts...
            f.write("const %s* = [\n" % name)
            line = "  "
            for cp, parts in rows:
                item = "%d'i32, %d'i32, " % (cp, len(parts)) + "".join("%d'i32, " % p for p in parts)
                if len(line) + len(item) > 100:
                    f.write(line.rstrip() + "\n")
                    line = "  "
                line += item
            f.write(line.rstrip().rstrip(",") + "]\n\n")
        flat_pairs("upperSimple", upper_simple)
        flat_pairs("lowerSimple", lower_simple)
        flat_multi("upperMulti", upper_multi)
        flat_multi("lowerMulti", lower_multi)
        flat_pairs("combiningClass", ccc)
        f.write("const decompData* = [\n")
        line = "  "
        for cp, compat, parts in decomp:
            item = "%d'i32, %d'i32, %d'i32, " % (cp, compat, len(parts)) + "".join("%d'i32, " % p for p in parts)
            if len(line) + len(item) > 100:
                f.write(line.rstrip() + "\n")
                line = "  "
            line += item
        f.write(line.rstrip().rstrip(",") + "]\n\n")
        f.write("const composeData* = [\n")
        line = "  "
        for a, b, c in compose:
            item = "%d'i32, %d'i32, %d'i32, " % (a, b, c)
            if len(line) + len(item) > 100:
                f.write(line.rstrip() + "\n")
                line = "  "
            line += item
        f.write(line.rstrip().rstrip(",") + "]\n")
    print("upper %d+%d lower %d+%d decomp %d ccc %d compose %d" % (
        len(upper_simple), len(upper_multi), len(lower_simple), len(lower_multi),
        len(decomp), len(ccc), len(compose)))

main()
