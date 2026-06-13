# M0 — regression corpus (≥5 self-contained C programs)

**Date:** 2026-06-14 · **Status:** Done (2026-06-14) — 6 programs, `dev/run.sh corpus` 7/7 PASS,
negative control + clean-room `repro` green. · **Milestone:** M0 (ROADMAP verification step 2).
**Builds on:** [emulator smoke loop](2026-06-14-emulator-smoke-loop.md).

## Context

ROADMAP **verification step 2** ("bench reproducible") requires a regression corpus: ≥5 small C
programs with known-correct output that build and run green from a clean checkout. Today the bench
runs exactly one program — `examples/snes/hello.c`, a *liveness* check (does `main()` run, is
`sentinel==0x42`). That proves the toolchain boots a ROM, but not that compiled C computes correct
results. The corpus turns the bench into a **correctness baseline**: each program exercises a
distinct slice of codegen and emits a value the host checks against a fixed expected. This matters
because M1 (far pointers) and M2 (16-bit regs / REP-SEP) will rewrite codegen — the *same sources*
must keep producing the *same bytes*, and the corpus is the net that catches a regression the moment
it appears. It directly reuses the smoke-loop harness built earlier today (MAME headless, `-rompath`
BIOS handling, clean-room `dev/run.sh repro`, manual CI).

## Design

**Host-side comparison (not self-checking).** Each program computes a result and stores it to a
known symbol; the *host* compares the bytes read out of WRAM against an expected in a manifest.
Strictly more robust than an in-ROM `if(ok) result=0x42` — a miscompiled comparison can't mask a
wrong answer because the judge lives outside the ROM. It is exactly the M1/M2 contract: fixed
source → fixed expected bytes.

**Uniform result symbol.** Every corpus program writes `volatile uint16_t corpus_result;` (16 bit =
1/65536 odds of a wrong value coincidentally matching; cheap to read), then spins like `hello.c`.
On crash / non-arrival the symbol stays at its `.bss` zero — distinguishable from any nonzero
expected.

**Address *and* length derived from the linker map** (confirmed: `build/hello.map` columns are
`VMA LMA Size Align … Symbol`; `sentinel` → VMA `20`, Size `1`). The existing `dev/smoke.sh`
formula `0x7E0000 + VMA` (WRAM mirror; low-RAM globals live below `$2000`, mirrored into
`$7E0000–$7E1FFF`) generalizes to any symbol; the harness also reads the **Size** column for the
read length — so the manifest does **not** carry a `len` column.

**Manifest** `examples/snes/corpus/expected.tsv` (tab-separated, `#` comments):
```
# cfile               symbol         expected  description
hello.c               sentinel       0x42      liveness: main runs
corpus/arith.c        corpus_result  0x????    8/16/32-bit integer ALU
corpus/control.c      corpus_result  0x????    loops / if / switch
corpus/arrays.c       corpus_result  0x????    arrays + .rodata lookup
corpus/structs.c      corpus_result  0x????    struct layout + pointer deref
corpus/funcs.c        corpus_result  0x????    calls + recursion (soft stack)
corpus/globals.c      corpus_result  0x????    crt0 .data copy + .bss clear
```
`hello.c` is row 0 — the corpus re-validates the smoke for free (one mechanism for both). Expected
values are hand-computed (programs are trivial/deterministic) with the derivation commented in each
`.c`; `0x????` filled in as each is written.

**Harness reuse.** `dev/smoke.lua` gains `SMOKE_LEN` (read N bytes little-endian; default 1, so the
existing `hello` path is unchanged). The MAME-run-and-assert core is factored out of `dev/smoke.sh`
into a sourced helper `dev/_emu.sh` (`run_assert <rom> <map> <symbol> <expected>` — derives addr+len
from the map, runs MAME headless, greps `SMOKE:`), so `smoke` and `corpus` share one invocation.

## Programs (6 — exceeds ≥5; deterministic, no UB, `volatile` inputs to defeat `-Os` constant-folding)

| File | Exercises | Catches |
|------|-----------|---------|
| `arith.c` | `uint8/16/32` add/sub/mul/div/mod/shift/bitwise | multi-byte ALU + mul/div libcalls (M2 reg mode) |
| `control.c` | `for`/`while`/`do`, `if/else`, `switch` | branch/loop lowering |
| `arrays.c` | `const` `.rodata` table + RAM array indexing | addressing modes + section placement (M1) |
| `structs.c` | struct fields, array-of-struct, pointer-to-struct | struct layout + pointer deref (M1) |
| `funcs.c` | multi-arg calls, return values, recursion (`fib`) | calling convention / soft stack (M2) |
| `globals.c` | initialized `.data` + zeroed `.bss`, read back | **our crt0 init chain** |

