# Vendor an external C correctness suite (gcc `c-torture/execute`) behind the `+mos-a16`/`+mos-xy16` differential gate

**Date:** 2026-06-19 · **Status:** PLANNED (not started).
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
*execution*-correctness corpus — ~1,500 self-checking programs that `abort()` on a wrong result and
`exit(0)` on success) into the **existing** differential engine, using the **default (non-`+mos-a16`)
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
**shim TU** (`examples/65816/torture/_shim.c`) force-included at compile time:

- Rename the test's entry: compile the test `.c` with `-Dmain=torture_test_main`.
- The shim provides the **real** `main`:
  ```c
  volatile unsigned short corpus_result;
  #define PASS 0x600D
  #define FAIL 0xDEAD
  int torture_test_main(void);
  int main(void){ int r = torture_test_main(); corpus_result = r ? FAIL : PASS; for(;;){} }
  void abort(void){ corpus_result = FAIL; for(;;){} }
  void exit(int c){ corpus_result = c ? FAIL : PASS; for(;;){} }
  // + freestanding stubs the in-scope subset needs: __assert_fail, etc.
  ```
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

### Phase 0 — fetch + host-side filter (no emulator; fast)
1. `dev/fetch-torture.sh` — pinned, sha256-verified tarball → gitignored `vendor/c-torture/execute/`.
   `set -euo pipefail`, `-h/--help`, idempotent (skip re-download if checksum matches).
2. **Compile/link filter** (`tools/torture_filter.py`, host-only, **default build only** — no flags, no
   emulator): for each `.c`, attempt the shim'd `compile_rom(... flags=[])` + link against the SNES SDK.
   Bucket each test: `compiles+links` (candidate in-scope) vs `compile-fail` / `link-overflow`
   (unsupported), with the diagnostic captured. Emit `examples/65816/torture/inscope.tsv` (the candidate
   list) + `unsupported.tsv` (excluded, with reason). **Log the counts** (e.g. "1487 total → 612 build,
   875 unsupported [n compile, m link]") — no silent caps.

### Phase 1 — adapter + runner + pilot
3. `examples/65816/torture/_shim.c` (above) + `dev/torture.sh` (drive from host: `dev/run.sh torture
   [N] [--opt -Os] [--no-bsnes]`).
4. `tools/torture_run.py` — **imports** `a16_fuzz` as a module and **reuses** `compile_rom` / `run_mame` /
   `run_bsnes` / `map_lookup` / `KNOWN_ISSUES` (no duplication); adds the shim wiring + the PASS/FAIL/SKIP
   sentinel classification above. Runs a test across the three build variants at a chosen `-O` level.
5. **Pilot:** run a fixed **30-test** slice of `inscope.tsv` through the full gate at `-Os` **and** `-O1`
   (the pressure levels where `globals.c`/scavenger bugs live). Prove: the adapter classifies correctly, a
   **deliberately-broken** test (inject `if (1) abort();`) is caught as FAIL, and a known-unsupported test
   is SKIP'd. Record raw output in §Verification.

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

## Verification (run on execution; paste raw output under each step)

1. **Fetch is reproducible + pinned.** `dev/fetch-torture.sh` on a clean checkout → sha256 matches; a
   second run is a no-op. _(paste)_
2. **Filter partitions deterministically.** `tools/torture_filter.py` → `inscope.tsv` + `unsupported.tsv`;
   re-run is byte-identical; counts logged and sum to the total. _(paste)_
3. **Adapter classifies correctly (pilot).** `dev/run.sh torture 30 --opt -Os`:
   default==+mos-a16==+mos-xy16==PASS on the in-scope slice (MAME + bsnes-jg). _(paste)_
4. **A real defect is caught.** Inject `abort()` into one passing test → runner reports **FAIL** (not
   SKIP/PASS). _(paste)_
5. **An unsupported test is SKIP'd, not FAIL'd.** A 32-bit-`int`-assuming test → default ≠ PASS → SKIP with
   reason. _(paste)_
6. **Non-breaking.** Existing gates unchanged: `dev/run.sh corpus` 7/7, `corpus-a16` 5/6+XFAIL,
   `fuzz 50 1` green, `0002` round-trips (no `vendor/llvm-mos` change — this is test-harness only). _(paste)_

## Risks / honest scoping
- **16-bit `int`.** llvm-mos `int` is 16 bits; a large fraction of torture tests assume ≥32-bit `int` and
  will land in `unsupported.tsv`. Coverage is the *in-scope* subset, not all ~1,500 — state the number, don't
  imply full conformance.
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
