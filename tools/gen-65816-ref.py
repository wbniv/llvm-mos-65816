#!/usr/bin/env python3
# tools/gen-65816-ref.py — generate the compact 65816 instruction reference
# (docs/refs/65816/65816-reference.md) FROM the llvm-mos backend's own TableGen
# description, and AUDIT that description against the canonical CC0 opcode matrix
# (docs/refs/65816/65816-opcode-audit.md).
#
# Why from TableGen: the reference then describes exactly what *this* toolchain
# assembles/emits, so it can never drift from the compiler. Why audit against an
# independent oracle: a TableGen-vs-canonical mismatch is a candidate backend bug,
# not just a doc typo — the project's differential-gate philosophy applied to the
# instruction set.
#
# Pipeline:
#   1. llvm-tblgen --dump-json on the MOS target -> every instruction record
#      (opcode bits, AsmString, Size, feature predicates).
#   2. Keep real machine instructions (not pseudo / not codegen-only); the MOS
#      backend covers many 65xx variants, so the canonical 65816 oracle selects,
#      per opcode, which variant is the 65816 one (match by mnemonic).
#   3. Emit the reference (16-bit / native-mode focus) + the per-opcode audit.
#
#   LLVM_TBLGEN=.../llvm-tblgen MOS_TD=.../MOS.td \
#     tools/gen-65816-ref.py --emit reference > docs/refs/65816/65816-reference.md
#   ... --emit audit > docs/refs/65816/65816-opcode-audit.md
#
# --json <file> reuses a cached `llvm-tblgen --dump-json` dump instead of running it.
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Feature predicates that hold on the WDC 65816 (mosw65816). Used only to PREFER /
# annotate; the oracle is what actually selects the 65816 instruction per opcode.
PRED_65816 = {"Has6502", "Has65C02", "HasW65C02", "HasW65816", "HasW65816Or65EL02"}

# Datasheet-vs-modern mnemonic synonyms (same opcode, different spelling).
SYN = [{"JMP", "JML"}, {"JSR", "JSL"}]

# TableGen record-name suffix  ->  canonical assembler addressing-mode notation.
MODE = {
    "Implied": "i", "Implicit": "i", "Accumulator": "A",
    "Immediate": "#", "Immediate16": "#", "ImmediateA": "#", "ImmediateIndex": "#",
    "ZeroPage": "dp", "ZeroPageX": "dp,X", "ZeroPageY": "dp,Y",
    "Absolute": "abs", "AbsoluteX": "abs,X", "AbsoluteY": "abs,Y",
    "AbsoluteLong": "long", "AbsoluteLongX": "long,X", "AbsoluteXLong": "long,X",
    "Indirect": "(dp)", "ZeroPageIndirect": "(dp)",
    "IndexedIndirect": "(dp,X)", "IndirectIndexed": "(dp),Y",
    "IndirectLong": "[dp]", "IndirectLongIndexed": "[dp],Y",
    "StackRelative": "sr,S", "StackRelativeIndirectIndexed": "(sr,S),Y",
    "Relative": "rel", "RelativeLong": "rlong", "Relative16": "rlong",
    "Indirect16": "(abs)", "AbsoluteIndirect": "(abs)",
    "AbsoluteIndexedIndirect": "(abs,X)", "AbsoluteIndirectLong": "[abs]",
    "IndexedIndirect16": "(abs,X)", "IndirectIndexedLong": "[dp],Y",
    "IndirectStackRelativeY": "(sr,S),Y", "816MemoryMove": "src,dst",
    "Stack": "s",
}

