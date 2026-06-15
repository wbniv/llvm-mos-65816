# #321 native-s16 Tier 1 — broaden the test corpus

**Date:** 2026-06-15
**Status:** done (2026-06-16) — fuzzer + 6 kernels + 2 combinatorial tests landed; found 3 real
`+mos-a16` defects (2 fixed in-backend with regression tests, 1 deferred/XFAIL). A16-threading de-risked.
**ROADMAP:** step 5 (M2 — 16-bit accumulator) · **TODO:** M2 "agreed optimization order" item (5)
A16-threading is gated behind this broad corpus.

## Why (strategic context)

The #321 work (HEAD `dda6209` on `main`) has landed a large battery of native 16-bit-accumulator
(`+mos-a16`) codegen optimizations: dual-width accumulator, cross-block REP/SEP mode tracking,
native 16-bit load/store (abs/indirect), compares (unsigned/signed/equality, branch-fused +
operand-fold), constant + signed shifts, `inc a`/`dec a`, and a full family of ALU-chain fusions
(add chains, multi-use chains, immediates-in-chains, AND/OR/XOR bitwise chains). It is proven by a
suite of **~31 feature-ISOLATING micro-tests** (`a16*`).

The two biggest remaining wins are both **gated behind "a broad corpus"**:

- **Tier 2 — A16-threading**: keep an s16 value resident in the accumulator across ops, dropping the
  `lda`/`sta` Imag16 round-trip between every op. This reintroduces the register-coalescer crash that
  sank the first native-s16 prototype (Inc 1d): the coalescer merged an 8-bit value into the 16-bit
  accumulator `A16`, emitting malformed MIR.
- **Tier 3 — unify the 1b/1c peephole into the GISel-native path**: retire the dual codegen path.

The isolating micro-tests are perfect for proving each optimization in isolation, but **useless for
surfacing that coalescer crash**, which needs *volume + diversity + mixed-8/16-bit-width pressure*.
Tier 1 builds exactly that: it is the keystone that **de-risks** A16-threading and the peephole
unification by giving us a differential safety net that catches crashes and miscompiles BEFORE the
riskier work ships.

## The safety net (oracle design)

A generated/written program ends in a `volatile unsigned short corpus_result`, read back from WRAM by
the existing harness. For each program we triangulate **four** independent values that must all agree:

1. **host-expected** — the generator/author computes the program's result in Python over exact
   fixed-width (`& 0xFFFF`) semantics. Catches the case where *both* compilers are wrong.
2. **default@MAME** — compiled WITHOUT `+mos-a16` (the trusted 8-bit M1 reference codegen), run in
   MAME's `snes` driver.
3. **a16@MAME** — compiled WITH `+mos-a16`, run in MAME.
4. **a16@bsnes-jg** — the same `+mos-a16` ROM, run in the independent cycle-accurate bsnes-jg core.

`host == default == a16(MAME) == a16(bsnes)`. Any inequality is a real miscompile (almost certainly in
`+mos-a16`, since default is trusted). PLUS the `+mos-a16` build is compiled under
`-mllvm -verify-machineinstrs` — a nonzero exit / "Bad machine code" / ICE is the **coalescer crash
detector**.

### Correctness — no undefined behaviour in generated C

The differential oracle is only sound if the generated program is **strictly well-defined C** (UB lets
the two compilers legally diverge → false positive). The generator guarantees this:

- **All arithmetic is modular unsigned.** Every binary op is emitted as
  `(unsigned short)((unsigned)a OP (unsigned)b)` so the result is `(a OP b) mod 2^16`, independent of
  whether `int`/`unsigned` is 16- or 32-bit on the target. No signed overflow.
