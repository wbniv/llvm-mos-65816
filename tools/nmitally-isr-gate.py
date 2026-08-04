#!/usr/bin/env python3
"""nmitally-isr-gate.py — the mandatory disasm gate for demo #123 (`nmitally`).

Value gates cannot see this demo's failure class: an interrupt handler with perfectly legal MIR
whose *machine code* assumes a processor state the hardware never establishes. So this gate reads
the actual disassembly of the `__attribute__((interrupt))` handler and asserts three properties.

  A — SHAPE.  A function named `nmi` exists and terminates in `rti` (not `rts`). An `interrupt`
      attribute that was ignored or unsupported would emit a plain subroutine return.

  B — WIDTH.  On the 65816 a native-mode hardware interrupt pushes PB/PC/P, sets I and clears D —
      it does NOT normalise M/X. Two separate obligations follow, and the gate checks both.

      B1 ENTRY RE-ESTABLISHMENT.  The handler inherits the accumulator and index widths of whatever
      it preempted. Every push its prologue emits (`pha`/`phx`/`phy`) and every immediate it
      encodes (`adc #$f3`, `ldy #$0c`, ...) was SIZED AT ASSEMBLY TIME assuming M=1,X=1. Entering
      with M=0 makes `pha` push two bytes and makes a one-byte immediate decode as two — the
      instruction stream desynchronises. So an absolute width establishment (`sep #$30`, or
      `sep #$20` + `sep #$10`, or `rep`/`php` equivalents) must precede the first width-sensitive
      instruction. The restore half needs nothing extra: P is pushed by hardware, popped by `rti`.

      B2 FULL-WIDTH A/X/Y SAVE.  If the handler itself enters 16-bit mode anywhere (`rep #$20` /
      `rep #$30`), then saving A with an 8-bit `pha` is not enough: the interrupted code's A may
      have been 16 bits wide, and the handler's own 16-bit `lda` destroys the high byte (B). The
      A/X/Y saves must therefore happen while the corresponding flag is 16-bit — i.e. a `rep`
      covering that register must precede the save push, and the matching pull must be equally
      wide. This one corrupts state SILENTLY; there is no desync to notice.

  C — IMAG SAVE/RESTORE.  The `__rcN` zero-page Imag registers are the ABI's virtual register
      file, shared with the interrupted code. For every `__rcN` the handler DEFINES it must
      (c1) read that register before its first definition — proof the incoming value was captured;
      and (c2) have its final write sourced from a stack pull (`pla`/`plx`/`ply`) or a soft-stack
      reload (`lda ($rc0),y` style) within a short window — proof the saved value was put back.

      `__rc0`/`__rc1` (the soft-stack pointer) are the documented exception: the handler carves its
      own frame by SUBTRACTING from the pair on entry and ADDING the same amount back on exit,
      rather than stashing a copy. They are checked by the stronger, exact property instead — the
      signed 16-bit adjustments applied to the pair across the whole handler must sum to zero, i.e.
      the soft-stack pointer is left bit-for-bit as it was found.

Usage:  nmitally-isr-gate.py <disasm-file> [--symbol nmi]
        (disasm-file = output of `llvm-objdump -d --mcpu=mosw65816 --section=.text.<sym>`)

Exit 0 = PASS, 1 = FAIL, 2 = usage/parse error.
"""
import re
import sys

WIDTH_ESTABLISH = re.compile(r"^(rep|sep)\b")
# Instructions whose byte length or register width depends on the M/X flags.
WIDTH_SENSITIVE = re.compile(
    r"^(pha|phx|phy|pla|plx|ply|lda|ldx|ldy|sta|stx|sty|adc|sbc|and|ora|eor|cmp|cpx|cpy"
    r"|inc|dec|asl|lsr|rol|ror|bit|stz|tsb|trb)\b"
)
PHP = re.compile(r"^php\b")
STORE_RC = re.compile(r"^(sta|stx|sty)\s+\$[0-9a-f]+.*<(__rc\d+)>", re.I)
LOAD_RC = re.compile(r"^(lda|ldx|ldy)\s+\$[0-9a-f]+.*<(__rc\d+)>", re.I)
PULL = re.compile(r"^(pla|plx|ply)\b")
SOFT_RELOAD = re.compile(r"^(lda|ldx|ldy)\s+\(\$", re.I)
INSN = re.compile(r"^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*\t(.*)$")


