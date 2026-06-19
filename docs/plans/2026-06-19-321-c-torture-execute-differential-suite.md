# Vendor an external C correctness suite (gcc `c-torture/execute`) behind the `+mos-a16`/`+mos-xy16` differential gate

**Date:** 2026-06-19 · **Status:** **PHASES 0 + 1 DONE (2026-06-19)** — fetch + host-side filter
(**1253 / 1656** in-scope) and the emulator differential runner both landed and verified. 120-test pilot:
**102 PASS, 17 SKIP, 1 XFAIL** (a real `+mos-a16 -O1/-Os` defect, `pr15296.c`, classified into the known
register-pressure family). Phase 2 (full-suite scale + triage) and Phase 3 (sampled CI) pending. See
§"Phase 0 / Phase 1 — RESULTS".
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

### Phase 2 — scale + triage
6. Run the **full `inscope.tsv`** at `-Os` and `-O1` (time-budgeted; this is the heavy emulator pass —
   run on a quiet box / overnight, not inline). Triage every **FAIL**:
   - delta-reduce (reuse the fuzzer's triage path) → minimal `.c` → root-cause → **fix in-backend with a
     regression test** (the F1/F2/F3/F4 precedent), or **XFAIL** with a `KNOWN_ISSUES` entry + an
     investigation note if it's the known RA/scavenger family.
   - **Expectation:** most defects will be *new shapes of already-known* `-O1/-Os` register-pressure bugs
     ([globals.c RA](../investigations/65816-a16-regalloc-pressure-failure.md),
     [scavenger N/Z](../investigations/65816-a16-scavenger-nz-liveness.md)); genuinely new ones are the
     prize.
7. Freeze a stable in-scope manifest + its expected SKIP/PASS partition; record the run verdict.

### Phase 3 — CI wiring (optional, follows Phase 2 green)
8. A **sampled, secret-gated** CI job (mirror [corpus-a16 CI](2026-06-19-321-corpus-a16-ci.md)): a fixed
   pseudo-random subset (seeded, not the full ~600 — emulator wall-clock) per run, plus the full set
   nightly. Forks without the BIOS secret skip. Never fail CI on a SKIP.

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
- The `builtins/` and `ieee/` subdirs (206 more tests) are **excluded by design** (compiler-builtin
  libcalls / floating-point); pass `--subdirs` to include them, but they are out of the freestanding
  integer scope this gate targets.
- **Determinism:** two back-to-back full runs produce **byte-identical** `inscope.tsv` / `unsupported.tsv`
  (the one initially-flapping row — `user-printf.c`, many missing symbols listed in nondeterministic order
  — is now normalized to the sorted-smallest symbol + a `(+N more)` count).
- **Build-mechanics correction** (now reflected in §"The adapter"): the shim must be **precompiled to
  `_shim.o`** and linked, because `-Dmain=…` applies to *all* TUs on the command line and would otherwise
  rename the shim's own `main`.

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
- **No new miscompile** — and none is even *possible* from a conforming program: `+mos-a16` exposes no
  predefined macro and shares the data model (16-bit `int`, same pointer sizes) with the default build, so
  the two can only differ on a real codegen bug. That makes the differential precise: a value mismatch *is*
  a defect.

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
