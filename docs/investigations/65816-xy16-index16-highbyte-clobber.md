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

## UPDATE (during implementation) — a phase-ordering wrinkle in approach A

Inspecting the **actual pre-RA MIR** (not the `-S` schedule) showed the triggering op is, before register
allocation, a *flexible* 8-bit load pseudo (`load i8 @g_110_2` → a GPR-result pseudo). Whether it becomes an
8-bit-**index** `LDY_Absolute` (which forces the narrowing `sep` and clobbers `XH`) or a harmless accumulator
`LDA` is **decided by the register allocator + `expandPostRAPseudo`** — *after* the point a pre-RA pass runs.
So a pre-RA "mark `XW_X8` ops as clobbering `XH`/`YH`" pass (the simple version of A) **cannot precisely
identify which ops to mark**: the `XW_X8`-ness is allocation-dependent.

This doesn't kill A, but it forces a choice:
- **A′ (conservative pre-RA clobber):** mark `XH`/`YH` clobbered on every op whose operand reg-class *could*
  be allocated to X/Y as an 8-bit index (reg-class-based, allocation-independent ⇒ pre-RA-safe). **Correct**
  (an over-claimed clobber only ever forces an *unnecessary* spill, never a miscompile). Cost = over-spill,
  but likely **small in practice** because 16-bit index values are normally short-lived (the non-LTO schedule
  spills `Xc16`→`imag16` immediately; the bug is LTO *extending* that live range). Must be **measured**.
- **C (post-RA spill repair):** in `MOSInsertREPSEP` (post-RA, where `requiredXWidth` already identifies the
  8-bit-index ops *precisely* and the allocation is final), detect a 16-bit index value (`XH`/`YH`) live
  across a narrowing `sep` and spill→reload it. **Precise** (no over-spill) but needs liveness + spill/reload
  + use-rewriting machinery in a pass that today only places `rep`/`sep`.

The cleanest *conceptual* fix — materialize `rep`/`sep` (and their `XH`/`YH` clobbers) **pre-RA** so the
allocator inherently sees them — remains the largest re-architecture and is still not recommended.

## UPDATE 2 (A′ implemented) — it does NOT work; the conflict is created *after* the pass

Implemented A′ as a pre-RA `MachineFunctionPass` (`MOSIndexWidthClobber`, `HasIndex16`-gated) marking `XH`/`YH`
implicitly clobbered on every non-`XLow` op touching an 8-bit-X/Y-capable operand, hooked at `addPreRegAlloc`.
Built (14 s incremental) and tested — **it does not fix the bug**, for three compounding reasons:

1. **The clobber doesn't create interference.** `XH`/`YH` are declared *"not directly addressable — only
   live as the high half of X16/Y16"* (`MOSRegisterInfo.td:112`). Implicit dead-defs of them do **not** make
   the allocator spill a virtual `Xc16` value live across them — the minimal repro stayed wrong (`0x0000`),
   register allocation essentially unchanged.
2. **Wrong phase — the conflict doesn't exist yet at pass time.** The buggy interleaving (`g_21` in X across
   the 8-bit `ldy`) is produced by the **machine scheduler + register allocator that run *after* this pass**.
   At pass time the schedule is the *good* one (the `Xc16` value is immediately COPY-spilled to `Imag16`); a
   pre-RA clobber can't prevent a conflict that a later pass creates.
3. **Clobbering the full `X16`/`Y16` isn't viable either.** Those *are* allocator-tracked, but a full-reg
   clobber conflicts with ops that legitimately define X/Y (e.g. `ldy` defines Y) → a double-def.

It also **crashed** on real programs: the predicate flagged PHI nodes (any function with a loop, e.g.
`transparent_crc`), and adding implicit defs to a PHI is invalid → segfault in `RenameIndependentSubregs`.

**Conclusion:** the pre-RA clobber family (A / A′) is the **wrong phase** — the conflict is only observable
*post*-register-allocation. The pass was unhooked (`addPreRegAlloc` removed); the toolchain is back to its
buggy-but-functional baseline (seeds 247/445 compile, minimal repro deterministic `0x0000`); **nothing landed
in `0002`**. The `MOSIndexWidthClobber.{cpp,h}` files remain in `vendor/` (gitignored, unregistered, inert).