PREAMBLE = """\
This is a **compact, 16-bit-focused** 65816 reference: the processor model needed
to drive `+mos-a16` codegen (native mode, the M/X width flags, and how you move
between 8- and 16-bit A / X / Y), followed by the full instruction set. Per-instruction
8-bit-only minutiae (cycle-by-cycle timing, emulation-mode quirks) are deliberately
omitted — see the canonical sources for those.

It is **generated from the llvm-mos backend's own TableGen** (so it matches the
assembler/codegen you actually run) and every opcode is **cross-checked against a
canonical opcode matrix**; the result of that check is the companion
[opcode audit](65816-opcode-audit.md).

## Processor model

The 65816 powers up in **6502 emulation mode** (E = 1). The SNES `crt0` switches to
**native mode** once, with `CLC; XCE` (exchange Carry into the E flag). In native mode
two status-register bits set operand width independently:

| Flag | Bit | 0 ⇒ | 1 ⇒ |
|------|-----|-----|-----|
| **M** | 5 | 16-bit accumulator / memory | 8-bit accumulator / memory |
| **X** | 4 | 16-bit index (X, Y) | 8-bit index (X, Y) |

`+mos-a16` runs with **M = 0** (16-bit accumulator). Width is changed with **REP**
(reset P bits) and **SEP** (set P bits):

| Want | Instruction |
|------|-------------|
| 16-bit A | `REP #$20` |
| 16-bit X/Y | `REP #$10` |
| 16-bit A + X/Y | `REP #$30` |
| 8-bit A | `SEP #$20` |
| 8-bit X/Y | `SEP #$10` |

**The width gotcha:** an immediate operand's size (and how many bytes the instruction
occupies) follows the M/X flag *as seen by the assembler at that point*. `LDA #$1234`
is a 3-byte instruction when M = 0 but `LDA #$12` is 2 bytes when M = 1 — so REP/SEP
placement and the assembler's tracking of M/X must agree, or the operand bytes shear.
Accumulator/memory instructions (ADC, AND, CMP, EOR, LDA, ORA, SBC, BIT, …) follow
**M**; index instructions (LDX, LDY, CPX, CPY) follow **X**. Setting X = 1 zeroes the
high bytes of X and Y. `XBA` swaps the two halves of A; `TCD/TDC/TCS/TSC` move the full
16 bits regardless of M.

In the tables below, **Bytes** is the instruction length the backend encodes; for the
M/X-width immediates it is the 8-bit form (add 1 when the governing flag selects 16-bit).
"""


def find_tblgen() -> str:
    env = os.environ.get("LLVM_TBLGEN")
    if env:
        return env
    for c in ("build/llvm-mos/bin/llvm-tblgen", "build/llvm-mos-asserts/bin/llvm-tblgen"):
        p = ROOT / c
        if p.exists():
            return str(p)
    sys.exit("llvm-tblgen not found; set LLVM_TBLGEN or run: dev/run.sh toolchain")


def load_json(args) -> dict:
    if args.json:
        return json.loads(Path(args.json).read_text())
    td = os.environ.get("MOS_TD") or str(ROOT / "vendor/llvm-mos/llvm/lib/Target/MOS/MOS.td")
    td = Path(td)
    if not td.exists():
        sys.exit(f"MOS.td not found at {td}; set MOS_TD")
    incs = [str(td.parent), str(td.parents[3] / "include")]  # .../MOS and llvm/include
    cmd = [find_tblgen(), "--dump-json"]
    for i in incs:
        cmd += ["-I", i]
    cmd.append(str(td))
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"llvm-tblgen failed:\n{out.stderr[-2000:]}")
    return json.loads(out.stdout)


def opcode_of(rec: dict):
    inst = rec.get("Inst")
    if not isinstance(inst, list) or len(inst) < 8:
        return None
    b = inst[:8]
    if not all(isinstance(x, int) for x in b):
        return None
    return sum(v << i for i, v in enumerate(b))   # Inst[0] = bit 0


def preds_of(rec: dict) -> set:
    return {p.get("def") for p in (rec.get("Predicates") or []) if isinstance(p, dict)}


def mnem_eq(a: str, b: str) -> bool:
    if a == b:
        return True
    return any(a in s and b in s for s in SYN)


def parse_tablegen(j: dict) -> dict:
    """opcode -> list of {name, mnem, mode, size, preds, is816}."""
    by_op: dict[int, list] = {}
    for n in j["!instanceof"]["Instruction"]:
        r = j[n]
        if r.get("isPseudo") or r.get("isCodeGenOnly"):
            continue
        op = opcode_of(r)
        if op is None:
            continue
        asm = (r.get("AsmString") or "").split()
        if not asm:
            continue
        mnem = asm[0].upper()
        if len(mnem) != 3 or not mnem.isalpha():
            continue                                  # skip SPC700 'or','mov', etc.
        suffix = n.split("_", 1)[1] if "_" in n else ""
        preds = preds_of(r)
        by_op.setdefault(op, []).append({
            "name": n, "mnem": mnem, "suffix": suffix,
            "size": r.get("Size"), "preds": preds,
            "is816": bool(preds) and preds <= PRED_65816,
        })
    return by_op


