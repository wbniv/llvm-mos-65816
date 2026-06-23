<!-- HISTORY: snapshots in docs/plans/.history/ (regen-md-history hook). -->

# #321 — fix the two `+mos-a16` register-pressure crashes (implementation)

**Date:** 2026-06-24 · **Issue:** #321 / ROADMAP M2 · **Worktree:** `wt/321-a16-pressure`
(`/home/will/SRC/llvm-mos-65816-a16-pressure`, compiler-changing: own `vendor/` + warm `build/`,
release + fresh asserts both rebuilt 2026-06-23 23:59).
**Supplements:** the handoff [`2026-06-23-321-a16-pressure-scavenger-fix-handoff.md`](2026-06-23-321-a16-pressure-scavenger-fix-handoff.md)
+ [`2026-06-17-321-a16-threading.md`](2026-06-17-321-a16-threading.md) §Phase 3 (the fix home).

## Root cause — PINNED on the fresh asserts build (`-debug-only=regalloc,reg-scavenging`)

Both crashes are `+mos-a16 -O1/-Os` register pressure on the single physical 16-bit accumulator
(`Ac16` = `A16` = `A:B`). **But they have two distinct triggers** (so two distinct levers):

**REGPRESS** (`examples/65816/a16regpress.c` → "ran out of registers"): the greedy allocator's final
failure is an `Ac16` indexed-load transit (e.g. `%122 = LDAbsIdx16 @B,%123`, `weight:INF`) that cannot get
`$a16`, because the **i8 loop counter** (the byte index, stepped `i += 2`) is in class **`Ac` = {A}** — it
selects to `ADCImm` (`adc` is hardware-A-only; `MOSInstrLogical.td` ~92–103 `Ac:$dst`/`Ac:$l`) — and is live
across the whole loop body. Last-chance recoloring tries to move the counter's split piece off `$a` and
**fails because `Ac` is a singleton {A}** (`Try to recolor: %157 … → Fail to assign %122 to $a16`). The INF
single-instruction transit cannot spill; the {A}-class counter cannot relocate → deadlock. *Key contrast:*
`G_INC`/`G_DEC` (±1) select to `IncMB`/`DecMB` on the **relocatable `Anyi8`** class (X/Y/A/zp) —
`selectIncDecMB`, `MOSInstructionSelector.cpp` ~2417 — so a ±1 counter would never deadlock; only
`i += const>1` pins it to {A}. DEFAULT 8-bit compiles fine because it loads the u16 as two 8-bit `lda`s (A is
freed between bytes); `+mos-a16` uses one 16-bit `LDAbsIdx16` (the INF A16 transit) that can't yield A.

**SCAVNZ** (`examples/65816/a16scavnz.c` → `assertNZDeadAt` / illegal `STImag8 $p`): register allocation
*succeeds*; post-RA `scavengeFrameVirtualRegs` must materialize soft-stack frame addresses for s16 values RA
spilled (`$rs = STAIndir16 … %stack.N`). The file is saturated, so it scavenges `$a` then **`$p`** "with
spill" — and the `$p` save is illegal (`STImag8 $p`) **and N is live** (from a native 16-bit compare/ADC),
violating `assertNZDeadAt`'s upstream invariant ("NZ cannot be live at a scavenge point"). Prior spike
(`2026-06-23-321-scavenger-nz-fix-spike.md`) ruled out the naive P-gate + LDCImm-remat (both relocate to
`RC=Ac NoRegister`). The lever is **reduce a16 register pressure so a free scratch always exists**.

## Fix A — REGPRESS: de-pin the small-constant i8 counter (IMPLEMENTED)

