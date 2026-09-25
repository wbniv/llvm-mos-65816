#!/usr/bin/env python3
"""Static W65C816S cycle/byte estimator over `llvm-objdump -dr` output.

Usage: llvm-objdump -dr X.o | cycles.py [--x16]

For every function prints: total bytes, one-path cycles (entry -> first rts, conditional branches
NOT taken, `bra` taken), and — if the function has a loop — loop-body bytes and cycles/iteration
(loop head -> back-edge, back-edge taken, the exit branch not taken, inner forward branches not taken).

A label named `L`/`L<n>` is a loop label inside the current function, not a new function.
Loop detection: a backward conditional branch (hand-written shapes, `bne L`) or a `jmp` whose
R_MOS_ADDR16 relocation targets `.text.<fn>+0xNN` (compiler output, `beq exit; jmp head`).

Timing model (W65C816S datasheet, native mode, DL=0 so no direct-page penalty):
  m = 1 when M=0 (16-bit A), x = 1 when X=0 (16-bit X/Y).
  imm 2+w | dp 3+w | abs 4+w | long 5+m | long,X 5+m | dp,X 4+w | abs,X/Y load 4+w(+1 if x)
  abs,X/Y store 5+m | [dp] 6+m | [dp],Y 6+m | (dp) 5+m | (dp),Y 5+m(+1 if x)
  RMW dp 5+2m | RMW abs 6+2m | implied/acc 2 | rep/sep 3 | pha/phx/phy 3+w | pla/plx/ply 4+w
  branch 2 (+1 taken) | bra 3 | jmp abs 3 | rts 6 | xba 3
  (w = m for accumulator ops, x for X/Y ops.) Page-crossing penalties are ignored (not knowable
  statically); this is an estimate for comparing shapes, not a cycle-exact simulator.
"""
import re
import sys

XOPS = {"ldx", "ldy", "stx", "sty", "cpx", "cpy"}
RMW = {"asl", "lsr", "rol", "ror", "inc", "dec", "tsb", "trb"}
COND = {"bcc", "bcs", "beq", "bne", "bmi", "bpl", "bvc", "bvs"}
STORES = {"sta", "stx", "sty", "stz"}

INSN = re.compile(r"^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*\t(\S+)(?:\t(.*?))?\s*(?:;.*)?$")
FUNC = re.compile(r"^([0-9a-f]+) <([^>]+)>:")
RELOC = re.compile(r"^\s*([0-9a-f]+):\s+R_MOS_\S+\s+(\S+)")


def cycles(mn, op, nb, m16, x16):
    m, x = int(m16), int(x16)
    w = x if mn in XOPS else m
    op = op or ""
    if mn in ("rep", "sep"):
        return 3
    if mn == "rts" or mn == "rtl":
        return 6
    if mn == "xba":
        return 3
    if mn in ("pha",):
        return 3 + m
    if mn in ("phx", "phy"):
        return 3 + x
    if mn in ("pla",):
        return 4 + m
    if mn in ("plx", "ply"):
        return 4 + x
    if mn in ("php", "phb", "phk", "phd"):
        return 3 if mn != "phd" else 4
    if mn in ("plp", "plb", "pld"):
        return 4 if mn != "pld" else 5
    if mn in COND:
        return 2
    if mn == "bra":
        return 3
    if mn == "jmp":
        return 3 if nb == 3 else 4
    if mn == "jsr":
        return 6
    if mn == "jsl":
        return 8
    if op == "" or op == "a":
        return 2
    if op.startswith("#"):
        return 2 + w
    if op.startswith("["):
        return 6 + m
    if op.startswith("("):
        base = 5 + m
        if op.endswith(",y"):
            base += x
        return base
    idx = op.endswith(",x") or op.endswith(",y")
    if nb == 4:  # absolute long / long,X
        return 5 + m
    if nb == 2:  # direct page
        if mn in RMW:
            return (6 if idx else 5) + 2 * m
        return (4 if idx else 3) + w
    # nb == 3: absolute
    if mn in RMW:
        return (7 if idx else 6) + 2 * m
    if idx:
        if mn in STORES:
            return 5 + m
        return 4 + w + x
    return 4 + w


def parse(lines):
    funcs, cur = [], None
    for ln in lines:
        mf = FUNC.match(ln)
        if mf and not (cur is not None and re.fullmatch(r"L\d*", mf.group(2))):
            cur = {"name": mf.group(2), "base": int(mf.group(1), 16), "insns": [], "relocs": {}}
            funcs.append(cur)
            continue
        if cur is None or mf:
            continue
        mr = RELOC.match(ln)
        if mr and cur["insns"]:
            cur["relocs"][cur["insns"][-1]["addr"]] = mr.group(2)
            continue
        mi = INSN.match(ln)
        if mi:
            cur["insns"].append({
                "addr": int(mi.group(1), 16),
                "nb": len(mi.group(2).split()),
                "mn": mi.group(3),
                "op": (mi.group(4) or "").strip(),
            })
    return funcs