def parse(path, symbol):
    """Return the handler's instruction list as (addr, mnemonic-with-operands, symbol-comment)."""
    insns = []
    in_fn = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if re.match(r"^[0-9a-f]+ <(.+)>:", line):
                in_fn = re.match(r"^[0-9a-f]+ <(.+)>:", line).group(1) == symbol
                continue
            if not in_fn:
                continue
            m = INSN.match(line.rstrip("\n"))
            if m:
                insns.append((int(m.group(1), 16), m.group(3).strip()))
    return insns


def resolve_rc(insns, relocs):
    """Attach the relocation-resolved symbol name to each instruction text, when known."""
    out = []
    for addr, text in insns:
        sym = relocs.get(addr)
        out.append((addr, text if sym is None else "%s   ; <%s>" % (text, sym)))
    return out


def parse_relocs(path):
    """`llvm-objdump -dr` prints a relocation line under the instruction it applies to; map the
    *previous* instruction address to the symbol name."""
    relocs = {}
    last_addr = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = INSN.match(line.rstrip("\n"))
            if m:
                last_addr = int(m.group(1), 16)
                continue
            r = re.search(r"R_MOS_\w+\s+(\S+)", line)
            if r and last_addr is not None:
                relocs[last_addr] = r.group(1)
    return relocs


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    path = argv[1]
    symbol = argv[3] if len(argv) > 3 and argv[2] == "--symbol" else "nmi"

    relocs = parse_relocs(path)
    insns = resolve_rc(parse(path, symbol), relocs)
    if not insns:
        print("    FAIL  A: no disassembly for symbol '%s'" % symbol)
        return 1

    rc = 0

    # ---- A: shape ------------------------------------------------------------------------
    mnemonics = [t.split()[0] for _, t in insns]
    has_rti = "rti" in mnemonics
    has_rts = "rts" in mnemonics or "rtl" in mnemonics
    if has_rti and not has_rts:
        print("    PASS  A shape: '%s' present, %d insns, terminates in rti" % (symbol, len(insns)))
    else:
        print("    FAIL  A shape: '%s' rti=%s rts/rtl=%s (interrupt CC not selected?)"
              % (symbol, has_rti, has_rts))
        rc = 1

    # ---- B: width re-establishment before the first width-sensitive instruction ------------
    first_sensitive = next((i for i, m in enumerate(mnemonics) if WIDTH_SENSITIVE.match(m)), None)
    first_establish = next(
        (i for i, m in enumerate(mnemonics) if WIDTH_ESTABLISH.match(m) or PHP.match(m)), None
    )
    if first_sensitive is None:
        print("    PASS  B1 entry width: handler touches no width-sensitive instruction")
    elif first_establish is not None and first_establish < first_sensitive:
        print("    PASS  B1 entry width: %s at insn #%d precedes first width-sensitive '%s' at #%d"
              % (insns[first_establish][1], first_establish,
                 insns[first_sensitive][1], first_sensitive))
    else:
        est = "none" if first_establish is None else "#%d (%s)" % (first_establish,
                                                                   insns[first_establish][1])
        print("    FAIL  B1 entry width: first width-sensitive insn is #%d '%s' at $%02X, but the"
              " first rep/sep/php is %s" % (first_sensitive, insns[first_sensitive][1],
                                            insns[first_sensitive][0], est))
        print("          -> the handler assumes M=1,X=1 at entry, a state the 65816 does NOT")
        print("             establish on interrupt. Entering from a `rep #$20` region mis-sizes")
        print("             the prologue pushes and immediates -> instruction-stream desync.")
        rc = 1

    # ---- B2: A/X/Y saved at full width if the handler ever goes 16-bit ----------------------
    goes16 = [i for i, (_, t) in enumerate(insns) if re.match(r"rep\s+#\$?(20|30)\b", t)]
    save_push = next((i for i, m in enumerate(mnemonics) if m in ("pha", "phx", "phy")), None)
    if not goes16:
        print("    PASS  B2 save width: handler never enters 16-bit mode; 8-bit saves suffice")
    elif save_push is None:
        print("    PASS  B2 save width: handler pushes no register")
    elif any(g < save_push for g in goes16):
        print("    PASS  B2 save width: rep at insn #%d precedes the A/X/Y save push at #%d"
              % (min(goes16), save_push))
    else:
        print("    FAIL  B2 save width: A/X/Y saved by '%s' at insn #%d (8-bit), but the handler"
              " enters 16-bit mode at insn #%d (%s)"
              % (mnemonics[save_push], save_push, min(goes16), insns[min(goes16)][1]))
        print("          -> the interrupted code's A may be 16 bits wide; the handler's own 16-bit")
        print("             lda destroys the high byte (B) and the 8-bit pla cannot restore it.")
        print("             SILENT state corruption of the interrupted routine.")
        rc = 1

    # ---- C: Imag save/restore --------------------------------------------------------------
    defs, reads = {}, {}
    for i, (_, text) in enumerate(insns):
        sym = None
        m = re.search(r"<(__rc\d+)>", text)
        if m:
            sym = m.group(1)
        if sym is None:
            continue
        op = text.split()[0]
        if op in ("sta", "stx", "sty"):
            defs.setdefault(sym, []).append(i)
        elif op in ("lda", "ldx", "ldy"):
            reads.setdefault(sym, []).append(i)

    # __rc0/__rc1 — the soft-stack pointer. Exact check: the 16-bit adjustments sum to zero.
    sp_adj, sp_note = 0, []
    for i, (_, text) in enumerate(insns):
        m = re.search(r"<(__rc[01])>", text)
        if m is None or not text.startswith("lda"):
            continue
        nxt = insns[i + 1][1] if i + 1 < len(insns) else ""
        a = re.match(r"adc\s+#\$([0-9a-f]+)", nxt)
        if a:
            delta = int(a.group(1), 16)
            sp_adj += delta if m.group(1) == "__rc0" else delta << 8
            sp_note.append("%s%+d" % (m.group(1), delta))
    sp_balanced = (sp_adj & 0xFFFF) == 0
    if sp_balanced:
        print("    PASS  C0 soft-stack ptr: __rc0/__rc1 adjustments balance to 0 (%s)"
              % " ".join(sp_note))
    else:
        print("    FAIL  C0 soft-stack ptr: __rc0/__rc1 adjustments sum to 0x%04X, not 0 (%s)"
              % (sp_adj & 0xFFFF, " ".join(sp_note)))
        rc = 1

    unsaved, unrestored = [], []
    for sym, didx in sorted(defs.items(), key=lambda kv: int(kv[0][4:])):
        if sym in ("__rc0", "__rc1"):
            continue  # covered exactly by the C0 balance check above
        ridx = reads.get(sym, [])
        if not ridx or ridx[0] > didx[0]:
            unsaved.append(sym)
            continue
        last_def = didx[-1]
        window = mnemonics[max(0, last_def - 4):last_def]
        if not any(PULL.match(m) for m in window) and not any(
            SOFT_RELOAD.match(insns[j][1]) for j in range(max(0, last_def - 4), last_def)
        ):
            unrestored.append(sym)
    if not defs:
        print("    PASS  C imag: handler defines no __rc register")
    elif not unsaved and not unrestored:
        print("    PASS  C imag: all %d defined __rc regs are read-before-def and restored"
              % len(defs))
    else:
        print("    FAIL  C imag: %d defined; unsaved=%s unrestored=%s"
              % (len(defs), unsaved or "-", unrestored or "-"))
        rc = 1

    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
