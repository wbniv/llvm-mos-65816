# Plan: xy16 Hang Fix — `XHigh=1` on Standard ldx/ldy/stx/sty

**Date:** 2026-06-18  
**Issue:** #321, ROADMAP M2  
**Prereq:** `2026-06-18-321-xy16-legalizer-integration.md` (Increment 1e) — `LDXImag16`,
`STXImag16`, `LDAbsXIdx16`, `G_LOAD_ABS_IDX16` all landed and in the patch.  
**Baseline:** `dev/run.sh fuzz 50 1` → 16/50 PASS, 34 `xy16@MAME=0x0000` hangs, 0 crashes.

---

## Context

After Increment 1e, `dev/run.sh fuzz 50 1` passes **16/50** seeds. The 34 failures all
return `xy16@MAME=0x0000` — the ROM completes but `corpus_result` is never written, meaning
the program hung or exceeded the 180-tick watchdog.

Root cause: the existing MOS code generator uses `ldx`, `ldy`, `stx`, and `sty` for
**byte-level** operations (loading/storing individual bytes of multi-byte structs or ZP
call-convention slots). In `+mos-xy16` mode, the `MOSInsertREPSEP` X-flag lattice puts X/Y
into **16-bit mode** (`rep #$10`) for XY16 operations. The standard byte-level `ldx`/`ldy`/
`stx`/`sty` carry **no X-width annotation** — the lattice treats them as X-agnostic and
never inserts `sep #$10` before them. A `ldy abs+1` intended to read 1 byte reads **2**; a
`sty ZP` intended to write 1 byte writes **2**, silently corrupting the adjacent ZP slot.

---

## Root Cause — Seed-38 Post-Mortem

Seed-38 generates a program with a recursive function `f0(uint16_t p0, uint16_t p1)`.
The call site in `f0` itself builds the arguments for the recursive call out of globals:

```
in_u2  : uint16_t  = 0x3400   (BSS layout: &in_u2, &in_u2+1)
in_s0  : int16_t   = 0x21E9   (immediately after in_u2: &in_s0 = &in_u2+2)
```

**Default (X=1 / 8-bit) assembly — CORRECT:**
```asm
ldy  in_u2        ; Y = 0x00 (in_u2.low,  1 byte)
sty  __rc2        ; __rc2 = 0x00 ✓
ldy  in_u2+1      ; Y = 0x34 (in_u2.high, 1 byte)
sty  __rc3        ; __rc3 = 0x34 ✓  — p1 set correctly
lda  __rc4        ; A = recursion depth (~2)
```

**+mos-xy16 (X=0 / 16-bit) assembly — BROKEN:**
```asm
ldx  in_u2        ; X16 = 0x3400 (2-byte read, both bytes of in_u2 — harmless here)
ldy  in_u2+1      ; Y16 = {in_u2+2, in_u2+1} = {in_s0.low=0xE9, in_u2.high=0x34}
                  ;      reads TWO bytes starting at in_u2+1, crossing into in_s0 ← BUG
stx  __rc2        ; __rc2=0x00, __rc3=0x34 ✓
sty  __rc3        ; __rc3=0x34 (Y.low ✓), __rc4=0xE9 ← CORRUPTS recursion depth!
lda  __rc4        ; A = 0xE9 = 233 (should be ~2)
jsr  f0           ; 233 levels of recursion → soft stack overflow → hang
```

`__rc4` holds the recursive call counter (p0−1). Its intended value is ~2; the 16-bit
`sty __rc3` stores Y.low=0x34 to `__rc3` (correct) and Y.high=0xE9 to `__rc4` (corrupt).
233 recursive calls overflow the soft stack; `corpus_result` is never written → 0x0000.

### Why does the lattice leave X=16?

`requiredXWidth()` in `MOSInsertREPSEP.cpp` (line 159) returns:
- `XW_X16` for instructions with `TSFlagXLow` set (new XY16 pseudos: `LDXImag16`, etc.)
- `XW_X8` for instructions with `TSFlagXHigh` set (currently only `LDX_Immediate`, CPX/CPY Immediate)
- `XW_None` for everything else — including `LDX_ZeroPage`, `LDY_ZeroPage`, `STX_ZeroPage`, `STY_ZeroPage`, etc.

