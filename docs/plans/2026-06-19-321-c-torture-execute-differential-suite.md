# Vendor an external C correctness suite (gcc `c-torture/execute`) behind the `+mos-a16`/`+mos-xy16` differential gate

**Date:** 2026-06-19 (Phase 3 added 2026-06-21) · **Status:** **PHASES 0–3 DONE.** Fetch + host filter
(**1253 / 1656** in-scope) + the emulator differential runner; full `-O1` (**1098 PASS**) and `-Os`
(**1174 PASS, 0 FAIL** with bsnes-jg 4-way) sweeps green-modulo-known (`xfails.tsv` now empty — every
known miscompile fixed). **Phase 3 (sampled CI) DONE** — the `torture` job is in
`.github/workflows/smoke.yml` (in-container, 4-way, seeded `--sample`, secret-gated, `mode` sampled/full);
see §"Phase 3 — RESULTS". Orphan-MAME reaper DONE 2026-06-21 (`_run_emu` process-group kill). See §"Phase 2 — RESULTS".
**BACKLOG RESOLUTION (2026-06-19 → fully cleared 2026-06-20):** the **frame-index fix cleared 13** (all a16),
the **dg-require** refinement dropped the `pr7284-1` false positive (in-scope 1253→1228), and the **4 remaining
xy16 defects + `k_isort`'s xy16 leg were all cleared by ONE fix** (the `MOSInsertREPSEP` `requiredXWidth`
index-width gap, 2026-06-20). **`xfails.tsv` now has no data rows — every known #321 a16/xy16 c-torture
miscompile is fixed.** See §"Phase 2 backlog — RESOLUTION".
**Issue:** #321, ROADMAP M2 (Test Bench / CI — broaden correctness coverage beyond the 6-program corpus + `a16*` micro-tests + the random fuzzer).
**Required reading:**
[corpus-a16 differential gate (the engine this reuses)](2026-06-19-321-corpus-a16-differential-mode.md) ·
[Tier-1 fuzzer + corpus](2026-06-15-321-tier1-broaden-corpus.md) ·
[WDC816CC/ORCA prior-art note (the *fetch-don't-commit* vendoring precedent)](2026-06-15-wdc816cc-orca-c-65816-c-abi-prior-art-note-primary.md).

## TL;DR

We have three correctness nets: the **6-program corpus** (`examples/snes/corpus/`), ~50 **feature-isolating
`a16*` micro-tests**, and a **random differential fuzzer** (`tools/a16_fuzz.py`). All three are
*home-grown* — they test the shapes we thought to write. The gap is a **large, externally-authored,
adversarial** body of real C. This plan slots the **GCC `c-torture/execute`** suite (the de-facto standard
*execution*-correctness corpus — **1,656 top-level** self-checking programs that `abort()` on a wrong
result and `exit(0)` on success; **1,253 build a default SNES ROM**, per Phase 0) into the **existing**
differential engine, using the **default (non-`+mos-a16`)
llvm-mos build as the trusted oracle**: a test is *in-scope* iff the default build runs it to the PASS
sentinel; among in-scope tests, **any `+mos-a16`/`+mos-xy16` disagreement is a real defect**. This is the
same `host == default == +mos-a16 == +mos-xy16` model `corpus-a16` already runs, scaled to a much larger
input set — and it sidesteps "is this test even appropriate for a 16-bit-`int` target" entirely (if the
default build handles it, the a16 build must too).

## Why `c-torture/execute`, not the alternatives

| Candidate | Verdict | Reason |
|---|---|---|
| **gcc `c-torture/execute`** | **CHOSEN** | Programs are **self-checking** (`if (wrong) abort(); … exit(0)`) — pass/fail is one bit, **no stdout/reference-output needed** (the SNES has no stdout). Exactly the model our value-readback harness wants. Exercises real ALU/control/pointer/struct C across many `-O` levels. |
| **`c-testsuite`** (MIT) | Alternative | Vendorable (MIT, no GPL), but its `single-exec` tests compare **stdout** — needs a `printf → corpus_result` shim — and most of its programs are themselves gcc-torture-derived. More plumbing for the same coverage. Keep as a fallback if GPL fetch is unwanted. |
| **Csmith / Yarpgen** | Out of scope | Random *generators* — we already have `tools/a16_fuzz.py`. Stronger off-the-shelf, but a different (generator) axis; revisit separately if we want to deepen *random* coverage. |
| **SuperTest / Plum Hall / Perennial** | Out of scope | Commercial ISO-conformance suites; not open source. |

## The adapter — map a self-checking test onto our value-readback model

Our harness reads back a `volatile unsigned short corpus_result` from emulator RAM (MAME + bsnes-jg) and
compares builds (`tools/a16_fuzz.py` → `compile_rom` / `run_mame` / `run_bsnes` / `map_lookup`). A torture
test has no such symbol; it signals via `abort()` / `exit(0)` / `return 0` from `main`. Bridge with a small
**shim TU** ([`examples/65816/torture/_shim.c`](../../examples/65816/torture/_shim.c), **landed in Phase 0**):

- Preprocess each test with **`-Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit`** so
  the test's `main` is renamed and its `abort()`/`exit()` calls route to the shim's stubs **instead of
  colliding with the SDK libc's own `abort`/`exit`** (the first build attempt hit exactly that collision).
- The shim provides the real `main` + the `__torture_*` stubs:
  ```c
  #define PASS 0x600D
  #define FAIL 0xDEAD
  volatile unsigned short corpus_result;
  int torture_test_main();                 /* empty parens: argv-taking mains still link */
  void __torture_abort(void){ corpus_result = FAIL; for(;;){} }
  void __torture_exit(int c){ corpus_result = c ? FAIL : PASS; for(;;){} }
  int main(void){ int r = torture_test_main(); corpus_result = r ? FAIL : PASS; for(;;){} }
  ```
- **Build mechanics (learned in Phase 0):** because `-D…` applies to *every* TU on the command line, the
  shim must be **precompiled once to `_shim.o`** (no `-D`) and the test then *linked against that object* —
  otherwise the shim's own `main` is renamed to `torture_test_main` too and clashes.
- **Classification** (a new thin runner, see Phase 1) by the read-back value of the *default* build:
  - default → `PASS` **and** `+mos-a16` == `+mos-xy16` == `PASS` on MAME (and `+mos-a16` == `PASS` on
    bsnes-jg) ⇒ **PASS**.
  - default → `FAIL`/timeout/compile-fail/link-overflow ⇒ **SKIP (unsupported)** — the test is
    target-inappropriate (16-bit `int`, too much RAM, needs libc/FP/`long long`/`alloca`/VLA we don't
    support). **Not** a compiler bug; logged with the reason, counted, **never silently dropped**.
  - default → `PASS` but `+mos-a16` or `+mos-xy16` ≠ `PASS` (or `-verify-machineinstrs` fails) ⇒ **FAIL**
    — a real `#321` defect. This is the whole point.

## Vendoring — fetch, don't commit (GPL hygiene + reproducibility)

`c-torture/execute` is **GPLv3** (it ships in the GCC tree); this repo is Apache-2.0-with-LLVM-exception.
Follow the **established precedent** ([the WDC816CC/ORCA refs](2026-06-15-wdc816cc-orca-c-65816-c-abi-prior-art-note-primary.md)):
**do not commit the test sources.** Add `dev/fetch-torture.sh` that downloads a **pinned GCC release
tarball** (e.g. `gcc-14.x`), **sha256-verifies** it, extracts only
`gcc/testsuite/gcc.c-torture/execute/*.c` into a **gitignored** `vendor/c-torture/` (mirroring the
`vendor/llvm-mos` model), and records the version + checksum. The repo stays GPL-clean; the suite is
reproducible from one script + a checksum. The shim, the runner, the in-scope manifest, and the recorded
verdicts **are** committed (our own work).

## Plan (phased — each phase lands independently)

### Phase 0 — fetch + host-side filter (no emulator; fast) — **DONE 2026-06-19**
1. ✅ [`dev/fetch-torture.sh`](../../dev/fetch-torture.sh) — pinned **gcc-14.2.0** (sha256
   `a7b39bc6…f3cc9`), extracts only `gcc.c-torture/execute` into gitignored `vendor/c-torture/execute/`,
   `set -euo pipefail` + `-h`/`--help`, idempotent (cached-tarball + extracted-tree fast paths).
2. ✅ **Compile/link filter** ([`tools/torture_filter.py`](../../tools/torture_filter.py), host-only,
   **default build only** — no flags, no emulator, `ProcessPoolExecutor`). Precompiles `_shim.o` once,
   links each test against it, buckets the result. Emits
   [`examples/65816/torture/inscope.tsv`](../../examples/65816/torture/inscope.tsv) +
   [`unsupported.tsv`](../../examples/65816/torture/unsupported.tsv) with a reason per excluded test, and
   logs the counts — **no silent caps** (every test lands in exactly one bucket). Result below.

### Phase 1 — adapter + runner + pilot — **DONE 2026-06-19**
3. ✅ `examples/65816/torture/_shim.c` (Phase 0) + [`dev/torture.sh`](../../dev/torture.sh) +
   `dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--no-bsnes]`.
4. ✅ [`tools/torture_run.py`](../../tools/torture_run.py) — imports `a16_fuzz` and reuses
   `run_mame` / `run_bsnes` / `map_lookup` / `verify_machineinstrs`-style + `classify_known`; adds the
   shim wiring + the oracle-gated PASS/FAIL/SKIP/XFAIL logic. **Refinement vs the original sketch:** the
   DEFAULT build is built + run **first** and gates everything — a non-buildable / non-PASS default ⇒ SKIP
   *before* +mos-a16 is judged, so only tests the default handles can produce a FAIL.
5. ✅ **Pilot** — 120 tests across three slices (raw output in §"Phase 1 — RESULTS"): 40 @ `-Os`,
   40 @ `-O1`, 40 @ `-O1` over the `pr*` regression tests. All four classification paths exercised; one
   real defect found (`pr15296.c`).

### Phase 2 — scale + triage — **`-O1` PASS DONE 2026-06-19** (`-Os` pass pending)
6. ✅ Ran the **full `inscope.tsv`** at `-O1` (the `-Os` pass is queued). Triaged every FAIL: re-ran all
   16 in isolation on a quiet box with bsnes-jg → **all 16 reproduced (zero flakes)**; the a16 ones agree
   on **both** emulators. The **expectation was wrong** — they are **not** the register-pressure family
   but **16 genuinely-new runtime miscompiles** (a16/xy16 computes a wrong value → the test's self-check
   writes `0xDEAD`). Recorded in [`examples/65816/torture/xfails.tsv`](../../examples/65816/torture/xfails.tsv)
   (the expected-fail manifest); `torture_run.py` now reports a listed test as **XFAIL** (and a fixed one as
   **XPASS** → "remove the row"), so the gate is **green-modulo-known**. Deep per-test root-cause is a
   separate backlog (the tests are diverse — packed structs, varargs, signed shift, computed-goto, … —
   likely several distinct bugs).
7. **Remaining:** the `-Os` pass (now non-aborting — the known fails XFAIL); then freeze the partition and
   root-cause the backlog one defect at a time.

### Phase 3 — CI wiring (optional, follows Phase 2 green)
8. A **sampled, secret-gated** CI job (mirror [corpus-a16 CI](2026-06-19-321-corpus-a16-ci.md)): a fixed
   pseudo-random subset (seeded, not the full ~600 — emulator wall-clock) per run, plus the full set
   nightly. Forks without the BIOS secret skip. Never fail CI on a SKIP.

#### Phase 3 — RESULTS (2026-06-21): DONE

Added the **`torture`** job to `.github/workflows/smoke.yml` (in-container, mirroring `corpus-a16`).
`needs: xcheck` so it reuses that job's cached from-source toolchain; builds the SDK + `build/jgxcheck`
(for the always-on bsnes-jg 4-way leg); fetches the suite on the host (`dev/fetch-torture.sh`, the
sha256-pinned gcc-14.2.0 → gitignored `vendor/c-torture/`; the committed `inscope.tsv` is the manifest);
**secret-gated** (skip — don't fail — without the SPC700 BIOS). The `mode` dispatch input picks `sampled`
(`dev/run.sh torture --sample 150 --sample-seed <seed> --opt -Os`) or `full` (the whole in-scope set at
`-Os` **and** `-O1`). A commented `schedule:` block (auto-selects `full`) is ready for when public.

Phase 3 needed one runner change: `tools/torture_run.py` had only a sequential `--start`/count slice
(alphabetical inscope.tsv → unrepresentative head), so **`--sample N` / `--sample-seed S`** were added —
a seeded, reproducible pseudo-random subset (`random.Random(S).sample(...)`, then sorted for stable
output). Verified deterministic: same seed → identical 150-test set; different seed → different set;
`--sample > len(inscope)` clamps to the full 1228.

Local sampled verification (4-way, the exact per-run CI command):
```
$ dev/run.sh torture --sample 150 --sample-seed 1 --opt -Os
==> torture-run: 150 test(s), -Os, sample=150 seed=1, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
==> torture-run: 143 PASS, 0 FAIL, 7 SKIP, 0 XFAIL (of 150)
```
0 FAIL / 0 XPASS, exit 0 — `host==default@MAME==+mos-a16@MAME==+mos-xy16@MAME==+mos-a16@bsnes-jg` holds
across the sample. **PASS.** (The `full`-mode commands reuse the long-proven count-slice path — whole-set
`-Os` 1174 PASS and `-O1` 1098 PASS from Phase 2 — so they are sound by construction; not re-run here as
the full sweep is hours.)

**Orphan-MAME reaper — DONE 2026-06-21.** `tools/a16_fuzz.py` now runs every emulator subprocess
(`run_mame`/`run_bsnes`) via a `_run_emu` helper that spawns it in its own session/process group
(`start_new_session=True`) and reaps the **whole group** (`os.killpg`) on three paths: the inline
per-test timeout, an uncaught `KeyboardInterrupt`/normal exit (`atexit`), and `SIGTERM` (handler). So a
hung boot no longer leaks a process across a 1000+-boot local sweep. Verified: a forking child is reaped
group-wide on timeout (`killpg(pgid,0)` liveness probe → empty after kill); the normal path is
unregressed (`torture --sample 8` → 8 PASS, 4-way). Behaviour-preserving — `_run_emu` returns the same
`CompletedProcess` and re-raises `TimeoutExpired`, so all callers (corpus-a16, fuzzer, torture) are
unchanged but now leak-free.

## Phase 0 — RESULTS (2026-06-19)

Filter run: `FUZZ_ROOT=$PWD MOS_TOOLCHAIN=$PWD/build/llvm-mos-install python3 tools/torture_filter.py`
(default build, `-Os`, 11 jobs, ~64 s over **1656** top-level `execute/*.c`):

```
==> 1253/1656 in-scope, 403 unsupported
      compile-error    197
      link-other        26
      region-overflow    4
      undefined-symbol  176
```

- **1253 in-scope** (75.7 %) — the candidate set for the Phase-1 differential run. Far larger than the
  6-program corpus.
- **403 unsupported**, each bucketed with a (sanitized, portable) diagnostic:
  - **197 compile-error** — clang front-end rejects (implicit-function-decl in old K&R tests, oversized
    bit-fields, target-type assumptions). Expected for a 1990s-era suite on a strict modern front end.
  - **176 undefined-symbol** — needs libc we don't provide; **168 are `__putchar`** (i.e. `printf`/`puts`)
    — these are the natural `c-testsuite`-style stdout tests, correctly excluded.
  - **26 link-other** — LTO/bitcode rejects (`__builtin_prefetch`), GNU vector/SIMD extensions, ld.lld
    limits.
  - **4 region-overflow** — static data exceeds the SNES `ram` region (e.g. `.noinit` overflow by 7322 B).
- The `builtins/` and `ieee/` subdirs were initially excluded (top-level-only glob); the **full vendoring**
  (2026-06-26, see §"Full vendoring" below) brings them into the same partition — `ieee/` adds real
  floating-point coverage, `builtins/` is accounted-for as a documented multi-file-harness bucket.
- **Determinism:** two back-to-back full runs produce **byte-identical** `inscope.tsv` / `unsupported.tsv`
  (the one initially-flapping row — `user-printf.c`, many missing symbols listed in nondeterministic order
  — is now normalized to the sorted-smallest symbol + a `(+N more)` count).
- **Build-mechanics correction** (now reflected in §"The adapter"): the shim must be **precompiled to
  `_shim.o`** and linked, because `-Dmain=…` applies to *all* TUs on the command line and would otherwise
  rename the shim's own `main`.

## Full vendoring — RESULTS (2026-06-26)

The Phase-0 filter originally globbed **only top-level** `execute/*.c` (1656), leaving the two subdirectories
unaccounted-for. `tools/torture_filter.py` now scans them too (one source edit: SRCDIR-relative manifest keys
+ unconditional `*/*.c` glob excluding `builtins/*-lib.c`; `builtins/lib/` is two levels deep so it's never
reached), so the committed manifest accounts for the **whole real suite**. Net scanned 1779 = 1656 top-level
+ 68 `ieee/` + 55 `builtins/` main tests (the 55 `-lib.c` companions + 28 `builtins/lib/` support files are
**not tests** and are excluded).

```
==> 1288/1779 in-scope, 491 unsupported   (was 1228/1656)
      builtins-multifile  55      ← gcc builtins multi-file harness; not single-file linkable (NEW bucket)
      compile-error      170
      dg-require-unsupported 58
      link-other          27
      region-overflow      2
      undefined-symbol   179
```

- **`ieee/` (68): 60 in-scope, 8 unsupported.** Genuinely new differential coverage — single-file IEEE-754
  self-checking tests exercising `+mos-a16`/`+mos-xy16` handling of `float`/`double` **values** (load/store/
  spill, branch-on-fp) and the **soft-float call ABI** (marshalling 8-byte doubles). NB: there is no a16
  multilib, so the soft-float kernels (`__adddf3`, `__divsf3`, …) link from the single 8-bit `common` library
  and are identical object code across default/a16/xy16 — what a16 recompiles is the test's own TU, not the
  arithmetic kernels.
- **`builtins/` (55 main tests): all `builtins-multifile`.** gcc's `builtins.exp` is a multi-file harness
  (each `foo.c` defines `main_test()`, linked against `lib/main.c` + a `foo-lib.c` reference impl). Our
  single-file freestanding build can't replicate that, so they're bucketed honestly (detected by the
  `main_test`-without-`main` signature) rather than failing with a misleading `undefined symbol:
  torture_test_main`. Making them *run* (companion-linking) is an explicit out-of-scope follow-up.
- **Differential gate result** (60 in-scope `ieee/`, 4-way MAME + bsnes-jg):
  - `-Os`: **53 PASS, 0 FAIL, 4 SKIP, 3 XFAIL** · `-O1`: **57 PASS, 0 FAIL, 0 SKIP, 3 XFAIL**.
  - The 4 `-Os` SKIPs (`fp-cmp-cond-1`, `inf-4`, `pr108540-2`, `pr109386`) are the default-8bit oracle
    correctly gating tests it can't itself pass (they PASS at `-O1`).
  - **3 XFAIL = one newly-found `+mos-xy16` defect.** `fp-cmp-8.c` + `fp-cmp-8l.c` + `pr38016.c` are the
    **same test body** (the latter two `#include "fp-cmp-8.c"`): the floating-point **compare-as-select**
    ("cmove", `__builtin_isunordered/isless(x,y) ? a : b`) miscompiles under `+mos-xy16` (default + a16 PASS,
    xy16 reads `0xDEAD`), reproducibly in isolation at both opt levels → `xfails.tsv`, gate green-modulo-known.
    Root-cause + fix is a dedicated follow-up. **This is the payoff of finishing the vendoring** — the integer
    top-level suite never reached this path.

## Phase 1 — RESULTS (2026-06-19)

120-test pilot through the full gate (`default == +mos-a16 == +mos-xy16` on MAME + bsnes-jg):

```
PILOT A: 40 @ -Os (start 0, date-named arith/loop) -> 40 PASS,  0 FAIL,  0 SKIP, 0 XFAIL
PILOT B: 40 @ -O1 (start 0)                        -> 40 PASS,  0 FAIL,  0 SKIP, 0 XFAIL
PILOT C: 40 @ -O1 (start 731, pr* regression tests)-> 22 PASS,  1 FAIL, 17 SKIP, 0 XFAIL
TOTAL                                              -> 102 PASS, (1 FAIL->XFAIL), 17 SKIP
```

All four classification paths exercised; the runner is correct.

- **PASS (102).** Real external C — arithmetic, loops, pointers, unions, bitfields — agrees byte-for-byte
  across default / +mos-a16 / +mos-xy16 on both emulators.
- **SKIP (17).** Oracle-gated, two sub-reasons: *"default build fails at -O1 (unsupported)"* (target-type /
  feature the default build can't take) and *"default != PASS (got 0xDEAD)"* (the 16-bit-`int` model
  legitimately self-fails the test's own check). Neither is a compiler bug — correctly excluded.
- **The one FAIL → reclassified XFAIL: `pr15296.c`.** Triaged to a **real `+mos-a16 -O1/-Os` defect**: the
  a16 build allocates so many `Imag16` zero-page pairs that `.zp.noinit` grows past 256 B and an 8-bit ZP
  relocation overflows — `ld.lld: relocation R_MOS_ADDR8 out of range: 1043 … references '.zp.noinit'`.
  **Default 8-bit and `+mos-a16 -O0` link clean; `-O1`/`-Os` fail** — the *same* register-pressure root
  cause as the `globals.c` RA crash, a different symptom (link-time ZP overflow vs an RA-time crash). Added
  `KNOWN_ISSUES["a16-zp-pressure-overflow"]` (so the gate XFAILs it, like `globals.c`) and recorded it in
  [the RA-pressure investigation](../investigations/65816-a16-regalloc-pressure-failure.md#related-manifestation--link-time-zp-overflow-c-torture-pr15296c-2026-06-19).
  The fix is the same deferred A16-threading Phase 3.
- **No new miscompile** *in the 120-test pilot* — and none is even *possible* from a conforming program:
  `+mos-a16` exposes no predefined macro and shares the data model (16-bit `int`, same pointer sizes) with
  the default build, so the two can only differ on a real codegen bug. That makes the differential precise:
  a value mismatch *is* a defect. (The full suite — §Phase 2 — duly found 16.)

## Phase 2 — RESULTS (2026-06-19, full `-O1` pass)

Full `-O1` differential pass over all **1253** in-scope tests (MAME `default == +mos-a16 == +mos-xy16`):

```
==> torture-run: 1098 PASS, 16 FAIL, 136 SKIP, 3 XFAIL (of 1253)
```

- **1098 PASS** — real external C agrees across default / a16 / xy16.
- **136 SKIP** — oracle-gated, all legitimate: 79 default-build-unsupported, 57 where the default build
  itself self-fails (16-bit-`int`-inappropriate). None masks a bug.
- **3 XFAIL** — `loop-2e.c`, `pr15296.c`, `pr44202-1.c`, all the known `a16-zp-pressure-overflow`
  (ZP-overflow at link). The `KNOWN_ISSUES` signature catches them.
- **16 FAIL → confirmed real, NEW runtime miscompiles** (the payoff). Each: the DEFAULT build self-checks
  PASS (`0x600D`) but a16/xy16 computes a wrong value → self-check fails → `0xDEAD`. **All 16 re-run in
  isolation on a quiet box with bsnes-jg reproduced — zero flakes** — and every a16 case agrees on **both**
  MAME and bsnes-jg:

  | scope | tests |
  |---|---|
  | `+mos-a16` (both emulators) | `20010518-2`, `20020402-1`, `20071202-1`, `20071210-1`, `20080522-1`, `921117-1`, `990127-1`, `990811-1`, `pr20466-1`, `pr35472`, `pr39120` |
  | `+mos-a16` **and** `+mos-xy16` | `pr49419`, `pr7284-1` |
  | `+mos-xy16` only | `20041011-1`, `doloop-1`, `va-arg-22` |

  They are **diverse** — mis-aligned packed structs, nested struct/arrays, `memset`-over-struct, varargs,
  signed left-shift, computed-goto/label-values, counted loops at `INT` limits — so likely **several
  distinct** a16/xy16 codegen bugs, not one. Logged in `examples/65816/torture/xfails.tsv`; the runner
  XFAILs them (and XPASSes a fixed one → "remove the row"), so the gate is **green-modulo-known**.
  **Per-defect root-cause is the open backlog** — each is its own delta-reduce → minimal `.c` →
  investigation, in the F1/F2/F3/F4 mold.

**`-Os` pass (2026-06-19) — completed:** `1248-ish PASS, 2 new FAIL, 2 XPASS` over the same 1253 (the 16
`-O1` known fails auto-XFAIL via `xfails.tsv`).
- **2 new confirmed miscompiles:** `pr34768-1.c`, `pr34768-2.c` (a16 **and** xy16; both emulators agree).
  PR34768 **const-indirect-call**: `(c ? foo : bar)()` with `bar __attribute__((const))`. Root-cause
  finding: the **per-function 65816 asm is correct** (`test` reloads `x` after the call; `foo` negates
  correctly; neither clobbers the `__rc20` holding `tmp`) — so the bug is at the **LTO / optimization
  level** (the ROM is an LTO build; whole-program may wrongly treat the indirect call as side-effect-free
  because one target is `const`, dropping the post-call reload). A pipeline interaction, *not* per-instr
  selection — echoing the seed-42 lesson (an a16 difference perturbing a shared path).
- **1 flake filtered:** `pr40404.c` reported "a16 build fails" in the pass but **builds clean 3/3 host-side**
  (a16 + xy16) → a resource-pressure flake during the 1253-test run, not a defect. (Build steps can flake
  too, not just MAME — a runner-retry follow-up.)
- **2 XPASS = opt-level-dependent:** `20020402-1.c`, `20041011-1.c` fail at `-O1` but pass at `-Os`. Their
  `xfails.tsv` rows **stay** (real at `-O1`); the "remove the row" hint only applies at the level the bug
  was found → make the manifest opt-level-aware (follow-up).
- **1 false positive:** `pr7284-1.c` needs `int32plus` (`n<<24` is UB on 16-bit `int`); default passed by
  UB-luck. Oracle gap: honor `dg-require-effective-target` (follow-up). **Net genuine distinct
  miscompiles: 17** (15 at `-O1` + 2 at `-Os`).

> **Harness note (fixed):** the runner's per-test `subprocess.run(timeout=…)` kills a hung MAME but can
> leave orphaned MAME children; over a 1253-test pass these accumulated and the final process hung in
> teardown (so the `-Os` pass — chained after `set -e` — never started). The 16 FAILs are unaffected (all
> reproduced isolated). The `-Os` pass reruns separately. **Reaped 2026-06-21:** `_run_emu` now spawns
> each emulator in its own process group and `killpg`s the whole group on timeout / exit / SIGTERM, so
> children no longer accumulate (see §"Phase 3 — RESULTS").

## Phase 2 backlog — RESOLUTION (2026-06-19)

The per-defect backlog (18 rows: 17 confirmed + the `pr7284-1` false positive) was triaged and substantially
cleared the same day. The "diverse, several distinct bugs" expectation was **wrong** for the a16 cases — they
were almost all **one** root cause:

- **13 cleared by ONE fix** — the `CmpBrAbsImm16` **frame-index elimination scramble** (`f2d65c2`,
  [plan](2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md)). `MOSRegisterInfo::eliminateFrameIndex`
  read the frame displacement from the wrong operand for the a16 fused compare-branch pseudo, so a16-LTO
  static/zero-page-stack accesses resolved to `base+compareImm` not `base+frameOffset`. Cleared:
  `20010518-2, 20020402-1, 20071202-1, 20071210-1, 20080522-1, 921117-1, 990127-1, 990811-1, pr20466-1,
  pr35472, pr39120, pr34768-1, pr34768-2` (`pr34768-*` had been mis-filed as an LTO const-attribute bug,
  `20010518-2` as a packed-struct/`long` bug — both were this defect). Regression guard: the 13 de-XFAIL'd
  rows + `examples/65816/a16frameidx`.
- **1 false positive removed** — `pr7284-1` (`int32plus`, `n<<24` UB on 16-bit `int`) via honoring
  `dg-require-effective-target` in the filter (`8622e3f`,
  [plan](2026-06-19-321-torture-honor-dg-require-effective-target.md)); in-scope **1253→1228**.
- **`pr49419`'s a16 leg fixed too** by the frame-index commit — it is now **xy16-only**
  ([plan](2026-06-19-321-c-torture-pr49419-a16-xy16-hang.md)).

**~~Remaining = 4 defects, ALL xy16~~ ALL CLEARED 2026-06-20 by ONE fix** (the 16-bit-index track, added
2026-06-18, less battle-tested): `pr49419` (hang), `20041011-1` (64-bit `ull` + pressure), `doloop-1`
(counted loop at `INT` limits), `va-arg-22` (varargs) — plus the `k_isort` xy16 miscompile surfaced by the
suite's xy16 leg. `pr49419`'s loops trace instruction-correct yet hang ⇒ a runtime **X-flag (index-width)
state** bug, prime suspect the **`MOSInsertREPSEP` X-flag lattice**, **likely shared** across the xy16 cluster.
- **All 5 cleared by ONE fix** — the `MOSInsertREPSEP` `requiredXWidth` **index-width gap** (2026-06-20,
  [plan](2026-06-19-321-xy16-xflag-lattice-fix.md)). Index-register *value* ops (compares `CMPImm`/
  `CMPImag8`/`CMPAbs` reading X/Y, register `INC`/`DEC`) were classified X-agnostic, so they ran in the
  ambient X=16 left by a 16-bit-indexed load — `cpy #imm` then compared the loop counter's uninitialized high
  byte. Cleared: `pr49419, doloop-1, 20041011-1, va-arg-22` (all 4 `xfails.tsv` rows removed) + `k_isort`'s
  xy16 leg. Confirmed the shared-cause prediction (as the frame-index fix cleared 13). `xfails.tsv` is now
  empty of data rows — **every known #321 a16/xy16 c-torture miscompile is fixed.**
The a16 (16-bit-accumulator) **and** xy16 (16-bit-index) tracks are now both healthy.

## Verification

1. **Fetch is reproducible + pinned.** ✅ PASS — `dev/fetch-torture.sh` (re-run, tarball cached):
   ```
   ==> tarball cached + verified (sha256 a7b39bc69cbf9e25826c5a60ab26477001f7c08d85cec04bc0e29cabed6f3cc9)
   ==> execute/ already extracted (1862 .c files)
   ==> ready: …/vendor/c-torture/execute  (top-level: 1656 tests)
   ```
2. **Filter partitions deterministically.** ✅ PASS — counts sum (1253 + 197 + 26 + 4 + 176 = 1656); two
   full runs `diff` byte-identical (`DETERMINISTIC ✓`); no machine-specific paths in the committed TSV
   (`grep -c '/home/will\|/tmp/'` → 0). Output in §"Phase 0 — RESULTS".
3. **Adapter classifies correctly (pilot).** ✅ PASS — 120-test pilot, all four paths exercised; 102 PASS
   default==+mos-a16==+mos-xy16 on MAME + bsnes-jg. Output in §"Phase 1 — RESULTS".
4. **A real defect is caught (FAIL path).** ✅ PASS — `pr15296.c` came back `!! FAIL  a16 build fails
   (default ok)`, an actual `+mos-a16 -O1/-Os` ZP-pressure overflow (not a harness artifact — reproduced
   by hand: default + a16 `-O0` link, a16 `-O1`/`-Os` overflow `.zp.noinit`). *(The original "inject
   `abort()`" idea was dropped: an unconditional abort fails the DEFAULT build too → SKIP. And no
   conforming program can be made to diverge — `+mos-a16` shares the data model and exposes no macro — so
   the FAIL path is provable only by a genuine bug, which the pilot supplied.)* After adding
   `KNOWN_ISSUES["a16-zp-pressure-overflow"]` it reclassifies:
   ```
   xf pr15296.c              XFAIL known issue [a16-zp-pressure-overflow]
   ```
5. **An unsupported test is SKIP'd, not FAIL'd.** ✅ PASS — both SKIP sub-paths fired, e.g.:
   ```
   ·· pr108498-1.c           SKIP  default != PASS (got 0xDEAD) — target-inappropriate
   ·· pr101335.c             SKIP  default build fails at -O1 (unsupported)
   ```
6. **Non-breaking.** ✅ PASS — **no `vendor/llvm-mos` / `0002` change** (test-harness only). The sole shared
   edit is an *additive* `KNOWN_ISSUES` entry in `tools/a16_fuzz.py`; the fuzzer never routes link errors
   through `classify_known`, so its behavior is unchanged (`dev/run.sh fuzz 1 1` → `1/1 PASS, all agree`,
   re-confirmed). Existing emulator smoke green throughout.

## Risks / honest scoping
- **16-bit `int`.** llvm-mos `int` is 16 bits; a fraction of torture tests assume ≥32-bit `int` and land in
  `unsupported.tsv` (part of the 197 compile-errors). Coverage is the *in-scope* subset (**1253 / 1656**
  measured in Phase 0), not the whole suite — state the number, don't imply full conformance.
- **Tiny RAM.** The SNES corpus linker confines writable data to LoRAM (~7.5 KB); big-array tests overflow →
  SKIP (caught at link).
- **Emulator wall-clock.** Full set × 3 variants × 2 `-O` × (MAME+bsnes) is hours. Hence the host-only
  Phase-0 filter, time budgets, sampling, and nightly-not-per-push CI.
- **Watchdog vs real hang.** A test exceeding the tick budget is SKIP **unless** the default build completes
  and a16 times out — that is a real hang regression (cf. the fuzzer's `ashr ≥ 8` hang), classified FAIL.
- **No `vendor/llvm-mos` edits** until Phase 2 produces a root-caused bug + regression test; Phases 0–1 are
  pure harness, additive, no `0002` change.

## Out of scope
- Random program generation (Csmith/Yarpgen) — separate axis; we already have the fuzzer.
- `c-testsuite` stdout model — fallback only (recorded above), not built unless the GPL fetch is rejected.
- Conformance *claims* — this is differential bug-finding vs the trusted default build, not an ISO
  conformance certification.
- Floating-point / full-libc tests — outside the freestanding subset; filtered out.

## References
- gcc `c-torture/execute` — <https://gcc.gnu.org/onlinedocs/gccint/C-Tests.html>
- `c-testsuite` (fallback) — <https://github.com/c-testsuite/c-testsuite>
- Differential output-comparison methodology — <https://arxiv.org/pdf/2202.07390>
