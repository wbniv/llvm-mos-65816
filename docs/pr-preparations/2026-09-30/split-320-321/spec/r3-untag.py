#!/usr/bin/env python3
"""Rewrite the #321 history tags in MOS comments to plain prose (review N4).

usage: r3-untag.py REPO_DIR
Edits llvm/lib/Target/MOS/* in place. Every rule is an exact phrase that only
the #321 commits added, so upstream lines are never touched. Prints the number
of replacements per rule; a rule that never fires on the #321 top is a bug.
"""
import pathlib, re, sys

RULES = [
    (r"(//\s*)#321 native ", r"\1Native "),
    (r"#321 SPILL CONTRACT \(", "Spill contract ("),
    (r"#321 `g == 0x1234`: fold", "For `g == 0x1234`, fold"),
    (r"#321 RHS-indexed compare fold:", "RHS-indexed compare fold:"),
    (r"#321 canonicalization:", "Canonicalization:"),
    (r"#321 seed 247/445: a 16-bit value", "A 16-bit value"),
    (r"#321 xy16 B1 gate: return true", "XY16 load gate: return true"),
    (r"#321 a16 register-pressure relief: under", "A16 register-pressure relief: under"),
    (r"// B1: under \+mos-xy16", "// Under +mos-xy16"),
    (r"// B2: set when", "// Set when"),
    (r"// B2: under \+mos-xy16", "// Under +mos-xy16"),
    (r"// B2: direct s16 offset", "// A direct s16 offset"),
    (r"XLow=1: our new 16-bit X/Y pseudos", "XLow=1: the 16-bit X/Y pseudos"),
    (r"The original Increment-1a behavior: each block", "Legacy placement: each block"),
    (r"insertion pass \(#321 — 16-bit register", "insertion pass (16-bit register"),
    (r"// \(#321\), whose operand", "// whose operand"),
    (r"indexed 16-bit load/store \(Native widths: \)\.", "indexed 16-bit load/store."),
    # Mid-sentence remnants of the earlier mechanical "Native widths:" relabel.
    (r"the Native widths: 16-bit abs-fold", "the 16-bit abs-fold"),
    (r"the Native widths: EQ abs-fold operand", "the EQ abs-fold operand"),
    (r"Native widths: computed-vs-global:", "Computed-vs-global:"),
]

def main():
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip()); sys.exit(0 if len(sys.argv) == 2 else 2)
    root = pathlib.Path(sys.argv[1]) / "llvm/lib/Target/MOS"
    counts = [0] * len(RULES)
    for p in sorted(root.rglob("*")):
        if p.suffix not in (".cpp", ".h", ".td") or not p.is_file():
            continue
        s = p.read_text()
        t = s
        for i, (pat, rep) in enumerate(RULES):
            t, n = re.subn(pat, rep, t)
            counts[i] += n
        if t != s:
            p.write_text(t)
    for (pat, _), n in zip(RULES, counts):
        print(f"{n}\t{pat}")

main()