`XW_None` means the lattice carries through whatever X-width was already set. After a
`LDXImag16` (XW_X16), X=16 stays set for all subsequent X-agnostic instructions. Any
`ldy ZP` / `sty ZP` in the same block runs in X16 mode.

### Pass ordering (confirms the fix is safe)

`ExpandPostRAPseudos` (addPreSched2, line 321) runs before `MOSInsertREPSEP` (addPreEmitPass,
line 334). However, `LDXImag16` / `STXImag16` / `LDYImag16` / `STYImag16` are **MC pseudos**:
`expandPostRAPseudo()` (MOSInstrInfo.cpp:1050) has no case for them → they survive past
`ExpandPostRAPseudos` → `MOSInsertREPSEP` sees them with `XLow=1` intact → MC emission
expands them to `LDX_ZeroPage` / `STX_ZeroPage` / etc. **after** the pass.

Adding `XHigh=1` to `LDX_ZeroPage` therefore does NOT affect `LDXImag16` expansions —
the expanded `LDX_ZeroPage` never passes through `MOSInsertREPSEP` again.

---

## Implementation

**Two files. No new test files** — the fuzz runner is the regression test.

### File 1: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrFormats.td`

`multiclass CC0_Regular` (~line 966) already adds `XHigh=1` to `_Immediate` (line 968).
Add it to `_ZeroPage` and `_Absolute`:

```tablegen
  // Before:
  def _ZeroPage : Inst16<OpcodeStr, OpcodeC0<aaa, 0b001>, ZeroPage>;
  def _Absolute : Inst24<OpcodeStr, OpcodeC0<aaa, 0b011>, Absolute>;

  // After:
  def _ZeroPage : Inst16<OpcodeStr, OpcodeC0<aaa, 0b001>, ZeroPage> {
    let XHigh = 1;
  }
  def _Absolute : Inst24<OpcodeStr, OpcodeC0<aaa, 0b011>, Absolute> {
    let XHigh = 1;
  }
```

Fixes **six** instructions in one place (via `defm LDY`, `defm CPY`, `defm CPX`):
`LDY_ZeroPage`, `LDY_Absolute`, `CPY_ZeroPage`, `CPY_Absolute`, `CPX_ZeroPage`, `CPX_Absolute`.

### File 2: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrInfo.td`

Add `let XHigh = 1;` to **twelve** instruction definitions (lines 67–157). Pattern:

```tablegen
// Before:
def LDX_ZeroPage :
    Inst16<"ldx", OpcodeC2<0b101, 0b001>, ZeroPage>;

// After:
def LDX_ZeroPage :
    Inst16<"ldx", OpcodeC2<0b101, 0b001>, ZeroPage> {
  let XHigh = 1;
}
```

Full list:

| Instruction | Approx. line | Mnemonic |
|---|---|---|
| `STX_ZeroPage` | 67 | `stx ZP` |
| `STX_ZeroPageY` | 69 | `stx ZP,Y` |
| `STX_Absolute` | 71 | `stx abs` |
| `LDX_ZeroPage` | 78 | `ldx ZP` |
| `LDX_Absolute` | 80 | `ldx abs` |
| `LDX_ZeroPageY` | 82 | `ldx ZP,Y` |
| `LDX_AbsoluteY` | 84 | `ldx abs,Y` |
| `STY_ZeroPage` | 148 | `sty ZP` |
| `STY_Absolute` | 150 | `sty abs` |
| `STY_ZeroPageX` | 152 | `sty ZP,X` |
| `LDY_ZeroPageX` | 154 | `ldy ZP,X` |
| `LDY_AbsoluteX` | 156 | `ldy abs,X` |

Skip `LDX_Immediate` (line 74) — already has `XHigh=1`.

### File 3: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` (added during implementation)

