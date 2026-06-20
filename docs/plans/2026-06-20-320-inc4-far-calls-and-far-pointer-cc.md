# #320 Increment 4 — far calls (JSL/RTL) + far-pointer calling-convention comparison

**Date:** 2026-06-20 · **Status:** Phase 0 + Phase 1 DONE (two-emulator verified) · Phase 2 (CC comparison) NEXT
**Builds on:** [Inc 3](2026-06-20-320-far-pointer-runtime.md) (runtime far deref/cast/arith, all intra-function, DONE)

---

## Context

#320 Increments 1–3 delivered **far DATA**: absolute-long load/store and runtime far-pointer
deref/cast/arithmetic — but every bit of it is **intra-function**. Increment 4 is the cross-function
half: **far CALLS** (calling code in another 64 KB bank) and the **far-pointer calling convention**
(passing/returning a 32-bit `p2` value across a call).

**No longer upstream-gated.** Earlier docs deferred the CC as "upstream-gated on an ABI decision."
New direction (user, 2026-06-20): **implement every ABI variant and measure** — the project's
"measure, don't assume" methodology, exactly as the 2026-06-20 *three-frame-strategies* study did.
The byte/cycle counts pick the convention; we bring a measured implementation to upstream, not a
question.

**Two separable things** (confirmed by investigation):

1. **Far-call MECHANISM** — `JSR`→`JSL` ($22, pushes 3-byte return), `RTS`→`RTL` ($6B, pops 3). This
   is **one approach**, not an ABI fork: it's the hardware far call. Arguments pass the *normal* way;
   only the code's bank differs. A small, demonstrable increment (Phase 1).
2. **Far-pointer CC** — how a 24-bit `p2` lays out across storage (ZP bytes / A,X,Y / stack). **This**
   is the multi-variant ABI question → build all variants, measure, decide (Phase 2).

### What already exists (verified, not assumed)

- `JSL_AbsoluteLong` ($22, `InstCall`) and `RTL_Implied` ($6B, `InstReturn`) are defined as MC
  instructions (`MOSInstrInfo.td:767,774`) but **never emitted** — no pseudo wraps them.
- `JSR` is a pseudo → `JSR_Absolute addr16` (`MOSInstrLogical.td:337`); `RTS`/`RTI` are
  `MOSReturn<…>` pseudos (`:358-359`). I mirror these for `JSL`/`RTL`.
- `lowerCall` hardcodes `MOS::JSR` (`MOSCallLowering.cpp:410`); `lowerReturn` hardcodes
  `MOS::RTS`/`RTI` (`:277`). Clean single hook points.
- crt0 is already native-mode (`platforms/snes/crt0.c`), frame lowering is soft-stack — the 3-byte
  JSL return address is transparent (the hard stack only holds the return address). **No crt0/frame
  change needed.**
- `snes-far/link.ld` has the `rom_1` region (bank $01) and `.far_rodata`→`rom_1` (`:31,58`). A
  `.far_text`→`rom_1` line is the parallel addition for far CODE.
- The CC is table-driven `CC_MOS` (`MOSCallingConv.td:58-75`): pointers→`RS1..RS7` (Imag16 pairs),
  i8→`A`,`X`,`RC2..`; **no i32/4-byte rule** → a 32-bit `p2` mis-sizes into a 16-bit `RS1`
  (`G_UNMERGE_VALUES scalar source does not match destination`). Phase 2 adds the rule(s).

---

## Phase 0 — `sta [dp]` far-store micro-test (close the Inc 3 loose end)

The runtime far **store** (`*fp = v` → `G_STORE_FAR_INDIR` → `STIndirLong`, opcode `$87`) was
implemented symmetrically with the load in Inc 3 but never exercised by a gate. Add one (trivial,
mirrors `far_indir.c`):

- `examples/65816/far_store.c` — write a sentinel through a runtime far pointer, then read it back
  (host-checkable). Needs `+mos-a16` (32-bit value). Bank $00 (`mos-snes.cfg`).
- `dev/far_store.sh` (mirror `dev/far_cast.sh`; disasm gate asserts `$87` = `sta [dp]`).
- Wire into `dev/run.sh` usage + `dev/xcheck.sh`.

Gate: disasm shows `87` (sta [dp]); MAME + bsnes-jg read back the stored byte.

---

## Phase 1 — far calls (JSL / RTL), demonstrable single approach

### Backend (`vendor/llvm-mos/llvm/lib/Target/MOS/`)