Each `#include <snes.h>`, reads inputs through `volatile`, sets `corpus_result`, then `for(;;){}`.
No PPU/I/O needed (the assert reads WRAM) — keeps them minimal and codegen-focused.

## Files

| File | Change |
|------|--------|
| `examples/snes/corpus/*.c` | **NEW** — the 6 programs |
| `examples/snes/corpus/expected.tsv` | **NEW** — manifest (cfile, symbol, expected, desc) |
| `dev/_emu.sh` | **NEW** — sourced `run_assert` (map→addr+len, MAME headless, grep `SMOKE:`) |
| `dev/smoke.lua` | add `SMOKE_LEN` (read N bytes LE); default 1 (hello unchanged) |
| `dev/smoke.sh` | refactor onto `dev/_emu.sh` (behavior identical) |
| `dev/corpus.sh` | **NEW** — iterate manifest, assert each row, print table + `N/N passed` |
| `dev/build.sh` | build every `examples/snes/**/*.c` → `build/<name>.sfc` + `.map` (currently hello-only) |
| `dev/run.sh` | add in-container `corpus` target |
| `dev/repro.sh` | run `build` + `corpus` (was `+ smoke`; corpus subsumes the smoke row) |
| `.github/workflows/smoke.yml` | run `dev/run.sh corpus` (was `smoke`) |
| `README.md`, `docs/ROADMAP.md`, `TODO.md`, `docs/plans/2026-06-14-regression-corpus.md` | document corpus; ROADMAP step 2 evidence; drop manifest `len` column |

## Implementation steps

1. **Generalize the harness** (no programs yet): `dev/_emu.sh`, `SMOKE_LEN` in `smoke.lua`, refactor
   `smoke.sh` onto it. Re-run `dev/run.sh smoke` → still `SMOKE: PASS` (refactor regression guard).
2. **Generalize the build**: `dev/build.sh` compiles every `examples/snes/**/*.c`. `dev/run.sh build`
   still yields `build/hello.sfc` plus the corpus ROMs+maps.
3. **Write the 6 programs + manifest**, computing each expected by hand, derivation in-source.
4. **`dev/corpus.sh` + `dev/run.sh corpus`**: assert each manifest row, print table, exit nonzero on
   any fail.
5. **Negative control**: corrupt one expected → that row FAILs, `corpus` exits nonzero. Restore.
6. **Wire repro + CI**: `repro.sh` → `build`+`corpus`; `smoke.yml` → `corpus`. `dev/run.sh repro` green.
7. **Docs**: README (corpus + how to add a program), ROADMAP step 2 evidence, TODO → Done.

## Verification

1. **Refactor safe** — `dev/run.sh smoke` → `SMOKE: PASS`, exit 0 (the `_emu.sh`/`SMOKE_LEN` refactor
   didn't break the existing path).
   **PASS** (2026-06-14): `SMOKE: PASS addr=0x7E0020 len=1 got=0x42`, exit 0. Negative control via the
   now-forwarded env (`SMOKE_WANT=0x99 dev/run.sh smoke`) → `SMOKE: FAIL got=0x42 want=0x99`, exit 1.
2. **All build** — `dev/run.sh build`: a 32 KiB `.sfc` + `.map` per program.
   **PASS** (2026-06-14): 7 programs built, each 32768 bytes (hello, arith, control, arrays, structs,
   funcs, globals).
3. **Corpus green (deliverable)** — `dev/run.sh corpus`: each program `SMOKE: PASS` vs manifest,
   prints `N/N passed`, exit 0.
   **PASS** (2026-06-14): **7/7 passed** — `arith 0xA9E9 · control 0x1DFB · arrays 0x03E1 ·
   structs 0x0340 · funcs 0x011E · globals 0xAB55 · hello 0x42`. Every hand-computed expected
   matched the actual ROM output.
4. **Negative control** — a wrong manifest expected → that row FAIL, `corpus` exit nonzero.
   **PASS** (2026-06-14): funcs expected → `0xDEAD` → `funcs FAIL got=0x011E want=0xDEAD`, `6/7
   passed`, exit 1 (and `len=2` correctly auto-derived from the map). Restored.
5. **Reproducible** — `dev/run.sh repro` runs build+corpus green from a clean HEAD checkout; manual CI
   (`workflow_dispatch`) runs `corpus` green. *(Run after committing — see commit + CI dispatch below.)*

## Risks

- **`-Os` constant-folds the program to a literal** (tests the optimizer, not codegen). Mitigate:
  read inputs through `volatile`, keep `corpus_result` `volatile`. Note the `volatile` inputs in each source.
- **Hand-computed expected typo.** The negative control proves the harness *can* fail; each expected's
  derivation is commented.
- **Symbol optimized away / absent from map.** `corpus.sh` errors clearly for that row (no silent skip).

## Out of scope

- Cross-emulator (bsnes-jg/Mesen2) corpus runs — M1. Cycle/size baselining — M2.