def load_oracle(path: Path) -> dict:
    o = {}
    for ln in path.read_text().splitlines():
        if ln.startswith("#") or not ln.strip():
            continue
        op, mnem, mode, nbytes = ln.split("\t")
        o[int(op, 16)] = {"mnem": mnem, "mode": mode, "bytes": int(nbytes)}
    return o


def mode_name(suffix: str, oracle_mode: str) -> str:
    return MODE.get(suffix, oracle_mode or suffix or "i")


def reconcile(by_op: dict, oracle: dict):
    """Return per-opcode records: {op, oracle, chosen, cands, verdict}."""
    rows = []
    unmapped = set()
    for op in range(256):
        o = oracle.get(op)
        cands = by_op.get(op, [])
        if o is None:                                  # reserved in canon (e.g. WDM $42)
            extra = [c for c in cands if c["is816"]]
            rows.append({"op": op, "oracle": None, "chosen": None,
                         "cands": cands, "extra816": extra})
            continue
        matches = [c for c in cands if mnem_eq(c["mnem"], o["mnem"])]
        matches.sort(key=lambda c: (not c["is816"], c["suffix"]))   # prefer 65816-gated
        chosen = matches[0] if matches else None
        if chosen and chosen["suffix"] and chosen["suffix"] not in MODE:
            unmapped.add(chosen["suffix"])
        rows.append({"op": op, "oracle": o, "chosen": chosen, "cands": cands})
    return rows, unmapped


def classify(row: dict) -> str:
    o, c = row["oracle"], row["chosen"]
    if o is None:
        return "reserved"
    if c is None:
        return "missing"
    if c["mnem"] != o["mnem"]:
        return "synonym"          # matched only via SYN
    if c["size"] == o["bytes"]:
        return "ok"
    # size differs: immediates carry an M/X-width +1; BRK/COP have a signature byte
    if abs((c["size"] or 0) - o["bytes"]) == 1 and (o["mode"] == "#" or o["mnem"] in ("BRK", "COP")):
        return "width"
    return "size"


def emit_reference(rows: list) -> str:
    out = ["<!-- generated by tools/gen-65816-ref.py --emit reference — DO NOT EDIT. -->",
           "<!-- Source: llvm-mos backend TableGen; verified vs the CC0 canonical matrix",
           "     (docs/refs/65816/SOURCES.md). Regenerate: see the Taskfile gen-docs task. -->",
           "", "# 65816 — compact reference", "", PREAMBLE, "",
           "## Instruction set", "",
           "Generated from the backend; opcode, mnemonic and byte length are the backend's, "
           "addressing-mode notation is canonical. Sorted by mnemonic. "
           "(`i` implied, `A` accumulator, `#` immediate, `dp` direct page, `abs` absolute, "
           "`long` absolute-long, `(…)`/`[…]` indirect/indirect-long, `,X`/`,Y`/`,S` indexed, "
           "`rel`/`rlong` branch.)", "",
           "| Mnemonic | Mode | Opcode | Bytes |",
           "|----------|------|--------|-------|"]
    items = []
    for r in rows:
        c, o = r["chosen"], r["oracle"]
        if not c or not o:
            continue
        items.append((c["mnem"], mode_name(c["suffix"], o["mode"]), r["op"], c["size"]))
    for mnem, mode, op, size in sorted(items, key=lambda t: (t[0], t[2])):
        out.append(f"| `{mnem}` | `{mode}` | `${op:02X}` | {size} |")
    out.append("")
    out.append(f"*{len(items)} opcodes. Cross-checked against the canonical matrix — "
               "see the [opcode audit](65816-opcode-audit.md).*")
    return "\n".join(out) + "\n"