1. **`MOSInstrLogical.td`** — two pseudos mirroring `JSR`/`RTS`:
   ```
   def JSL : MOSLogicalInstr, PseudoInstExpansion<(JSL_AbsoluteLong addr24:$tgt)> {
     dag InOperandList = (ins label:$tgt);
     let isCall = true;
   }
   def RTL : MOSReturn<RTL_Implied>;
   ```
   (`addr24` on the expansion → 24-bit `R_MOS_ADDR24` reloc, same as far data's `lda $018000`.)

2. **`MOSCallLowering.cpp` `lowerCall` (:410)** — emit `JSL` for a far direct callee:
   ```cpp
   bool IsFar = Info.Callee.isGlobal() &&
                Info.Callee.getGlobal()->getSection().starts_with(".far_");
   auto Call = MIRBuilder.buildInstrNoInsert(IsFar ? MOS::JSL : MOS::JSR)...
   ```
   (Indirect/far-function-pointer calls stay near for now — a follow-up, like far *data* pointers
   came after far data.)

3. **`MOSCallLowering.cpp` `lowerReturn` (:277)** — `RTL` when the current function is far:
   ```cpp
   bool IsFar = MF.getFunction().getSection().starts_with(".far_");
   auto Return = MIRBuilder.buildInstrNoInsert(
       TFI.isISR(MF) ? MOS::RTI : (IsFar ? MOS::RTL : MOS::RTS));
   ```
   Caller (JSL) and callee (RTL) are driven by the **same** section attribute → always agree.

### SDK / linker

4. **`platforms/snes-far/link.ld`** — add after `.far_rodata` (`:58`):
   ```
   .far_text : { *(.far_text .far_text.*) } >rom_1
   ```
   Places `__attribute__((section(".far_text")))` functions at `$018xxx` (bank $01).

### `__far` mechanism

Section-based — **no clang change**: a user marks a function
`__attribute__((section(".far_text")))`. The same attribute drives placement (linker), the call
(`JSL`), and the return (`RTL`).

### Correctness constraints (MVP scope — documented, gated conservative)

- **The MVP far function is a LEAF** (or calls only other far functions). A far function that `JSR`s
  a *near* function would keep the program-bank-register at $01 and execute bank-$01 bytes at the
  near address → wrong. Making *all* calls from far code long (or bank-tracking the callee) is the
  general case — a **follow-up**, not Phase 1. The gate uses a far leaf.
- **No far tail calls**: the tail-call peephole (`MOSLateOptimization.cpp:516`) keys on `MOS::JSR`,
  so a `JSL` is never converted to a near `TailJMP` — automatically safe/conservative.
- Args reach the far leaf via the normal CC (Imag16/A/X in zero-page/registers, which are
  bank-independent); DBR=0 so the far function's `abs` data access reads bank $00 correctly.

### Gate — `examples/65816/far_call.c`

`main` (bank $00) calls a `__far` **leaf** in bank $01 via `JSL`, which returns a value via `RTL`;
the result is asserted. Disasm gate: `22` (jsl) at the call site **and** `6b` (rtl) in the far
function; the far function symbol resolves to `$018xxx`. 3-way differential (host == default == far
on MAME + bsnes-jg — note: far CALLS are a16-**independent**, so unlike far runtime *values* this
can run in the default 8-bit build too → a genuine 4-way if the callee takes/returns only ≤16-bit).

---

## Phase 2 — far-pointer calling convention: build all variants and measure

The multi-variant ABI study. **Separate execution, its own plan** when started; outline here.

**Reuse the established methodology** (`docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md`):
feature flags per variant (off by default, `MOSFeatures.td`) · a feasibility ROM per variant · a
**census** on realistic code (how often are far pointers passed/returned? register pressure?) ·
**pre-registered go/no-go bars** · measurement via `dev/measure-frame-abi.sh` (size,
`llvm-objdump --section-headers`) + `dev/probe-cycles.lua` (cycles, MAME sentinel protocol) · durable
artifacts merged regardless of outcome.

**Candidate variants** (each = a `CC_MOS` extension + a register-class/lowering change):

| | Layout of the 24-bit far pointer | Natural extension of |
|---|---|---|
| **(a) Imag32 quad** | 4 consecutive `__rc` ZP bytes (one `RL#`) | Imag16 pointer passing (`RS#`) — just wider |
| **(b) Imag16 + bank byte** | low-16 in an `RS#` pair + bank in a separate `RC#` (or `Y`) | decomposed near-ptr + a bank register |
| **(c) A:X + Y** | low-16 in `A`:`X`, bank in `Y` | the A/X return convention, extended |
| **(d) hardware stack** | pushed (reverse) on the 65816 stack | WDC816CC / ORCA-C prior art |

The root break to fix first (any variant): `CC_MOS` has no 32-bit/`p2` rule, so the value mis-sizes.
Each variant adds the assignment rule + teaches call-lowering to (dis)assemble 4 bytes / 2 words.

**Pre-register the go/no-go** before measuring (e.g. "variant X wins iff it's ≤ the others on corpus
bytes AND never regresses a realistic call shape by >2%"). A NULL result (one variant is obviously
best, or they tie and the simplest wins) is itself the publishable upstream conclusion.

---

## Verification

**Phase 0** (`sta [dp]` store):
1. `dev/run.sh far_store` → disasm `87` (sta [dp]); MAME reads back the stored byte; bsnes-jg agrees.

**Phase 1** (far calls):
2. `dev/run.sh far_call` → disasm shows `22` (jsl) at the call + `6b` (rtl) in the far leaf; the far
   symbol is at `$018xxx` (bank $01).
3. MAME: the far call executes and returns the asserted value.
4. bsnes-jg (`dev/run.sh xcheck`, new row): same value — independent confirmation.
5. No regression: existing far ROMs + corpus + a spot of `a16*` still PASS; `0001` regen round-trips
   (far-call backend hunks land in `0001`, the #320 patch — they're `HasW65816`-gated, a16-independent;
   confirm `grep -c accum16` on `0001` stays 0).

**Phase 2**: per the variant study's own pre-registered bars (separate plan).

### Results (2026-06-20) — Phase 0 + Phase 1 PASS

```
Phase 0 — far_store (sta [dp]):
  disasm   28: 87 00  sta [$0]                        -> PASS (runtime far store is indirect-long)
  MAME     SMOKE: PASS addr=0x7E0205 got=0xF3         -> PASS (stored via [dp], read back near)
  bsnes-jg far_store.sfc got=0xF3                     -> PASS

Phase 1 — far_call (JSL/RTL):
  disasm    9: 22 00 00 00  jsl  (call site)          -> PASS (far call is JSL $22)
            2: 6b           rtl  (far leaf)           -> PASS (far return is RTL $6b)
  link     far_leaf VMA = 0x18000                     -> PASS (placed in bank $01)
  MAME     SMOKE: PASS addr=0x7E0201 got=0xF3         -> PASS (value crossed the bank boundary)
  bsnes-jg far_call.sfc got=0xF3                      -> PASS

No regression: corpus 7/7 (default 8-bit, near JSR/RTS intact); a16call/a16ret PASS both emulators;
  Csmith 27/30 (0 mismatch, 0 crash, 0 error); all 5 prior far ROMs still PASS on bsnes-jg.
Patch hygiene: 0001 regen round-trips (new dev/regen-patch-0001.sh, sequential worktrees);
  0001 delta is exactly the JSL/RTL pseudos + lowerCall/lowerReturn far detection; 0001 a16-free
  (accum16=0); 0002/0003 untouched; 0002 still stacks on the new 0001.
```

**What shipped:** the far-call MECHANISM (a direct call to a `.far_*` leaf in another bank → `JSL`,
returns `RTL`), plus the Inc 3 `sta [dp]` store loose end. `JSL`/`RTL` pseudos mirror `JSR`/`RTS`;
`lowerCall`/`lowerReturn` swap on the callee/function `.far_*` section, `STI.hasW65816()`-gated so
default codegen is byte-identical. `.far_text`→`rom_1` places far code in bank $01. In `0001`
(a16-independent). **Surprise:** the SDK linker script (`.far_text` line) needs `dev/run.sh build`
(SDK rebuild) — a compiler-only `dev/run.sh toolchain` leaves the installed `link.ld` stale, so far
code silently orphans into bank $00 until the SDK is rebuilt.

---

## Patch placement

- Phase 1 far-call backend (JSL/RTL pseudos, lowerCall/lowerReturn) is `HasW65816`-gated and
  a16-independent → lands in **`0001`** (the #320 far patch), like the Inc 3 far machinery.
  (Regenerate `0001` via its clean-room method — `0001` has no `regen-patch.sh` path; snapshot-diff
  the touched files. Confirm `0001` stays free of `accum16`/foreign hunks.)
- The `.far_text` linker line, `far_store.c`/`far_call.c`, and `dev/*.sh` are tracked repo files
  (normal commit).
- Phase 2 CC variants are a16-adjacent (the 32-bit value) → likely `0002`; decided per variant.
