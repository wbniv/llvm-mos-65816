# llvm-mos-65816 — agent handoff: build/test mechanics & backend navigation

Verbose reference for doing codegen work on this repo. The high-level orientation, the `vendor/` model, the
three governing lessons, and commit discipline are in the auto-loaded project
[`CLAUDE.md`](../CLAUDE.md) — read that first; this file is the mechanics it points to. (Per-task specifics
live in `docs/plans/YYYY-MM-DD-<topic>.md`.)

## Build / compile / disasm / test — the exact commands

- **Rebuild the toolchain after a `vendor/` edit** (Docker container; incremental): `dev/run.sh toolchain`.
  **Do not** start a second concurrent toolchain build (it clobbers `build/llvm-mos`). **GOTCHA:**
  `build/llvm-mos-install/bin/clang` is a symlink with a *stale mtime*; the real binary is **`clang-23`**.
  Confirm a rebuild took by checking `clang-23`'s mtime advanced (or `nm` it for a new symbol) — a stale
  build silently serving old codegen has burned this project before.
- **Compile + MIR-verify on the host** (no container needed; `mos-clang` is the built compiler):
  ```
  build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs -c FILE.c -o /tmp/x.o
  ```
  Use the `-Xclang -target-feature -Xclang +mos-a16` form (the driver rejects `-mattr`). Clean exit = OK.
- **Disasm / size:** `build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/x.o`;
  `… --section-headers /tmp/x.o` → per-function `.text.<name>` byte size. In an unlinked `.o`, zero-page
  operands all print as `$0` (relocation placeholders) — for symbolic operand names compile to assembly
  (`-S`).
- **MIR:** add `-mllvm -print-after=legalizer` / `-print-before=legalizer` / `-print-after-all` (to stderr).
- **Emulator / differential tests** (Docker; **run on a QUIET box** — concurrent docker/MAME load flakes
  MAME's settle window → false failures that pass on re-run): `dev/run.sh <name>`. The a16 suite:
  `for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done`. Corpus:
  `dev/run.sh corpus` (expect `7/7`). Differential fuzzer: `dev/run.sh fuzz 50 1` (expect
  `50/50, 0 mismatch, 0 new-crash`).
- Long ops: background them and monitor; don't block on `sleep`.

## The correctness gate + micro-test pattern

The bar is the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. New value-level behavior gets a
`examples/65816/a16<name>.c` + `dev/a16<name>.sh` micro-test (pattern: a `corpus_result` the test asserts
across host/default/a16 on both emulators, often with a disasm gate, e.g. native `cmp` present and no 8-bit
`cpx/cpy`), wired into `dev/run.sh`, and is exercised by the fuzzer (`tools/a16_fuzz.py`). Use
`examples/65816/a16eqval*.c` + `dev/a16eqval*.sh` as templates.

## Measurement methodology (size/speed claims)

- Compare **native-`+mos-a16` vs 8-bit-`+mos-a16` on the *same* C shape** — toggle only the feature gate.
  Never compare `+mos-a16` vs non-`+mos-a16` (that conflates the value's ALU/load codegen with the change
  under study). Often the *current* `+mos-a16` output already IS the 8-bit baseline for the shape (the gate
  doesn't fire yet) — capture it, make the change, rebuild, diff.
- Decide on **bytes** (the `-Os` target), cycles as tiebreaker; report both. Hand-count 65816 cycles if
  needed (DP=0 assumption; the *delta* is usually insensitive to the DP penalty).
- **Measure in realistic 16-bit-ambient context, not just isolated leaf functions.** A leaf function pins
  the ambient accumulator mode at 8-bit and over-charges `rep`/`sep` to the op under study; real `+mos-a16`
  code holds `M=0` across sustained compute. (This regime difference has flipped measured conclusions
  here.)

## Navigating the backend (grep — don't trust line numbers; `vendor/` is multi-agent)

Line numbers drift because `vendor/` is edited by multiple agents — **grep for symbol/string anchors.**
Under `vendor/llvm-mos/llvm/lib/Target/MOS/`:

- `MOSLegalizerInfo.cpp` — GISel legalization: `legalizeICmp`, `legalizeAddSub`, `legalizeLoadStore16`, the
  `+mos-a16` gates (e.g. `NativeS16Eq`).
- `MOSInstructionSelector.cpp` — selection: `select*`, the `m_CmpNZ*` / `CmpNZ*_match` matchers, operand-fold
  helpers (`getImm16Operand`, `foldableAbsLoad16`).
- `MOSInstrPseudos.td` + `MOSInstrInfo.cpp` — pseudos: `CmpBrImag16` (Imag16-resident LHS),
  `CmpBrImm16` (const RHS), `CmpBrAbsAbs16` (both-global), `CmpBrAbsImm16` (global LHS + const RHS),
  `CmpBrImagAbs16` (computed LHS + global RHS); + their post-RA expansion (`expandCmpBr16`).
- `MOSInsertREPSEP.cpp` — M-flag (8/16-bit) mode tracking across blocks.
- `MOSLateOptimization.cpp` — post-RA peephole: `threadAccum16` eliminates redundant `STAImag16 R;
  LDAImag16 R` round-trips between dependent native-s16 ops (A16-threading Phases 0–1–1.5 done).
- `MOSRegisterInfo.td` — register classes: `GPR` = {A,X,Y}, `Ac16` = {A16}, `Imag8`/`Imag16` = the
  zero-page imaginary registers (`$rc*` / `$rs*`).

Harness/tests: `examples/65816/`, `dev/run.sh` + `dev/*.sh`, `tools/a16_fuzz.py`.