### Revised recommendation → **approach C (post-RA repair)** or a scheduler/liveness constraint

- **C (post-RA, in `MOSInsertREPSEP`):** this is the phase where the bug is *visible* — the final schedule has
  `ldx g_21 … sep #$10 … stx __rc`, the 16-bit value physically in X across the narrowing. Detect a 16-bit
  index value (`XH`/`YH` live) across a narrowing `sep` and spill→reload it. Complex (custom spill/reload +
  liveness in a pass that today only places `rep`/`sep`), but correct and at the right phase.
- **Scheduler/liveness constraint:** stop the machine scheduler from interleaving an 8-bit-index op within a
  16-bit index value's live range (the non-LTO schedule already avoids the bug by keeping `Xc16` short-lived
  — the LTO scheduler is what extends it). Possibly the smallest change, but scheduling heuristics are subtle.
- **Register-model change:** make `XH`/`YH` interference-tracked so a clobber actually forces a spill — broad
  and risky.

*Pending the owner's steer on C vs the scheduler-constraint before the next implementation attempt.*

## UPDATE 3 (#2 scheduler/liveness investigated) — also not a clean win

Pinned the exact mechanism via LTO MIR after each pass: the **machine scheduler** interleaves the `g_110_2`
load (32B) between `g_21`'s `Xc16` load (16B) and its spill-COPY (64B) — harmless *there* (it's `ac`/A) — but
the **register allocator** then assigns that load to **`$y`** (an 8-bit-index op) while `$x16` is live, so the
narrowing `sep` for the `ldy` zeroes the high byte. So the conflict is, again, an **allocation-time** choice.

Two findings make #2 unattractive as a quick fix:
1. The MOS scheduler's custom `MOSSchedStrategy::tryCandidate` (`MOSMachineScheduler.cpp`) is pressure-only
   and **does not honor cluster edges**, and its `registerClassPressureDiff` counts **physical** regs only —
   so neither a cluster-mutation nor an `Xc16`-pressure heuristic takes effect without extra surgery. A
   working #2 needs a custom `ScheduleDAGMutation` **plus** a `tryCandidate` change, and still only papers
   over the RA choice.
2. **A cleaner lead surfaced:** `selectMem16Abs` (`MOSInstructionSelector.cpp:3020`) already lowers
   `G_LOAD16_ABS` through `A16`→`STAImag16` — it never emits `LDXAbs16`/`Xc16`. So `g_21` landing in `Xc16`
   (where it is *immediately spilled, never used as an index*) is an over-eager **reg-bank/class** assignment
   upstream of the load selector — approach **B** territory. Preventing a non-index 16-bit value from being
   classed `Xc16` would root-fix this shape, but the assignment is driven by `RegBankSelect`/the consumer and
   is tangled.

**Net:** A′ (pre-RA clobber) and #2 (scheduler) both founder on the same rock — the conflict is created at /
after register allocation. The robust fix is **C (post-RA repair)**, already filed as a TODO; **B**
(reg-class steering away from `Xc16` for non-index values) is the intriguing-but-tangled root alternative.

## UPDATE 4 — approach B IMPLEMENTED + VERIFIED ✅ (this is the fix)

Tracing the selection showed the over-eager `Xc16` originates in **`selectXY16`'s `G_LOAD16_ABS` case**
(`MOSInstructionSelector.cpp:2604`): it emits `LDXAbs16`/`LDYAbs16` whenever the *result is classed*
`Xc16`/`Yc16` — even when the value is immediately spilled (only consumed by a COPY), never used as a real
index. (`selectMem16Abs`, the C++ fallback, correctly lowers via `A16`→`STAImag16`.) **The fix** (≈22 lines,
xy16-gated): in that case, only emit the direct `X16`/`Y16` load when the value is **genuinely used as an
index** (has a non-COPY user); otherwise reclass the dst to `Imag16` and fall through to `selectMem16Abs`'s
accumulator path. Selection is bottom-up, so the dst's users are already selected and classifiable.

