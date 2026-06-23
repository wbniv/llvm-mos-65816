# #321 — verify 32-bit `long`/`int32_t` support (micro-test + builtin-fuzzer 32-bit track)

**Date:** 2026-06-23 · **Issue:** #321 (M2) · **Worktree:** `wt/321-s32-verify`
(`/home/will/SRC/llvm-mos-65816-s32-verify`, hardlink/non-compiler — no `vendor/` change, no toolchain
rebuild) · **Status:** ✅ **DONE + verified** (both deliverables built; §4 has the pasted evidence —
`a16s32` 4-way PASS, builtin `--s32` fuzz 40/40, no-flag byte-identical).

Builds two complementary verifications of the existing 32-bit support (no compiler change): **(1)** a
dedicated value-level **differential micro-test** `a16s32`, and **(2)** a **32-bit track in the builtin
differential fuzzer** so the *deterministic* 4-way oracle exercises `long` (today only the non-deterministic
csmith does).

---

## 0. What "32-bit support" already is (the thing under test)

Under `+mos-a16` an `s32` (`long`/`int32_t`) is **2×s16** (`MOSLegalizerInfo.cpp`): wide ops narrow to s16,
with `customFor` **4×s8↔s32** (un)merge glue (`legalizeMergeS32FromBytes` / `legalizeUnmergeS32ToBytes`) for
the byte-split shapes the artifact combiner can't fold, and **libcalls** for mul/div/variable-shift
(`{S8,S16,S32,S64}`). The **default** (non-a16) 8-bit build also supports `long` (byte-wise). 32-bit far
pointers (`PF`) reuse the same `s32` machinery.

**Measured shape (2026-06-23, `+mos-a16`):** `uint32_t` add → `adc` chain; `*` → `__mulsi3` libcall;
`>>` → libcall/byte-extract; all bracketed by one `rep`/`sep`. `-verify-machineinstrs` clean. Target widths
confirmed: `int`=2, `long`=4, `long long`=8, `int32_t`=4.

**Current coverage & the gap** (why this work):

| Layer | 32-bit? | |
|---|---|---|
| Csmith fuzzer (`dev/run.sh fuzz`) | ✅ emits real `int`/`long` — *found* the `a16-unmerge-s32` bug | non-deterministic; seeds SKIP |
| c-torture (`dev/run.sh torture`) | ✅ 34/1230 in-scope use `long` | broad, not s32-focused |
| **Builtin fuzzer** (`--gen builtin`, the deterministic 4-way oracle) | ❌ `CTYPE` is only `u8/s16/u16` | **gap → deliverable (2)** |
| **Micro-tests** (`a16<name>.c`) | ❌ none for s32 values (`a16unmerge` is a frozen `.ll`) | **gap → deliverable (1)** |

---

## 1. The verification bar (unchanged)

Project differential: **host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg**, plus `-verify-machineinstrs` clean. Unlike the far tests (a16-only), s32 has a
**default leg** (`long` works 8-bit), so this is a full 4-way differential — stronger.

**The 32-bit oracle hazard (the crux for both deliverables).** `short` is 16-bit on host *and* target, which
is why the existing fuzzer uses it. `int`/`long` are **not** 32-bit on both (target int=16/long=32;
typical host int=32/long=64). So:
- The micro-test uses **`uint32_t`/`int32_t`** (exactly 32-bit on both) and computes its expected constant by
  **exact 32-bit wrapping** semantics, documented inline.
- The builtin fuzzer's oracle is a **Python evaluator** (not a host-compiled binary), so it is exact by
  construction — but the **emitted C** must force 32-bit arithmetic with explicit `(uint32_t)`/`(int32_t)`
  casts (mirroring how every existing node casts to `(unsigned short)` to force 16-bit), and the eval must
  mask with a new `u32()`/`to_s32()`. Integer promotion: `int32_t` has rank ≥ `int` on both, so pure-`int32_t`
  expressions aren't promoted away — but mixed sub-int operands must be cast up explicitly.

---

## 2. Deliverable (1) — `examples/65816/a16s32.c` + `dev/a16s32.sh`

A `volatile uint32_t corpus_result` (the harness derives the 4-byte read width from the `.map` symbol size —
confirmed `run_assert` uses `size`), folding in every s32 hazard so a wrong byte anywhere flips the result:

| Sub-result | Exercises (legalizer path) |
|---|---|
| `a + b`, `a - b` (32-bit) | the **2×s16 carry chain** across the 16-bit boundary |
| `(uint32_t)byte << 24 \| …` assembled from `uint8_t`s | **4×s8→s32 merge** (`legalizeMergeS32FromBytes`) |
| `a + 1`, `a >> 8`, byte-extract `(uint8_t)(a>>16)` | **s32→4×s8 unmerge** (`legalizeUnmergeS32ToBytes`) |
| `a << 5`, `a >> 5` (logical), `(int32_t)a >> 5` (arith) | shift legalization (const; ≥8 special) |
| `a * b` | **`__mulsi3` libcall** path |
| `a / b`, `a % b` (constants chosen to avoid /0) | `__udivsi3`/`__umodsi3` libcall |
| `(a == b)`, `((int32_t)a < (int32_t)b)` as values | s32 compare-as-value (signed + unsigned) |
| sign/zero extend: `(uint32_t)(uint16_t)x`, `(int32_t)(int16_t)y` | s16→s32 ext |

Operands are `volatile` globals (laundered, so nothing folds to a constant). `corpus_result` =
a fixed reduction (XOR/rotate-mix) of all sub-results so **all 32 bits matter**; the expected value is
hand-computed with exact 32-bit wrapping and written into `dev/a16s32.sh` as `WANT=0x........` with the
arithmetic shown.