**The `.td` flags alone were insufficient.** The backend emits *generic load/store
pseudos* — `LDAbs`, `LDImag8`, `LDImm`, `STAbs`, `STImag8`, `LDXIdx`, `LDYIdx` — that only
become concrete `LDX_ZeroPage` / `STY_ZeroPage` / etc. during **MC lowering**
(`MOSMCInstLower.cpp`), based on the *allocated register* of the relevant operand. MC lowering
runs **after** `MOSInsertREPSEP`. These pseudos have **no `XHigh` TSFlag** (they are
register-class-generic), so `requiredXWidth()` saw them as `XW_None` and the lattice left X in
16-bit mode — the byte-level `ldx`/`sty` still ran in X16. Confirmed via post-REPSEP MIR:
`$x = LDAbs @in_b0` executing with `X=16` after a prior `LDXImag16`.

Fix — `requiredXWidth()` returns `XW_X8` for these pseudos when the relevant operand is
allocated to `$x`/`$y` (after RA all regs are physical, so the check is exact):

```cpp
auto isXY = [](Register R) { return R == MOS::X || R == MOS::Y; };
switch (MI.getOpcode()) {
case MOS::LDAbs: case MOS::LDImag8: case MOS::LDImm: case MOS::STAbs:
  if (MI.getOperand(0).isReg() && isXY(MI.getOperand(0).getReg())) return XW_X8;
  break;
case MOS::STImag8:                       // operand 1 is the GPR (op0 = ZP addr)
  if (MI.getOperand(1).isReg() && isXY(MI.getOperand(1).getReg())) return XW_X8;
  break;
case MOS::LDXIdx: case MOS::LDYIdx:       // always X / Y destination
  return XW_X8;
}
```

This is conservative in the required direction: it can only *add* a `sep #$10` before a
byte-level X/Y op (never remove one), so a misclassification misses a churn-minimization, never
causes a regression. The `.td` `XHigh` flags (Files 1–2) still matter — they cover the path
where the *real* `LDX_ZeroPage` etc. are already present at REPSEP time (e.g. via other
expansions).

**Not changed:**
- `STX_AbsoluteY` (line 493, opcode 0x9b) / `STY_AbsoluteX` (line 494, opcode 0x8b) —
  65CE-02-specific opcodes; not valid 65816 instructions. Even though `STX_ZeroPageY` and
  `STX_AbsoluteY` are paired in `MOSInstrInfoTables.td` ZPIRE, the absolute-Y form maps to
  a CE-02-only opcode and is not generated for `mosw65816`.
- `LDX_Immediate16` (line 690) — has `XLow=1` (16-bit immediate in X16 mode); must stay.
- `PHX_Implied`, `PLX_Implied`, `PHY_Implied`, `PLY_Implied` — push/pull are symmetric
  (always occur together in the same X-mode context); see **Deferred**.
- `TAX_Implied`, `TXA_Implied`, `TAY_Implied`, `TYA_Implied`, `TXY_Implied`, `TYX_Implied` —
  transfer instructions; the XY16 paths use `TAX16`/`TXA16` pseudos (XLow=1). No evidence
  of misclassification in current test corpus; see **Deferred**.

### Code-size impact

In XY16 code that interleaves X16 ops (e.g. `LDXImag16`) with byte-level X/Y ops (e.g.
`ldx ZP` for passing a sub-argument), the lattice inserts `sep #$10` before the byte-level
op and `rep #$10` before the next X16 op — 2 extra bytes per transition. The inter-block
lattice minimises transitions; a stretch of consecutive byte-level ops shares one `sep`. The
cost is acceptable: the alternative is wrong-answer hangs.

---

## Deferred

- **PHX/PLX/PHY/PLY in X16 mode.** Push/pull 2 bytes when X=0. The `xy16spillr` test
  passes (spill path is symmetric: both push and pull in the same X-mode). A future scenario
  where push occurs in X16 mode but pull in X8 (or vice versa) could produce wrong code.
  Watch for new fuzz failures that are NOT `xy16@MAME=0x0000` hangs.

- **Transfer instructions (TAX/TXA/TAY/TYA/TXY/TYX) in mixed modes.** Standard implied
  forms carry no X-width annotation. XY16 paths use `TAX16`/`TXA16` pseudos (XLow=1).
  No failures attributed to transfer instruction misclassification yet; defer until evidence
  surfaces.