**Verified (2026-06-20):**
- **Correct, 4-way, both emulators:** minimal repro `0x0002`, seed 445 `0x0D1D`, seed 247 `0x80FE` —
  `default == default-O0 == a16 == xy16` everywhere. The csmith harness (incl. MAME) reports
  `seed 247 0x80FE (all agree)`, `seed 445 0x0D1D (all agree)`, 0 mismatch/crash.
- **a16/default byte-identical** — `selectXY16` is reached only under `STI.hasIndex16()`
  (`MOSInstructionSelector.cpp:280`), so the change is unreachable for a16/default *by construction*.
- **No xy16 regression:** `xy16basic`/`xy16ops`/`xy16indiry`/`xy16spill`/`xy16spillr` all PASS — crucially the
  *genuine* index paths (`xy16ops`/`indiry`/`spillr`, which use `LDXImag16`/`LDAbsXIdx16`) are unchanged, so
  the fix routes **only** the spurious-spill case to the accumulator.
- **`-verify-machineinstrs` clean.**
- **Smaller code, not larger:** the minimal `main` shrank from **61 → 54 bytes** — the fix *removes* the
  pointless `rep #$10; ldx; sep #$10` round-trip rather than adding anything.

Why B is *not* "incomplete" in practice: the fix keeps the direct `X16`/`Y16` load for every value genuinely
consumed as an index (no regression there), and only diverts values that were headed for an immediate
`Xc16`→`Imag16` spill — which is exactly the shape that the bug needs and that gains nothing from `Xc16`.

**`0002` status:** the fix is live in `vendor/` (toolchain rebuilt + verified). Committing it to the tracked
`patches/llvm-mos/0002-*.patch` is **pending coordination** — a concurrent worker has uncommitted **#320
far-pointer runtime** vendor changes (`G_LOAD_FAR_INDIR`/`Imag32`/`tryFarIndirectAddressing`/`LDIndirLong`)
that a `0002` regen would absorb, so a clean `0002` commit needs their work committed first (or a shelve).

## Recommendation (superseded by UPDATE 2 above)

**Approach A′** (conservative reg-class-based pre-RA clobber): it keeps the fix as a small pass that leverages
the existing allocator's spilling (no hand-written spill/reload machinery, the error-prone part of C), it is
the structural hardware-invariant framing we want, and its only downside (over-spill) is a **measurable size**
question, not a correctness risk. Fall back to **C** only if A′'s measured size cost is unacceptable. Both are
`HasIndex16`-gated ⇒ a16/default byte-identical. *(Pending the owner's steer on the A′-vs-C trade-off before
implementing — the over-spill cost is unknown until built.)*

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

- **Ownership / upstream relevance.** Verified: `XH/YH/X16/Y16`, `Xc16/Yc16`, and `MOSInsertREPSEP` (net-new,
  `--- /dev/null`) are all added by patch `0002`; upstream's `W65816` exists only as an **8-bit / emulation-
  mode** target (`FeatureAccum16`/`FeatureIndex16` are explicitly *NOT* implied by `FamilyW65816`). So the
  code and the bug are ours — but this is **not** merely a private-feature defect. The invariant it encodes
  (the 65816's *single shared index-width flag* zeroes `XH`/`YH` on narrowing) is **fundamental hardware
  behavior**, so the corrected register model is foundational native-65816 support that belongs in the **M2
  upstream contribution** of native 16-bit codegen, not a fork-local afterthought. There is no bug to file
  against *current* upstream (they lack native 16-bit mode), but the fix should be expressed as a structural
  *hardware invariant* (every op that forces 8-bit index clobbers `XH`+`YH`) and carried into that
  contribution — not bolted on as an `xy16` special case.
- The 18-line cvise output and the 8-line UB-free repro are saved at `/tmp/xy16-reduce-445/SAVED-*.c`; the
  8-line form should become the committed regression micro-test.
- Seed 247 shares the idiom (a 16-bit value routed through an index register, live across an 8-bit-index op);
  approach A fixes the class, so it should resolve both seeds — to be confirmed in step 2.