`MOSLegalizerInfo.cpp` `legalizeAddSub`: under `STI.hasAccum16()`, lower an 8-bit `G_ADD`/`G_SUB` by a small
constant (`|Amt| ≤ MaxChain`, initially **2**) to a short chain of `G_INC`/`G_DEC` (relocatable `Anyi8`)
instead of falling to `narrowScalarAddSub` → A-pinned `ADCImm`. Reuses the proven multi-byte inc/dec
machinery (unmerge → N×inc/dec passes → merge). **Gating:** `MaxChain = hasAccum16() ? 2 : 1`, so the DEFAULT
8-bit build is byte-identical (keeps ±1-only + ADC). **Conservative:** a miss only keeps the ADC; `G_ADD`/
`G_SUB` are plain modular ops (no carry-out operand) so the inc/dec chain is value-identical — exactly as the
pre-existing ±1 rewrite already relies on. **Size:** bounded so the chain is never larger than `clc;adc`
(inc = 1 B/reg vs `clc;adc#imm` = 3 B); an index counter additionally saves the A↔X copy ADC forces.

## Fix B — SCAVNZ + pr15296: KEPT XFAIL (clean partial — the orthogonal hard core)

Fix A does **not** address SCAVNZ (`a16scavnz.c`) or `a16-zp-pressure-overflow` (`pr15296.c`): neither has an
i8 small-constant byte index — both are pure native-s16 pressure (a recursive fn holding ~5 live u16 across
the self-call + an N-live 16-bit compare; resp. pointer/union/`intptr_t` register pressure). Confirmed:
`pr15296.c`'s `+mos-a16 -Os` object is **byte-identical** pre/post Fix A. A 13-agent design workflow
(`a16-pressure-fix-design`) + the prior scavenger spike converge: the only lever for these is the deferred
**Phase-3 pre-RA `Ac16`/ZP-residency rework** (reduce s16 pressure so a free scratch always exists) or
shared-subtarget frame-lowering changes (maintainer-territory; high default-regression risk). Both stay
XFAIL — `scavenger-p-not-gpr` (repro `a16scavnz.c`, KNOWN_ISSUE_REPROS) and `a16-zp-pressure-overflow`
(c-torture). A clean partial (REGPRESS fixed) is explicit progress per the handoff.