---

## Files Modified

| File | Change |
|---|---|
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrFormats.td` | `CC0_Regular._ZeroPage` + `._Absolute`: add `let XHigh = 1;` (2 defs) |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrInfo.td` | 12 instructions: add `let XHigh = 1;` block |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` | `requiredXWidth()`: register-residency `XW_X8` for `LDAbs`/`LDImag8`/`LDImm`/`STAbs`/`STImag8`/`LDXIdx`/`LDYIdx` pseudos (File 3 — added during impl) |
| `patches/llvm-mos/0002-321-accum16.patch` | regen after vendor edit |

---

## Verification

1. Seed-38 (confirmed hang seed) resolves — `xy16@MAME ≠ 0x0000`:

```
$ dev/run.sh fuzz 1 38
```

```
==> a16 differential fuzz: 1 program(s), seeds 38..38
    toolchain=/work/build/llvm-mos-install/bin  bsnes=yes
  [ ok ] seed    38  0x2801 (all agree)
==> fuzz: 1/1 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

   **PASS** — seed-38 was the documented post-mortem hang; now `0x2801`, all four oracles agree.

2. No regression on existing test suite:

```
$ dev/run.sh corpus && dev/run.sh xy16basic && dev/run.sh xy16spill \
    && dev/run.sh xy16spillr && dev/run.sh xy16ops
```

```
==> corpus: 7/7 passed
RESULT: PASS — +mos-xy16 accepted, X-flag lattice inert for M16-only ops, corpus_result==0x0042   (xy16basic)
RESULT: PASS — Ac16 static-stack spill compiles clean under +mos-xy16 (Layer 4 Ac16 path intact)   (xy16spill)
RESULT: PASS — LDXImag16+LDAbsXIdx16 indexed access under +mos-xy16; corpus_result==0x3457; both emulators agree   (xy16spillr)
RESULT: PASS — G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==0x2A42; both emulators agree   (xy16ops)
```

   **PASS** — every existing test green; no regression from the `XHigh`/`requiredXWidth` change.

3. `dev/run.sh corpus` specifically — all 7 PASS:

```
$ dev/run.sh corpus
```

```
  hello      PASS  sentinel=0x42  liveness: main runs (the smoke ROM)
  arith      PASS  corpus_result=0xA9E9  8/16/32-bit integer ALU
  control    PASS  corpus_result=0x1DFB  loops / if / switch
  arrays     PASS  corpus_result=0x03E1  arrays + .rodata lookup table
  structs    PASS  corpus_result=0x0340  struct layout + pointer deref
  funcs      PASS  corpus_result=0x011E  calls + recursion (soft stack)
  globals    PASS  corpus_result=0xAB55  crt0 .data copy + .bss clear
==> corpus: 7/7 passed
```

   **PASS** — 7/7.

4. Fuzz 50 seeds — materially improved pass rate (baseline: 16/50, target: 50/50;
   if < 50/50 after the fix, the remaining failures likely have a different root cause
   and require separate investigation):

```
$ dev/run.sh fuzz 50 1
```