- **Shifts** use a constant amount `k ∈ [1,15]` on an explicitly `unsigned` value:
  `(unsigned short)((unsigned)x << k)` / `(unsigned)x >> k` — well-defined for any unsigned width.
  Signed (arithmetic) `>>` is emitted as `(short)x >> k` and modelled in Python as an arithmetic shift
  (matches the backend's ASHR).
- **Comparisons** cast both operands to `(unsigned short)` (unsigned compare) or `(short)` (signed
  compare) so the comparison kind is unambiguous; modelled in Python with the matching interpretation.
- **No division/modulo/mul** (not in the operator set) → no div-by-zero.
- **All loops bounded** by a small compile-time constant (≤ 8 iters); the only infinite loop is the
  terminal `for(;;){}` AFTER `corpus_result` is stored.
- **No uninitialized reads** — every local is assigned before use.

The host evaluator and the C emitter walk the **same AST**, so their semantics cannot drift.

## Increments (highest-leverage first; each a separate commit)

### Increment 1 — differential fuzz harness (main deliverable)

- `tools/a16_fuzz.py` — a seeded generator that builds a random AST over a handful of `volatile`
  globals + locals of mixed width (`unsigned short` / `short` / `unsigned char` — the 8/16 interleave
  is the coalescer trigger), using `+ - & | ^ << >> == != < <= > >=`, assignments, `if`/`else`,
  bounded `for` loops, `noinline` function calls, and arrays/pointers, ending in `corpus_result`. It
  emits the `.c` AND computes the host-expected value from the same AST.
- An orchestration driver (in the same script) that, per program: compiles default + `+mos-a16` with
  the from-source toolchain, runs default@MAME / a16@MAME / a16@bsnes-jg, compiles `+mos-a16` under
  `-verify-machineinstrs`, and asserts all four values agree + no crash.
- On any mismatch/crash: save `seed-NNNN.c` + seed + both disasms + the verify log to a triage dir
  (`build/fuzz-triage/`) and print a minimal repro (`dev/run.sh fuzz 1 <seed>`).
- `dev/fuzz.sh` + `dev/run.sh fuzz [N] [seed]` dispatch; reports pass/fail counts.

### Increment 2 — realistic kernels (committed deterministic regression tests)

Small but real algorithms as `examples/65816/k_*.c` + `dev/k_*.sh`, each with a deterministic
`corpus_result` verified `host == default == +mos-a16` on BOTH emulators + `-verify-machineinstrs`
clean. Chosen to hold MANY 16-bit values live at once and interleave 8/16-bit width (the coalescer
trigger): CRC16, a fixed-point 16-bit multiply, an xorshift16 / LCG PRNG iterated N times, popcount +
bit-reverse, saturating add, a small insertion sort + memcpy/memset loop. Correctness/no-crash across
a realistic program is the point (disasm gate optional).

### Increment 3 — combinatorial mixing (a few committed tests)

Single functions that combine several s16 features at once — compares + shifts + chains + calls +
spills in one body — to stress the interactions the isolated micro-tests miss.

## Verification

Run for each increment; paste raw output + PASS/FAIL back here. (All emulator runs on a quiet box —
heavy concurrent docker/MAME load flakes the settle window; see F1.)

1. **Fuzzer runs clean at volume.** `dev/run.sh fuzz 50 1` → every non-XFAIL program PASS
   (host==default==a16 on both emulators), zero mismatches / new crashes / errors; XFAILs match the
   documented `cmp-value-selectimm` signature (F3).

   ```
   ==> fuzz: 42/50 PASS, 8 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
   # the 5 seeds that hung pre-F1-fix (6,20,37,39,47) now PASS: 0x64F2 0x8708 0xF275 0xC552 0xDB07
   # xfail seeds (stable): 1 7 9 11 22 35 41 44  — the F3 SelectImm known issue
   ```
   **PASS.**

2. **Fuzzer is reproducible.** Same seed → byte-identical program; the XFAIL set is identical across
   runs (the pre-fix run and the post-fix run both flag seeds 1,7,9,11,22,35,41,44).
   **PASS.**

3. **Fuzzer detects real faults.** Stronger than a planted control: at volume it surfaced **three**
   genuine `+mos-a16` defects (F1 hang, F2 CRC miscompile, F3 SelectImm crash) — each delta-reduced to a
   committed repro; F1/F2 fixed in the backend with regression tests, F3 XFAIL-classified into
   `build/fuzz-triage/known/`. The differential gate caught F2 as a value mismatch
   (`a16@MAME=0x036D ≠ host=0x29B1`) and the `-verify-machineinstrs` gate caught F1/F3.
   **PASS.**

4. **Kernels pass on both emulators.** `k_crc16` 0x29B1 · `k_fxmul` 0x0020 · `k_prng` 0xE00F ·
   `k_bits` 0x4223 · `k_satadd` 0xFFFF · `k_isort` 0xF47A — each RESULT: PASS (host==default==a16,
   MAME==bsnes, verify clean). **PASS.**

5. **Combinatorial tests pass on both emulators.** `a16mix1` 0xE50D · `a16mix2` 0xF0C0 — RESULT: PASS.
   **PASS.**

6. **Non-breaking.** `dev/run.sh corpus` → 7/7; the full a16 suite + new tests = **40/40 green** on a
   quiet box (32 a16* micro-tests + `a16ashift8` + 6 kernels + 2 combinatorial); two `vendor/` backend
   fixes (F1, F2) captured — `dev/regen-patch.sh` round-trips (`0002`, 20 files). **PASS.**

   ```
   ==== a16+kernels suite: 40 PASS, 0 FAIL ====
   ==> corpus: 7/7 passed
   RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
   ```

## Findings

The corpus did its job: at volume it surfaced **three distinct, real `+mos-a16` backend defects**
(two fixed here with committed regression tests; one minimized + deferred), plus a harness robustness
gap under heavy concurrent load. Each was reproduced and root-caused — none hand-waved.

### F1 — arithmetic right shift by ≥ 8 hangs the compiler (FIXED — backend)

The first `dev/run.sh fuzz 50 1` reported 5 `TimeoutExpired(…, 120)` on the `+mos-a16` verify compile
(seeds 6, 20, 37, 39, 47). This was **not** an environmental flake: it minimizes to a deterministic,
standalone **compiler hang**.

- **Reproduced on a 2-line program, pre-fix.** `r = (unsigned short)((short)g >> 8)` does **not**
  terminate (`>240 s`, killed); `>> 7` compiles in <0.1 s. The boundary is exact — amounts **1–7**
  (the native ASHR path) and **all** unsigned `>>` are fast; signed `>>` by **≥ 8** hangs. The default
  (non-`+mos-a16`) build of the same source compiles in 0.04 s.
- **Root cause** (`MOSLegalizerInfo.cpp`, `legalizeShiftRotate`): the `Amt >= 8` byte-decomposition
  path computes the ASHR sign-fill byte by building an s16 `ICMP_SLT(Src, 0)`. Under `+mos-a16` that
  re-enters the native signed-compare legalization (the `SLT → ULT` sign-flip rewrite) as a
  **compare-result-as-VALUE** (it feeds a `SExt`, not a branch), and the legalizer loops.
- **Fix:** compute the sign fill with a pure 8-bit `AShr(highByte, 7)` broadcast — equivalent, and it
  never builds an s16 compare. All five hang-seeds (and the minimal repros) now compile in <0.1 s with
  correct results. Regression test: `examples/65816/a16ashift8.c` → `dev/run.sh a16ashift8` PASS
  `0x001F` on both emulators (negative + positive operands, amounts 8 and 13).

**Harness defense-in-depth (complementary, `tools/a16_fuzz.py`).** Independently of F1, heavy
*concurrent* docker + MAME load can stretch a normally-sub-second compile — or a MAME settle window —
past budget (observed: running the full suite in the background *while* rebuilding the toolchain and
running individual tests made four already-passing tests spuriously FAIL; all four PASSed when re-run
on a quiet box). So `_run` retries a timed-out toolchain command, and `verify_machineinstrs` surfaces a
**persistent** timeout (every retry) as a triaged CRASH ("possible backend infinite loop") rather than
a swallowed `ERROR` — a genuine future hang is still caught, transient load is absorbed. **Run the
suite on an otherwise-quiet box for clean MAME results.**

### F2 — 16-bit `asl`/`lsr` clobber the branch carry → CRC miscompile (FIXED — backend)

The `k_crc16` kernel exposed the most dangerous class — a **silent miscompile**: `+mos-a16` computed
`0x036D` where the correct CRC16-CCITT("123456789") is `0x29B1`, and **both emulators agreed on the
wrong value** (so it is deterministic codegen, not an emulator quirk).

- **Minimized** to a single conditional-XOR step: `if (crc & 0x8000) crc = (crc<<1) ^ 0x1021;
  else crc = crc<<1;` → default `0x3449`, `+mos-a16` `0x2468` (= `crc<<1` with the XOR dropped).
- **Root cause** (disassembly): the common `crc << 1` is hoisted above the branch; the `+mos-a16`
  16-bit `asl` (`ASLAcc16`) lands **between** the `cmp` that sets the branch carry and the `bcs` that
  reads it — and `asl` clobbers carry (carry := bit 15 of `crc`), flipping the branch. `ASLAcc16` /
  `LSRAcc16` did **not** model their carry clobber, so the scheduler placed them in a live-carry
  interval. (`RORAcc16` already models carry via an operand; `INCAcc16`/`DECAcc16` correctly do *not*
  clobber `C`.)
- **Fix** (`MOSInstrLogical.td`): `let Defs = [C]` on `ASLAcc16` and `LSRAcc16`. `k_crc16` → `0x29B1`
  on both emulators; the native shift tests (`a16shift`, `a16ashift`, `a16ashift8`) are unaffected.

### F3 — compare-result-as-value `SelectImm` crash (DEFERRED → XFAIL, tracked)

~16 % of fuzz seeds crash the `+mos-a16` verify compile (and segfault link-time codegen): a 16-bit
compare result consumed as a cross-block i1 **value** (a stored bool / PHI under branchy control flow)
is materialized via `SelectImm $a16, -1, 0` (or `$y`) — a GPR where the pseudo requires a Flag (NZ/C)
register → "Illegal physical register for instruction". This is squarely the **already-tracked**
compare→stored-bool / select-NZ-lowering follow-up (TODO M2 item c) — a non-trivial flag-lowering
change beyond the ~3-attempt budget, so it is **deferred** to that track, not fixed here. Minimized
repro committed at `examples/65816/known/a16-cmp-value-selectimm.c`; the fuzzer classifies this exact
signature as **XFAIL** (known issue), so the suite stays green on the rest of the (vast) space while
new/unmatched crashes and all value mismatches remain hard failures.

## Out of scope / deferred

- A Python fault-injection mode beyond the negative control (not needed — the seed corpus is the
  fuzz volume).
- Backend fixes: if the corpus surfaces a crash/miscompile, minimize → root-cause → fix with the repro
  committed as a regression test, OR document as a known issue for Tier 2 (revert cleanly if no fix in
  ~3 attempts).
