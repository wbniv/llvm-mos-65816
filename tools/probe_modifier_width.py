#!/usr/bin/env python3
"""Sweep llvm-mc over modifier x operand-width combinations and record encodings.

Driven by dev/probe-modifier-width.sh; see that script for usage. The point is
to make a parser width change *measurable*: run the sweep against the pre-fix
assembler, run it again against the fixed one, and diff. Every row whose
encoding changed is a row the change is responsible for -- no prediction, no
"this should be fine".

Each probe is a single instruction assembled on its own, with -show-encoding so
the selected opcode is visible even when no relocation is emitted (a constant
operand emits no fixup at all, which is precisely how the truncation defect
stays silent).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

# (cpu, extra llvm-mc flags)
CPUS = [
    ("mos6502", []),
    ("mos65c02", []),
    ("mosw65816", []),
    ("mosspc700", []),
    ("moshuc6280", []),
    ("mos45gs02", []),
    ("mos65ce02", []),
    ("mos65el02", []),
]

# Instruction shapes: "%s" is replaced by the operand text. Each shape names the
# operand classes the matcher will try, so a diff row can be read back to a
# concrete candidate (Addr8 vs Addr16 vs Addr24 vs Imm8 ...).
SHAPES = [
    ("abs/zp", "lda %s"),
    ("abs,x/zp,x", "lda %s,x"),
    ("abs,y", "lda %s,y"),
    ("sta abs/zp", "sta %s"),
    ("sta abs,x/zp,x", "sta %s,x"),
    ("jmp abs", "jmp %s"),
    ("(zp),y", "lda (%s),y"),
    ("(zp,x)", "lda (%s,x)"),
    ("imm", "lda #%s"),
    ("cmp abs/zp", "cmp %s"),
]

# SPC700 and bit-operand shapes are probed separately: their mnemonics differ.
SPC700_SHAPES = [
    ("spc mov a,abs/dp", "mov a, %s"),
    ("spc mov abs/dp,a", "mov %s, a"),
    ("spc imm", "mov a, #%s"),
]

MODIFIERS = [
    "",  # bare operand, the control
    "mos8",
    "mos16",
    "mos24",
    "mos16lo",
    "mos16hi",
    "mos24bank",
    "mos24segment",
    "mos24segmentlo",
    "mos24segmenthi",
    "mos13",
]

# Values chosen to straddle every width boundary the parser cares about.
VALUES = ["0", "1", "7", "15", "16", "240", "255", "256", "4660", "65535",
          "65536", "1193046", "-1"]

# Symbolic probes: the modifier wraps a symbol instead of a constant, which
# takes the other branch of isImmInRange. Included so a change to the constant
# branch can be shown NOT to move them.
SYMBOLS = ["defsym", "extsym"]

PRELUDE = (
    ".text\n"
    "defsym = 240\n"
    ".globl extsym\n"
)


def operand(mod: str, val: str) -> str:
    return val if not mod else f"{mod}({val})"


def probes():
    for cpu, flags in CPUS:
        shapes = SPC700_SHAPES if cpu == "mosspc700" else SHAPES
        for shape_name, shape in shapes:
            for mod in MODIFIERS:
                for val in VALUES + SYMBOLS:
                    yield {
                        "cpu": cpu,
                        "flags": flags,
                        "shape": shape_name,
                        "input": shape % operand(mod, val),
                        "modifier": mod or "(none)",
                        "value": val,
                    }


def run_one(mc: str, p: dict) -> dict:
    src = PRELUDE + p["input"] + "\n"
    r = subprocess.run(
        [mc, "-triple", "mos", f"-mcpu={p['cpu']}", "-show-encoding", *p["flags"]],
        input=src, capture_output=True, text=True,
    )
    out = ""
    for line in r.stdout.splitlines():
        if "encoding:" in line:
            out = " ".join(line.split())
    err = ""
    if r.returncode != 0:
        # Keep only the diagnostic itself; paths and carets add noise.
        for line in r.stderr.splitlines():
            if "error:" in line:
                err = line.split("error:", 1)[1].strip()
                break
        else:
            err = r.stderr.strip().splitlines()[0] if r.stderr.strip() else "rc!=0"
    rec = dict(p)
    rec.pop("flags", None)
    rec["rc"] = r.returncode
    rec["encoding"] = out
    rec["error"] = err
    return rec


def key(rec: dict) -> tuple:
    return (rec["cpu"], rec["shape"], rec["modifier"], rec["value"])


def sweep(mc: str, out_path: str) -> int:
    all_probes = list(probes())
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(lambda p: run_one(mc, p), all_probes))
    rows.sort(key=key)
    with open(out_path, "w") as f:
        json.dump({"llvm_mc": mc, "count": len(rows), "probes": rows}, f, indent=1)
    ok = sum(1 for r in rows if r["rc"] == 0)
    print(f"{len(rows)} probes -> {out_path}  ({ok} assembled, {len(rows) - ok} rejected)")
    return 0


def diff(a_path: str, b_path: str) -> int:
    a = {key(r): r for r in json.load(open(a_path))["probes"]}
    b = {key(r): r for r in json.load(open(b_path))["probes"]}
    assert set(a) == set(b), "probe sets differ; regenerate both sweeps"
    changed = [k for k in sorted(a) if
               (a[k]["encoding"], a[k]["rc"]) != (b[k]["encoding"], b[k]["rc"])]
    print(f"{len(a)} probes, {len(changed)} changed\n")
    for k in changed:
        ra, rb = a[k], b[k]
        before = ra["encoding"] or f"REJECTED: {ra['error']}"
        after = rb["encoding"] or f"REJECTED: {rb['error']}"
        print(f"{k[0]:<11} {k[1]:<16} {ra['input']}")
        print(f"    before: {before}")
        print(f"    after:  {after}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mc")
    ap.add_argument("--out")
    ap.add_argument("--diff", nargs=2, metavar=("BASELINE", "FIXED"))
    args = ap.parse_args()
    if args.diff:
        return diff(*args.diff)
    if not args.mc or not args.out:
        ap.error("--mc and --out are required unless --diff is given")
    return sweep(args.mc, args.out)


if __name__ == "__main__":
    sys.exit(main())