def target_of(ins, relocs, fname):
    """Branch/jump target address (function-relative), or None."""
    r = relocs.get(ins["addr"])
    if r:
        mm = re.match(r"\.text\.(.+?)(?:\+0x([0-9a-f]+))?$", r)
        if mm and mm.group(1) == fname:
            return int(mm.group(2) or "0", 16)
        return None
    mm = re.match(r"\$([0-9a-f]+)", ins["op"])
    if mm and (ins["mn"] in COND or ins["mn"] in ("bra", "jmp")):
        return int(mm.group(1), 16)
    return None


def walk(insns, by_addr, relocs, fname, start, m16, x16, stop_at=None, limit=4000):
    """Follow one path from `start`. Returns (cycles, m16, x16, visited-addrs)."""
    cyc, i, seen = 0, by_addr[start], []
    for _ in range(limit):
        ins = insns[i]
        seen.append(ins["addr"])
        mn, op = ins["mn"], ins["op"]
        if mn in ("rep", "sep"):
            v = int(op.lstrip("#$"), 16) if op.startswith("#$") else int(op.lstrip("#"))
            on = mn == "rep"
            if v & 0x20:
                m16 = on
            if v & 0x10:
                x16 = on
        if stop_at is not None and ins["addr"] == stop_at:
            c = cycles(mn, op, ins["nb"], m16, x16)
            cyc += c + (1 if mn in COND else 0)  # back-edge taken
            return cyc, m16, x16, seen
        cyc += cycles(mn, op, ins["nb"], m16, x16)
        if mn in ("rts", "rtl"):
            return cyc, m16, x16, seen
        if mn in ("bra", "jmp"):
            t = target_of(ins, relocs, fname)
            if t is None or t not in by_addr:
                return cyc, m16, x16, seen
            i = by_addr[t]
            continue
        i += 1
        if i >= len(insns):
            return cyc, m16, x16, seen
    raise RuntimeError("path walk did not terminate")


def analyse(f, x16_entry):
    insns = f["insns"]
    by_addr = {ins["addr"]: k for k, ins in enumerate(insns)}
    total = sum(i["nb"] for i in insns)
    # loop: a backward cond branch or a jmp back into the function
    head = edge = None
    for ins in insns:
        t = target_of(ins, f["relocs"], f["name"])
        if t is not None and t < ins["addr"] and (ins["mn"] in COND or ins["mn"] == "jmp"):
            head, edge = t, ins["addr"]
    res = {"name": f["name"], "bytes": total}
    if head is None:
        res["path_cyc"] = walk(insns, by_addr, f["relocs"], f["name"], insns[0]["addr"], False, x16_entry)[0]
        return res
    # M/X state at the loop head: walk the prologue linearly up to head
    pre_c, m16, x16 = 0, False, x16_entry
    for ins in insns:
        if ins["addr"] >= head:
            break
        if ins["mn"] in ("rep", "sep"):
            v = int(ins["op"].lstrip("#$"), 16) if ins["op"].startswith("#$") else int(ins["op"].lstrip("#"))
            if v & 0x20:
                m16 = ins["mn"] == "rep"
            if v & 0x10:
                x16 = ins["mn"] == "rep"
    body_c, _, _, _ = walk(insns, by_addr, f["relocs"], f["name"], head, m16, x16, stop_at=edge)
    end = by_addr[edge]
    body_b = sum(i["nb"] for i in insns[by_addr[head]:end + 1])
    # compiler shape `beq exit; jmp head`: the not-taken beq is inside [head, edge] already.
    res.update(loop_bytes=body_b, iter_cyc=body_c)
    return res


def main():
    x16 = "--x16" in sys.argv
    for f in parse(sys.stdin.read().splitlines()):
        if not f["insns"]:
            continue
        r = analyse(f, x16)
        if "iter_cyc" in r:
            print(f"  {r['name']:<16} {r['bytes']:>4} B   loop body {r['loop_bytes']:>3} B  {r['iter_cyc']:>4} cy/iter")
        else:
            print(f"  {r['name']:<16} {r['bytes']:>4} B   {r['path_cyc']:>4} cy (fall-through path)")


if __name__ == "__main__":
    main()