```
==> fuzz: 49/50 PASS, 0 known-issue (xfail)  (1 mismatch, 0 new-crash, 0 error)
  [FAIL] seed 31  mismatch: host=0x0B1F, default@MAME=0x0B1F, a16@MAME=0x0B1F,
                  xy16@MAME=0x0CCC, a16@bsnes=0x0B1F
```

   **PARTIAL — 49/50, and all 34 hangs are gone (0 new-crash, 0 hang).** Baseline was 16/50
   with 34 `xy16@MAME=0x0000` hangs. The fix cleared **every** hang. The single residual,
   seed-31, is a **mismatch (`0x0CCC` vs `0x0B1F`), not a hang** — i.e. a *different root cause*,
   exactly as this step's rubric anticipated.

   **seed-31 root cause (separate bug, pre-existing, newly exposed):** the
   `MOSInsertREPSEP` cross-block lattice **bails the whole function to `placeLegacy`** when a
   mode transition lands on a true critical edge (here `bb.1→bb.3` needs X16→X8: `bb.1` ends
   X16 via `CPXImm16`, `bb.3` enters X8 via `JSR`). `placeLegacy` restores **both** M and X to
   8-bit at *every* block terminator — but `$x16` (`= LDXAbs16 @arr+8 = 0x3C7D`) is **live
   across `bb.0→bb.1`**. The end-of-`bb.0` `sep #$30` zeroes X's high byte, truncating
   `0x3C7D → 0x007D`; the subsequent `cpx #128` then takes the wrong branch (`125 < 128` instead
   of `15485 ≥ 128`), corrupting `corpus_result`. This bail is independent of the `XHigh`
   change (both edges' X-modes are unchanged by it); the byte-level corruption that previously
   *hung* seed-31 (`0x0000`) is fixed, leaving this latent control-flow bug visible. The
   `XHigh` change is therefore a **strict improvement** (hang → 33 fixed; seed-31 hang →
   wrong-answer) with **no regression**. Tracked as a follow-up:
   [`2026-06-18-321-repsep-critical-edge-x16-liveness.md`](2026-06-18-321-repsep-critical-edge-x16-liveness.md).

5. Assembly spot-check — seed-38 `+mos-xy16` now has `sep #$10` bracketing byte-level
   `ldy`/`sty` (run inside dev container):

```
# python3 tools/a16_fuzz.py gen --seed 38 > /tmp/s38.c
# build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
#   -Xclang -target-feature -Xclang +mos-xy16 -S -o /tmp/s38_xy16_fixed.s /tmp/s38.c
# grep -E 'sep|rep|ldy|sty|ldx|stx' /tmp/s38_xy16_fixed.s | head -30
```

   Expected: `sep #$10` appears before a byte-level `ldy`/`ldx` or `sty`/`stx` that was
   previously naked in X16 context; `rep #$10` appears after (or before the next
   `LDXImag16`/`LDAbsXIdx16`). No bare `ldy abs` without preceding `sep` while X could be
   16-bit.

```
   52:	rep	#16        ; X→16 for the X16 op below
   53:	ldx	__rc2      ; LDXImag16 expansion (16-bit X load)
   54:	rep	#32
   57:	sep	#48        ; sep #$30 → M=8, X=8
   ...
   65:	sep	#48        ; sep #$30 → M=8, X=8  (X restored to 8-bit)
   66:	ldx	in_b0      ; byte-level ldx — now correctly X=8 (1-byte read)
   68:	stx	__rc2      ; byte-level stx — X=8 (1-byte write)
```

   **PASS** — the byte-level `ldx in_b0` / `stx __rc2` (66/68) run after `sep #$30` (65), which
   includes the `#$10` X-bit → X=8. The previously-naked byte X ops are now bracketed. seed-38
   computes `0x2801` correctly.

6. Patch sanity — `XHigh` additions land in the patch (run after `dev/regen-patch.sh`):

```
$ grep -c '\+XHigh' patches/llvm-mos/0002-321-accum16.patch
```

   Expected: > 0 (at least the 12 MOSInstrInfo.td additions + 2 MOSInstrFormats.td).
   Check that no foreign patch hunks were absorbed: verify `legalizeICmp`/`addSub16Native`
   hunk counts unchanged from Increment 1e baseline (5):

```
$ grep -c 'legalizeICmp\b\|addSub16Native\b' patches/llvm-mos/0002-321-accum16.patch
```

   Expected: 5 (unchanged from baseline).

```
$ grep -cP '^\+.*let XHigh = 1;' patches/llvm-mos/0002-321-accum16.patch
14
$ grep -c 'legalizeICmp\b\|addSub16Native\b' patches/llvm-mos/0002-321-accum16.patch
5
```

   **PASS** — 14 `let XHigh = 1;` additions (12 `MOSInstrInfo.td` + 2 `MOSInstrFormats.td`);
   foreign-hunk count 5, unchanged from the Increment-1e baseline (no absorption). The File-3
   `requiredXWidth()` pseudo cases (`case MOS::LDAbs:` … `case MOS::LDXIdx:`) are also present in
   the patch. `dev/regen-patch.sh` round-trips clean (reapplied MOS dir == live vendor).
