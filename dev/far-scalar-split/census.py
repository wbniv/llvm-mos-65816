#!/usr/bin/env python3
"""census.py -- count byte-split far 16-bit scalar accesses in `llvm-objdump -d[r]` output.

Usage: llvm-objdump -dr X.o | census.py LABEL      (relocatable: symbol+offset from R_MOS_ADDR24)
       llvm-objdump -d  X.elf | census.py LABEL    (linked: 24-bit address from the operand bytes)
       census.py -h | --help

A byte-split far s16 access is two 8-bit accesses of the same kind to ADJACENT far bytes inside
one function, within a short window (WIN instructions):
  abs-long   : `af A` ... `af A+1`          (load)   /  `8f A` ... `8f A+1`          (store)
  [dp]       : `a7 d` ... `b7 d`            (load)   /  `87 d` ... `97 d`            (store)
               (the `ldy #1` is hoisted, often through a branchy carry idiom, so Y is not checked;
               the compiler emits b7/97 only for the constant-displacement [dp],Y fold)
Each load pair is further classified by what consumes the two bytes:
  imag16 : both bytes go straight to DP (`sta zp`) and a `rep #$20` follows within 4 instrs, i.e.
           the value is reassembled in an Imag16 pair and read back by a native 16-bit op -- the
           shape a single M=0 load would replace outright (the `x ^ fg` finding).
  dp     : both bytes go straight to DP but no 16-bit consumer follows (byte-consumed / spilled).
  reg    : at least one byte stays register-resident (`tax`/`tay`/`xba`/...) -- the A:X return /
           argument convention; a native M=0 load does NOT obviously win here (lesson 2).
Output: one line per hit: LABEL FUNC KIND CLASS ADDR
Known false positive: two genuinely separate byte-wide far objects laid out adjacently and read
back to back (e.g. a far struct {uint8_t a, b;}). The doc lists and hand-checks every hit.
"""
import re
import sys

WIN = 8

if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
    print(__doc__)
    sys.exit(0)
label = sys.argv[1] if len(sys.argv) > 1 else "-"

fn_re = re.compile(r"^[0-9a-f]+ <([^>]+)>:")
ins_re = re.compile(r"^\s+([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*(\S+)\s*([^;]*)")
rel_re = re.compile(r"R_MOS_(ADDR24|ADDR8)\s+(\S+)")

funcs = {}
cur = None
for line in sys.stdin:
    m = fn_re.match(line)
    if m:
        cur = m.group(1)
        funcs.setdefault(cur, [])
        continue
    if cur is None:
        continue
    r = rel_re.search(line)
    if r and funcs[cur]:
        funcs[cur][-1]["sym"] = r.group(2)   # far address (ADDR24) or DP register (ADDR8)
        continue
    m = ins_re.match(line)
    if m:
        bs = m.group(2).split()
        funcs[cur].append({"addr": int(m.group(1), 16), "bytes": bs,
                           "mn": m.group(3), "opnd": m.group(4).strip(), "sym": None})


def far_addr(i):
    """(base, offset) of an af/8f operand: symbol+off from the reloc, else the linked address."""
    if i["sym"]:
        s = i["sym"]
        mm = re.match(r"(.+?)\+0x([0-9a-f]+)$", s)
        return (mm.group(1), int(mm.group(2), 16)) if mm else (s, 0)
    b = i["bytes"]
    return ("", int(b[1], 16) | int(b[2], 16) << 8 | int(b[3], 16) << 16)


def consumer(ins, k):
    nxt = ins[k + 1] if k + 1 < len(ins) else None
    if nxt and nxt["bytes"][0] in ("85", "8d"):
        return "dp"
    return "reg"


def rep_follows(ins, k):
    return any(x["bytes"][:2] == ["c2", "20"] for x in ins[k + 1:k + 5])


for fn, ins in funcs.items():
    used = set()
    for i, a in enumerate(ins):
        op = a["bytes"][0]
        if i in used:
            continue
        if op in ("af", "8f"):
            base, off = far_addr(a)
            for j in range(i + 1, min(i + 1 + WIN, len(ins))):
                b = ins[j]
                if j in used or b["bytes"][0] != op:
                    continue
                b2, o2 = far_addr(b)
                if b2 == base and abs(o2 - off) == 1:
                    used |= {i, j}
                    kind = "abslong-" + ("ld" if op == "af" else "st")
                    cls = "-"
                    if op == "af":
                        c1, c2 = consumer(ins, i), consumer(ins, j)
                        cls = ("imag16" if rep_follows(ins, j) else "dp") if c1 == c2 == "dp" else "reg"
                    print(label, fn, kind, cls, hex(a["addr"]))
                    break
        elif op in ("a7", "87"):
            dp = a["sym"] or a["bytes"][1]   # DP operand: reloc symbol in a .o, byte in an ELF
            want = "b7" if op == "a7" else "97"
            for j in range(i + 1, min(i + 1 + WIN, len(ins))):
                b = ins[j]
                if b["bytes"][0] == want and (b["sym"] or b["bytes"][1]) == dp:
                    used |= {i, j}
                    kind = "indlong-" + ("ld" if op == "a7" else "st")
                    cls = "-"
                    if op == "a7":
                        c1, c2 = consumer(ins, i), consumer(ins, j)
                        cls = ("imag16" if rep_follows(ins, j) else "dp") if c1 == c2 == "dp" else "reg"
                    print(label, fn, kind, cls, hex(a["addr"]))
                    break