def emit_audit(rows: list) -> str:
    buckets = {"ok": 0, "width": 0, "synonym": 0, "size": 0, "missing": 0, "reserved": 0}
    detail = []
    for r in rows:
        v = classify(r)
        buckets[v] += 1
        if v in ("size", "missing", "synonym", "width"):
            detail.append((r, v))
    out = ["<!-- generated by tools/gen-65816-ref.py --emit audit — DO NOT EDIT. -->",
           "", "# 65816 backend opcode audit", "",
           "Audits the **llvm-mos backend's** 65816 instruction encodings (from its TableGen) "
           "against an independent **canonical opcode matrix** (CC0; see "
           "[SOURCES.md](SOURCES.md)). A mismatch is a candidate backend defect. "
           "Generated by `tools/gen-65816-ref.py`.", "",
           "## Summary", "",
           "| Result | Opcodes |",
           "|--------|---------|",
           f"| ✓ exact agreement (mnemonic + bytes) | {buckets['ok']} |",
           f"| ≈ byte-count differs by the expected width/signature rule | {buckets['width']} |",
           f"| ~ mnemonic synonym (e.g. JMP-long ≡ JML) | {buckets['synonym']} |",
           f"| ⚠ unexplained byte-count mismatch | {buckets['size']} |",
           f"| ✗ canonical opcode absent from the backend | {buckets['missing']} |",
           f"| — reserved in canon (WDM etc.) | {buckets['reserved']} |",
           "",
           f"**{buckets['ok'] + buckets['width'] + buckets['synonym']} / "
           f"{sum(v for k, v in buckets.items() if k != 'reserved')} defined opcodes agree** "
           "(exact, width-rule, or synonym). "
           + ("**No unexplained discrepancies.**" if buckets["size"] == 0 and buckets["missing"] == 0
              else "**See discrepancies below.**"), ""]
    if detail:
        out += ["## Notable rows", "",
                "| Opcode | Canonical | Backend | Note |",
                "|--------|-----------|---------|------|"]
        sym = {"width": "≈", "synonym": "~", "size": "⚠", "missing": "✗"}
        for r, v in sorted(detail, key=lambda t: t[0]["op"]):
            o = r["oracle"]; c = r["chosen"]
            can = f"`{o['mnem']} {o['mode']}` / {o['bytes']}B" if o else "—"
            bk = (f"`{c['mnem']}` `{c['suffix'] or 'i'}` / {c['size']}B" if c
                  else "*(none)*")
            note = {"width": "M/X-width or signature byte (expected)",
                    "synonym": "datasheet vs modern spelling",
                    "size": "byte-count mismatch — investigate",
                    "missing": "backend has no matching mnemonic at this opcode"}[v]
            out.append(f"| `${r['op']:02X}` {sym[v]} | {can} | {bk} | {note} |")
        out.append("")
    # reverse check: definitely-65816 backend ops landing on a canon-reserved opcode
    extras = [r for r in rows if r["oracle"] is None and r.get("extra816")]
    if extras:
        out += ["## Backend instructions at canon-reserved opcodes", "",
                "| Opcode | Backend | Note |", "|--------|---------|------|"]
        for r in extras:
            names = ", ".join(f"`{c['mnem']}`" for c in r["extra816"])
            out.append(f"| `${r['op']:02X}` | {names} | reserved in the datasheet matrix |")
        out.append("")
    return "\n".join(out) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate the 65816 reference / opcode audit from TableGen")
    ap.add_argument("--emit", choices=("reference", "audit"), required=True)
    ap.add_argument("--oracle", type=Path,
                    default=ROOT / "docs/refs/65816/oracle-65c816-opcodes.tsv")
    ap.add_argument("--json", help="cached `llvm-tblgen --dump-json` output (skip running tblgen)")
    args = ap.parse_args()

    j = load_json(args)
    by_op = parse_tablegen(j)
    oracle = load_oracle(args.oracle)
    rows, unmapped = reconcile(by_op, oracle)
    if unmapped:
        print("note: unmapped addressing-mode suffixes (using oracle notation): "
              + ", ".join(sorted(unmapped)), file=sys.stderr)
    sys.stdout.write(emit_reference(rows) if args.emit == "reference" else emit_audit(rows))


if __name__ == "__main__":
    main()