`dev/a16s32.sh` (model on `dev/a16eqval.sh`), gates:
1. **build both** default *and* `+mos-a16` with `-mllvm -verify-machineinstrs` → clean.
2. **disasm gate (a16):** the s32 path is present — a `rep`/`sep` bracket + `adc` chain + `__mulsi3`
   (and shift/div libcalls); confirms the value really went through the 2×s16/libcall machinery, not
   constant-folded.
3. **execution differential:** `corpus_result == WANT` for **default** *and* `+mos-a16` on MAME, host
   constant matches; bsnes-jg via `dev/xcheck.sh`. Close with `emu_verdict`.

Wire into `dev/run.sh` (dispatch + usage) and `dev/xcheck.sh` (build_rom + xassert, both default and a16
legs as the other a16 tests do).

---

## 3. Deliverable (2) — 32-bit track in `tools/a16_fuzz.py` (builtin generator)

The builtin generator is rigidly 16-bit (every node emits `(unsigned short)`, evals through `u16()`). Rather
than thread a width dimension through the whole `Expr` tree (high risk to the proven 16-bit fuzzer that
guards everything), add an **additive, self-contained 32-bit block**:

- **`u32(v)` / `to_s32(v)`** masking helpers (alongside `u16`/`to_s16`).
- **A `gen_s32_block()`** emitted into each generated `main()` (under a generator flag / probability): declare
  a few `volatile uint32_t`/`int32_t` vars seeded from the existing 16-bit state (zero/sign-extended), run a
  short straight-line sequence of 32-bit `+ - & | ^ << >> *` (and a guarded `/`), then **fold the 32-bit
  accumulator into the existing `corpus_result`** (XOR its two halves in). Emission uses explicit
  `(uint32_t)`/`(int32_t)` casts; a parallel exact evaluator (`u32`/`to_s32`) computes the oracle
  contribution.
- **`#include <stdint.h>`** added to the generated preamble.
- The 32-bit block is **gated** (e.g. `--s32` flag and/or a per-seed probability) so existing 16-bit seeds
  are byte-identical unless 32-bit is requested — preserving every current builtin/known-issue gate. Default
  off for `known-issues`/regression replays; on for a new `fuzz --gen builtin --s32` sweep.

This keeps the 4-way oracle (Python-eval == default == a16 == xy16) intact and reproducible, now covering the
2×s16 carry, the 4×s8↔s32 (un)merge, shifts, and the `__mulsi3`/`__udivsi3` libcall paths.

---

## 4. Verification steps

Run on the worktree `wt/321-s32-verify` (hardlinked toolchain; QUIET box for MAME). **All PASS 2026-06-23.**

1. **Micro-test 4-way — PASS.** `dev/run.sh a16s32`:
   ```
   ==> host-oracle cross-check: WANT=0x50F2B870 confirmed (0x50F2B870)
     PASS: both builds -verify-machineinstrs clean
     PASS: __mulsi3 / __udivsi3 / __umodsi3 libcall present;  PASS: 19 rep (s32 went native-16)
   ==> 4) MAME: default: got=0x50F2B870 (len=4) ;  +mos-a16: got=0x50F2B870 (len=4)
   ==> 5) bsnes-jg: got=0x50F2B870
   RESULT: PASS — corpus_result==0x50F2B870 host==default==+mos-a16 (both emulators)
   ```
   Full 4-way (host==default==a16, both emulators); the 32-bit/4-byte `corpus_result` round-trips.

2. **Builtin fuzzer 32-bit, deterministic — PASS.** `dev/run.sh fuzz --gen builtin --s32 40 1`:
   ```
   ==> a16 differential fuzz: 40 program(s), seeds 1..40  [+32-bit track]
   ==> fuzz: 40/40 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
   ```
   The deterministic 4-way oracle (Python-eval == default == a16 == xy16 on MAME) now exercises the s32
   path; all agree. (Lockstep also host-cross-checked: a host compile of the generated `--s32` program
   matched `expected()` for seeds 1..12.)

3. **Builtin fuzzer unchanged without the flag — PASS.** `dev/run.sh fuzz --gen builtin 40 1` → `40/40 PASS,
   0 mismatch`; and `a16_fuzz.py gen --seed N` is **byte-identical** to the pre-change generator for
   N=1..30 (the s32 draws are gated, so the rng stream and emitted 16-bit program are untouched).

4. **Regression:** `--s32` rejected for `--gen csmith` (builtin-only guard, verified). `corpus` is unaffected
   by this test/tooling-only change (no `vendor/`, no compiler change) — corpus **7/7** was confirmed on
   main's real toolchain during the prior far-tail land; it is not re-run here because this hardlink worktree
   has no built example ROMs (`dev/run.sh build` would write the hardlinked `build/install`).

---

## 5. Scope / non-goals

- **In scope:** value-level verification of the *existing* s32 codegen (no `vendor/` change). The micro-test
  + the deterministic fuzzer track.
- **Not a compiler change:** if either surfaces a *new* miscompile, that becomes its own `vendor/` fix on a
  compiler worktree (this plan only adds tests/tooling).
- **Not full-width fuzzer refactor:** the 32-bit fuzzer track is an additive block, not a width dimension
  through every `Expr` (deliberately bounded to protect the 16-bit core).
- **s64 (`long long`):** out of scope (libcall-only; no native path to stress).

---

## 6. Land / commit

Tracked files only (`examples/65816/a16s32.c`, `dev/a16s32.sh`, `dev/run.sh`, `dev/xcheck.sh`,
`tools/a16_fuzz.py`, this plan, `TODO.md`). No `vendor/`. Commit on `wt/321-s32-verify`, then merge to `main`
(orthogonal to the other agent's `0008`), push. Worktree retained per policy.
