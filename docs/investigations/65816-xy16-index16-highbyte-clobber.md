# `+mos-xy16` miscompile — a 16-bit index value's high byte zeroed by index-narrowing `sep` — root cause + fix scoping

*Deep root-cause + fix-scoping record for the `+mos-xy16`-only Csmith runtime miscompiles (seeds 247 + 445).
Companion to the execution plan [`2026-06-20-321-xy16-seed445-cvise-reduction.md`](../plans/2026-06-20-321-xy16-seed445-cvise-reduction.md)
and the canonical Track-B plan [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md`](../plans/2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md).
This note pins **what the bug is**, **why** the earlier static analysis missed it, and **what a correct fix
requires** — so the fix is done deliberately, not guessed. **No code has been changed yet** (per the
"scope-first" decision).*

## Symptom

Csmith differential fuzzing found two seeds where, of the four trusted configurations, only `+mos-xy16`
diverges: `host == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg`, but `+mos-xy16` is wrong on **both**
emulators (445: `0x0D1D` vs `0x35E7`; 247: `0x80FE` vs `0x7C73`). Disambiguation (commit `f410115`) proved
both emulators agree on the *same* wrong xy16 value ⇒ a genuine compiler bug, not an emulator artifact.

An earlier 10-agent static workflow (`wf_826f3a8e-bff`) concluded the index **width** was correct everywhere
and refused to localize the bug (it even refuted its own `requiredXWidth` fix 3/3). The decisive move was to
**reduce, not guess.**

## How it was localized — cvise reduction

`cvise` (now installed; wired into `task dev-setup`) reduced the 9 KB seed 445 to **18 lines** using
[`dev/reduce-xy16.sh`](../../dev/reduce-xy16.sh) — a **target-only multi-config interestingness test** (no x86
host oracle is possible: Csmith's `int` is 16-bit). Interesting iff `V(default-Os)==V(default-O0)==V(a16-Os)`
and `≠ V(xy16-Os)`, all read from bsnes-jg headless (load-insensitive ⇒ parallel-safe). cvise even removed its
own injected UB. De-UB'd / re-minimized canonical repro (**8 lines, UB-free**, wrong on both emulators):

```c
volatile short corpus_result;
long crc32_context, func_1_g_8; int g_21 = 535; volatile int g_59; char g_110_2;
void crc32_byte(char b) { crc32_context = b; }
void func_12(int x) { (void)x; g_59; }
void main(){ func_1_g_8=0;
  for(; func_1_g_8<=0; func_1_g_8+=1){ int *l_20=&g_21; func_12((*l_20)--); char *l_109=&g_110_2; *l_109|=g_21; }
  crc32_byte(g_21>>8); corpus_result=crc32_context; }
```

`g_21 = 535 = 0x0217`; decremented once ⇒ `0x0216`; `0x0216 >> 8 = 0x02`. Correct `corpus_result = 0x0002`.
**xy16 gives `0x0000`.** Exposing the full `g_21` instead of `g_21>>8`: `default=0x0216`, **`xy16=0x0016`** —
`g_21`'s high byte `0x02` is exactly **zeroed**.

## Root cause — index-narrowing `sep #$10` zeroes a live 16-bit value's high byte

Reading the **post-LTO** disassembly of `main` (the `--config` LTO build — the pre-LTO `-S` is a *different,
non-buggy* schedule; **measure the build that actually runs**):

```
rep #$10 ; ldx g_21      ; X = 0x0217   (g_21 loaded 16-bit into the X index register — Xc16)
sep #$10                 ; X = 0x00_17  ★ narrowing index to 8-bit ZEROES XH/YH (65816 hardware)
ldy g_110_2              ; the unrelated 8-bit Y load that forced the sep
...
rep #$10 ; stx __rc2     ; stores X = 0x0017 (high byte already gone) → __rc3 = 0x00
... dec → 0x0016 → sta g_21 ; g_21 = 0x0016 ...
ldx __rc3 (=0x00)        ; (g_21>>8) read back as 0 → corpus_result = 0x0000
```

The 16-bit value `g_21` is selected into the **`Xc16`** register class (`%0:xc16 = G_LOAD16_ABS @g_21`) and
left **live in the X index register across a `sep #$10`**. On the 65816 the X and Y index registers share a
**single** index-width status flag; setting it to 8-bit **forces `XH` and `YH` (the high bytes) to zero**. So
the narrowing — inserted by `MOSInsertREPSEP` purely to satisfy the unrelated 8-bit `ldy g_110_2` — silently
destroys `g_21`'s high byte. Both emulators agreeing on `0x0000` confirms both *correctly* zero XH; the
codegen wrongly assumed it survives.

This explains exactly the two pieces cvise found load-bearing: the `func_12((*l_20)--)` call+pointer forces
`g_21` into `Xc16`, and the `*l_109 |= g_21` line's 8-bit `g_110_2`→`Y` load forces the index-narrowing `sep`.
Verified two independent ways (the `>>8` result *and* `g_21` itself).

## Why the static workflow missed it — it's a register-MODEL gap, not a per-instruction width gap

`XH`/`YH` **are** modeled (`MOSRegisterInfo.td:114`, sub-regs `subhi` of `X16`/`Y16`, `CoveredBySubRegs`).
The gap is that **nothing models index-narrowing as clobbering them**:

- `SEP_Immediate`/`REP_Immediate` (`MOSInstrInfo.td:704`) carry **no `Defs`**.
- `MOSInsertREPSEP` runs in `addPreEmitPass` (`MOSTargetMachine.cpp:334`) — **post-register-allocation** — and
  its `requiredXWidth` lattice (`MOSInsertREPSEP.cpp:163`, flowed per-instruction in `placeIntraBlock`,
  `:298`) is purely **per-instruction** ("does *this* MI need X8 or X16?"). It has **no notion of a value
  being live in X/Y across the narrowing point.**

So the register allocator freely kept a 16-bit `Xc16` value live across an 8-bit-index op — an **impossible
situation on hardware**: a live 16-bit index value pins the shared index-width flag to 16-bit for its whole
live range, so *any* 8-bit-index op in that range is illegal. The earlier workflow checked that each
instruction *ran* in the right width (true) and concluded "no bug" — but the defect is a **liveness/allocation
constraint**, invisible to a per-instruction width audit.

## Fix approaches (scoped; all `HasIndex16`-gated ⇒ a16/default untouched)

Correctness bar for any fix: the 4-way differential on the minimal repro + seeds 247/445, plus
`xy16basic/xy16ops/xy16indiry/xy16spill*`, the csmith/torture sweeps, and `a16`/`default` **byte-identical**.

### (A) Model the clobber — *recommended*

Make every instruction that requires 8-bit index implicitly **clobber `XH` and `YH`**, so the register
allocator must spill any live 16-bit index value (`Xc16`/`Yc16`) to ZP (`Imag16`) across it. This is the true
hardware model: narrowing the shared index flag destroys both high bytes.

- **Implementation:** a small **pre-RA** `MachineFunctionPass`, inserted in the `addPreRegAlloc` region
  (before `RegisterCoalescer`/the allocator — `MOSTargetMachine.cpp:285–313`), gated on `HasIndex16`, that
  adds implicit-def `XH`,`YH` operands to each MI whose execution requires 8-bit index. The "requires 8-bit
  index" predicate is the existing `requiredXWidth==XW_X8` classification (`MOSInsertREPSEP.cpp:163`) — but it
  must be made **pre-RA-safe**: the `XHigh`-flagged reals are identified by TSFlag (works pre-RA); the
  indexed-addressing pseudos (`LDAAbsIdx`/`(zp),Y`/ALU `zp,X`/…) must be matched by **opcode or addressing
  mode**, not by the current post-RA `readsRegister(MOS::X/Y)` test (operands are vregs pre-RA). This is the
  same "enumeration vs structural" subtlety flagged for Track A — the structural option is preferred.
- **Correctness:** complete. Forces a spill→reload around the conflict; the high byte then lives in ZP,
  untouched by the `sep`. Also covers genuine-index values live across an 8-bit op (spill/reload, correct).
- **Cost / risk:** broad — every 8-bit indexed access becomes a barrier for live 16-bit index values, so code
  that interleaves them gains spills (size). Likely **small in practice** (16-bit index values and 8-bit
  indexed accesses rarely co-occur) but must be **measured** on the xy16 suite during implementation. No
  correctness risk; `HasIndex16`-gated ⇒ a16/default provably byte-identical.

### (B) Steer instruction selection away from `Xc16`/`Yc16`

In `selectMem16Abs` (and friends; `G_LOAD16_ABS` → `MOSInstructionSelector.cpp:324`), prefer `A16`/`Imag16`
for 16-bit values that aren't genuine index uses, so the value never lands in an index register it can't keep.

- **Cost / risk:** localized, but **incomplete** — it would fix *this* repro yet leaves the underlying defect:
  a value that genuinely *must* be an index (real `abs,X16` access) can still be left live across an 8-bit op.
  Reg-class choice is also often forced by the consumer, so the steer is unreliable. **Not a real fix.**

### (C) Spill in `MOSInsertREPSEP`

At a narrowing point where `XH`/`YH` is live, save the 16-bit index value to a scratch ZP pair before the
`sep` and reload after re-widening.

- **Cost / risk:** can be made correct but **high implementation risk** — it is **post-RA** (`:334`), so it
  means inserting spill code and rewriting downstream uses by hand, with recomputed liveness (`LiveRegUnits`),
  in a pass that today only places `rep`/`sep`. Easy to get subtly wrong; the most error-prone option.

## Recommendation

**Approach A.** It is the only **general + correct** fix: it encodes the actual hardware invariant (a live
16-bit index value pins the index width, so 8-bit-index ops clobber the high bytes) at the right phase
(pre-RA, where the allocator can act on it). B is incomplete (doesn't cover genuine-index live ranges); C is
correct-able but high-risk post-RA surgery. A's only real cost is potential extra spills, which is a **size**
question to *measure*, not a correctness risk — and it is `HasIndex16`-gated so a16/default are untouched.

### Implementation plan for A (next step, on approval)

1. On a worktree with a rebuildable toolchain, add the pre-RA `HasIndex16`-gated clobber-marking pass; derive
   the "requires-8-bit-index" set **structurally** (TSFlag `XHigh` ∪ the indexed-addressing pseudo opcodes),
   not by hand-enumeration. Clobber **both** `XH` and `YH`.
2. Rebuild (`dev/run.sh toolchain`) and verify on the minimal repro + seeds 247/445 (4-way, both emulators).
3. **Measure size:** diff the xy16 suite + the 247/445 disasm pre/post-fix — the only deltas should be added
   spills around 8-bit-index ops in 16-bit-index-live regions; **a16/default byte-identical**.
4. Run the no-regression gate (xy16 micro-tests; csmith `200 101` + `200 301`; `torture 60`;
   `-verify-machineinstrs`). Add the 8-line repro as an xy16 differential micro-test.
5. Regenerate `patches/llvm-mos/0002-*.patch`; land on the xy16 work area.

## Notes

- **This is entirely our #321 code** (`+mos-xy16`, the `XH/YH/X16/Y16` classes are `#321 xy16` additions in
  patch `0002`) — **not** an upstream llvm-mos defect, so no upstream report is owed; the fix is in `0002`.
- The 18-line cvise output and the 8-line UB-free repro are saved at `/tmp/xy16-reduce-445/SAVED-*.c`; the
  8-line form should become the committed regression micro-test.
- Seed 247 shares the idiom (a 16-bit value routed through an index register, live across an 8-bit-index op);
  approach A fixes the class, so it should resolve both seeds — to be confirmed in step 2.