> The design workflow's *synthesis* recommended against Lens A on the premise that "the +2 stride never
> becomes an i8 add (it's a 16-bit address IV)." That premise was **refuted empirically**: the legalized MIR
> shows `%13:_(s8) = G_ADD %0, 2` — the byte index IS an i8 add (the IR has `%2 = phi i8; %11 = add i8 %2, 2`;
> only the *address* uses `zext(%2)`). The build is the arbiter (governing lesson 1): Fix A compiles regpress
> + the original `globals.c` clean and is net-positive on real code.

## Acceptance (from the handoff)

1. Both repros compile clean (`-verify-machineinstrs`) at `+mos-a16 -O1` and `-Os`; asserts build does not abort.
2. Differential gate: host == default@MAME == a16@MAME == a16@bsnes-jg for corpus + a16 micro-suite + fuzz
   (esp. scavenger seeds 169/173/196/268/271/272/306/420 + the regalloc/zp seeds → 0-mismatch/0-crash).
3. No regression: `corpus` 7/7; `a16localx` (1d coalescer guard) + A16-threading micro-tests green;
   `-verify-machineinstrs` clean tree-wide; `measure-a16-threading.sh` no size regression.
4. XPASS guard flips (`dev/run.sh known-issues`) for `scavenger-p-not-gpr`, `regalloc-out-of-registers`,
   `a16-zp-pressure-overflow`; then de-XFAIL (remove the 3 `KNOWN_ISSUES` + promote the repros to gates).
5. Land as fork patch `0009`; update `implementation-status.md` + `TODO.md`; draft upstream PR if upstreamable.

## Verification steps (raw output + PASS/FAIL)

1. **Fix A compiles + clears REGPRESS** (release + asserts).
   ```
   release: a16regpress.c +mos-a16 -Os -verify  -> exit 0;  -O1 -> exit 0
   release: original examples/snes/corpus/globals.c +mos-a16 -Os -verify -> exit 0
            (main/pre-fix: "ran out of registers during register allocation in function 'main'")
   asserts: a16regpress.c +mos-a16 -Os/-O1 -> exit 0; -debug-only=regalloc: 0 "Fail to assign"/"ran out"
   selected MIR: ADCImm=0, IncMB/INC=4 (counter -> inc chain); disasm: inx;inx;cpx (index in X)
   ```
   **PASS.**
2. **SCAVNZ + pr15296 status.** `a16scavnz.c` still fails (`$p is not a GPR register`) on BOTH main and
   Fix A; `pr15296.c` a16 object byte-identical pre/post Fix A. Both kept XFAIL (Fix A is regpress-specific).
   *Accuracy note:* the 8 catalogued "scavenger seeds" (169/173/196/268/271/272/306/420) **already pass on
   current `main`** (csmith generation has drifted since they were catalogued — verified 169/196/271/306/420
   `[ ok ]` / `[skip]`, 0 xfail, on the pre-fix `main` clang), so they are not evidence of this fix either
   way; the **deterministic `a16scavnz.c` repro is the sole remaining `scavenger-p-not-gpr` reproducer**.
   **PASS (expected partial).**
3. **DEFAULT byte-identical.** worktree-clang vs main-clang, `-Os` (no `+mos-a16`):
   ```
   IDENTICAL (default): examples/65816/a16regpress.c
   IDENTICAL (default): examples/snes/corpus/globals.c
   ```
   Structural: the new code is `if (STI.hasAccum16() && ...)` so the 8-bit path never enters it. **PASS.**
4. **Differential gate.**
   ```
   dev/run.sh corpus      -> 7/7 passed
   a16 + kernel suite     -> PASS=57 FAIL=0  (incl. a16localx, the 1d coalescer-crash guard)
   dev/run.sh fuzz 50 1   -> 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)
   dev/run.sh a16regpress -> RESULT: PASS (corpus_result==0x01A7, MAME + bsnes-jg agree; 4 inx)
   ```
   **PASS.**
5. **No size regression (net).** `dev/measure-a16-threading.sh`: roundtrips=0 everywhere (A16-threading
   intact). Broad a16 `-Os` `.text`, main vs Fix A over 122 c-torture programs:
   ```
   total .text: main=128193  FixA=128070  delta=-123 (-0.096%)   better=4 worse=0 same=118
   real kernels: k_isort -52, k_bits -1, k_satadd +8  (net -45 B)
   outlier: a16cmpaudit +533 B (a pathological nested-loop audit harness — greedy allocation noise from
            the index's added freedom; still CORRECT, passes the a16 suite). Net across real code positive.
   ```
   **PASS** (measured net-positive; per "only a measured net-negative is a don't").
6. **`-verify-machineinstrs` clean** over all `a16*`/`k_*` examples (both `-Os` and `-O1`): 118 a16 compiles,
   only `a16scavnz.c` fails (the still-XFAIL); 59 default compiles, 0 fail. Plus fuzz 50 (×2 builds). **PASS.**
7. **XPASS + de-XFAIL.** `dev/run.sh known-issues` before edit: `a16regpress.c XPASS [regalloc-out-of-registers]`
   (both `+mos-a16` and `+mos-xy16`) -> "ACTION: drop KNOWN_ISSUES[...]"; `a16scavnz.c` still xfail. After
   removing the entry + repro row: `RESULT: PASS — 2/2 known-issue legs still reproduce`. a16regpress.c
   promoted to the positive gate `dev/run.sh a16regpress`; corpus-a16 auto-promotes globals.c. **PASS.**
8. **Patch `0009` round-trips.** `dev/regen-patch-0009.sh` -> `RESULT: PASS — 0009 round-trips`; 1 file
   (`MOSInstructionSelector.cpp`), my marker ×4, **0 foreign symbols** (no far/Imag32/packed/scavenger).
   `MOSLegalizerInfo.cpp` reverted byte-identical to main (the mis-located first attempt left no residue).
   **PASS.**
