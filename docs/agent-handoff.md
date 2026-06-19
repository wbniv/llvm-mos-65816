# llvm-mos-65816 — agent handoff: build/test mechanics & backend navigation

Verbose reference for doing codegen work on this repo. The high-level orientation, the `vendor/` model, the
three governing lessons, and commit discipline are in the auto-loaded project
[`CLAUDE.md`](../CLAUDE.md) — read that first; this file is the mechanics it points to. (Per-task specifics
live in `docs/plans/YYYY-MM-DD-<topic>.md`.)

## Active worktrees (2026-06-19)

| Branch | Worktree | Task | Status |
|--------|----------|------|--------|
| `wt/321-csmith` | `/home/will/SRC/llvm-mos-65816-csmith` | Csmith differential fuzzer — Phases 0–4 done (s32 fixed); Phase 5 (sampled CI) open | ~~**MERGED** `dd5616b` → main 2026-06-19~~ |
| `wt/321-xy16` | `/home/will/SRC/llvm-mos-65816-xy16` | xy16 index-register-mode implementation (Layers 1–5) | ~~**MERGED** `35604c7` → main 2026-06-18~~ |
| `main` | `/home/will/SRC/llvm-mos-65816` | seed-42 regression: `legalizeICmp` EQ-swap leaked into non-a16 path | ~~DONE~~ `51a5bae` |
| `main` | `/home/will/SRC/llvm-mos-65816` | indir-dst copy fold (`*p = gg`): corpus trigger check | ~~CLOSED WON'T-DO~~ — 0/6 progs, 0 B, `f52d5b8` |

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
  `dev/run.sh corpus` (expect `7/7`). Differential fuzzer: `dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]`
  (**Csmith is now the default**; builtin selectable via `--gen builtin`). With Csmith: expect `0 mismatch,
  0 crash` — a handful of seeds legitimately SKIP (Csmith `main` diverges before `corpus_result` is set,
  so `--gc-sections` drops it). Example: `dev/run.sh fuzz 50 1` → `~46 PASS, 0 xfail, ~4 skip (0 mismatch)`
  on seeds 1–50. Builtin (all 4-way oracle): `dev/run.sh fuzz --gen builtin 50 1` (expect `50/50, 0 mismatch`).
  - **The "QUIET box" rule is a MAME/fuzzer rule, not a bsnes-jg one.** The **bsnes-jg leg** (`build/jgxcheck`)
    is *deterministic* — fixed frame count + direct WRAM read, no Lua bridge / settle window — so its
    verdict is load-insensitive (and it needs no SPC700 BIOS). A **bsnes-jg-only** confirmation of the
    second oracle can therefore run on a contended box; run it **serial** (one core) to stay a light
    neighbor to any concurrent MAME. Today the jgxcheck leg only runs *after* MAME inside each
    `dev/a16*.sh`; the planned MAME-skipping `JG_ONLY` guard + `dev/run.sh xcheck-suite` makes the
    second-emulator-only pass a first-class target —
    [plan](plans/2026-06-19-second-emulator-jg-only-confirmation.md).
- **Running `dev/run.sh` from a feature worktree** (the Docker run mounts a single root, so the `CLAUDE.md`
  env-override trick is host-side only): hardlink the prebuilt `build/` in with `cp -al` — full procedure in
  [`howto-feature-worktree.md`](howto-feature-worktree.md).
- **External C suite (gcc c-torture):** host prereq `dev/fetch-torture.sh` (pinned gcc-14.2.0,
  sha256-verified → gitignored `vendor/c-torture/`) + `python3 tools/torture_filter.py` (host-only
  compile/link filter → `examples/65816/torture/{inscope,unsupported}.tsv`, 1253/1656 in-scope; `mos-clang`
  runs **directly on the host**, no Docker). Then the emulator differential gate:
  `dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--no-bsnes]` (`tools/torture_run.py`) — DEFAULT
  build is the oracle, so a non-PASS default ⇒ **SKIP** and any FAIL is a real defect; known a16 crashes
  (incl. `a16-zp-pressure-overflow`) ⇒ XFAIL. [plan](plans/2026-06-19-321-c-torture-execute-differential-suite.md).
- Long ops: background them and monitor; don't block on `sleep`.
- **CI** (`.github/workflows/smoke.yml`, `workflow_dispatch`-only): the `smoke` job boots the corpus in
  MAME; the `xcheck` job builds the from-source toolchain (cached) + SDK, then `dev/run.sh xcheck` (bsnes-jg)
  and the secret-gated `dev/run.sh corpus-a16`. Dispatch: `gh workflow run snes-smoke`. **Monitor a run
  with `task ci-watch` / `dev/ci-watch.sh [RUN_ID|--once]`** — streams step transitions + a heartbeat + the
  final verdict and exits with the run's conclusion (background it; GitHub exposes in-progress step *logs*
  only in the web UI, so ci-watch tracks structure, not log text). Both CI legs proven green: run
  27823207476 (2026-06-19, cold ~1h46m; cached thereafter).

## The correctness gate + micro-test pattern

The bar is the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. New value-level behavior gets a
`examples/65816/a16<name>.c` + `dev/a16<name>.sh` micro-test (pattern: a `corpus_result` the test asserts
across host/default/a16 on both emulators, often with a disasm gate, e.g. native `cmp` present and no 8-bit
`cpx/cpy`), wired into `dev/run.sh`, and is exercised by the fuzzer (`tools/a16_fuzz.py`). Use
`examples/65816/a16eqval*.c` + `dev/a16eqval*.sh` as templates. Close the script with
`emu_verdict "$rc" "<pass detail incl. an emulator-agreement clause>"` (from `dev/_emu.sh`), **not** a
hand-rolled `echo "RESULT: …"` — the helper prints `RESULT: FAIL`/`PASS` and, under `JG_ONLY`
(`dev/run.sh xcheck-suite`, the bsnes-jg-only pass), rewrites the "both emulators" claim so a MAME-skipped
run stays honest.

**Gating discipline — the fuzzer guards the DEFAULT build too.** Every `+mos-a16` change must be gated so it
*cannot* alter non-`+mos-a16` codegen — and that includes **operand canonicalizations / helper predicates**,
not just instruction defs and selection. A green a16 suite is **not** sufficient: the differential fuzzer
compiles each program *both* default and `+mos-a16` and compares to the host oracle, so an a16 helper that
leaks into the 8-bit path surfaces as a `default@MAME ≠ host` mismatch. Concrete bite (seed-42, fixed in
`0002` 2026-06-18): an EQ-only operand swap in `legalizeICmp` was guarded by a predicate that did **not**
check `hasAccum16` (nor `Pred==EQ`), so a non-EQ `<`/`>` compare in the *default* build hit
`std::swap(LHS, RHS)` and reversed the comparison →
[plan](plans/2026-06-18-321-seed42-legalizeicmp-swap-fix.md). Gate on the **same predicate that enables the
feature behavior** (e.g. `NativeS16Eq` = `hasAccum16 && Type==S16 && Pred==ICMP_EQ`), not a looser
operand-shape test.

**Attributing a fuzzer/regression finding to a patch (or single hunk) — isolated-worktree + ccache
bisection.** When a differential mismatch must be pinned to a specific patch/hunk and MIR diffing is
inconclusive (state-sensitive bug, byte-identical post-legalize IR), bisect with *builds*: spin a detached
worktree of `vendor/llvm-mos` at pristine upstream (`git -C vendor/llvm-mos worktree add --detach <dir>
<HEAD-sha>`), `git apply` a chosen *subset* of `patches/llvm-mos/*.patch` hunks (filter a patch to specific
files/hunks with `awk` on the `diff --git` / `@@` headers; revert one with `git apply -R`), build into a
**separate** `build/` dir with `CCACHE_DIR=$PWD/build/.ccache` reused (each incremental rebuild is minutes,
not the 30–90 min cold build — LLVM TUs hit ccache, only the changed MOS target recompiles + relinks), and
run the one-program differential (`dev/run.sh fuzz 1 <seed>`) on each. The unpatched `/opt/llvm-mos` in the
dev container is the correct-value oracle. **Never** build a subset into the shared `build/llvm-mos` (it
clobbers the toolchain other agents use). Trust the build result over any plausible mechanism — two
"obvious" causes (a concurrent edit; the register topology) were each refuted this way before the real
one-line cause was found.

## Measurement methodology (size/speed claims)

- Compare **native-`+mos-a16` vs 8-bit-`+mos-a16` on the *same* C shape** — toggle only the feature gate.
  Never compare `+mos-a16` vs non-`+mos-a16` (that conflates the value's ALU/load codegen with the change
  under study). Often the *current* `+mos-a16` output already IS the 8-bit baseline for the shape (the gate
  doesn't fire yet) — capture it, make the change, rebuild, diff.
- Decide on **bytes** (the `-Os` target), cycles as tiebreaker; report both. Hand-count 65816 cycles if
  needed (DP=0 assumption; the *delta* is usually insensitive to the DP penalty).
- **Addressing/DBR contract (don't over-generalize the `inc abs` note).** Near data is bank-0 low WRAM
  ($0200–$1FFF). The **8-bit `abs` path is DBR-relative** (`R_MOS_ADDR16`, reads `DBR:addr`); the **native-16
  `long` path is DBR-independent** (`R_MOS_ADDR24`). So data access is a *mix*, not uniformly
  DBR-independent. The crt0 establishes **DBR=0 explicitly** (`phk; plb` in `.init.50`) so the 8-bit `abs`
  globals + MMIO writes land in bank 0; gate `dev/run.sh crt0native`. See
  [native-mode-crt0-xy16 plan](plans/2026-06-18-321-native-mode-crt0-xy16.md). Full power-on→`main()`
  walkthrough: [snes-bootup-sequence](snes-bootup-sequence.md).
- **Measure in realistic 16-bit-ambient context, not just isolated leaf functions.** A leaf function pins
  the ambient accumulator mode at 8-bit and over-charges `rep`/`sep` to the op under study; real `+mos-a16`
  code holds `M=0` across sustained compute. (This regime difference has flipped measured conclusions
  here.)

## Navigating the backend (grep — don't trust line numbers; `vendor/` is multi-agent)

Line numbers drift because `vendor/` is edited by multiple agents — **grep for symbol/string anchors.**
Under `vendor/llvm-mos/llvm/lib/Target/MOS/`:

- `MOSLegalizerInfo.cpp` — GISel legalization: `legalizeICmp`, `legalizeAddSub`, `legalizeLoadStore16`, the
  `+mos-a16` gates (e.g. `NativeS16Eq`); also the four `hasAccum16()`-gated s32↔s16 rules
  (`G_ANYEXT`/`G_TRUNC`/`G_MERGE_VALUES`/`G_UNMERGE_VALUES`) so `+mos-a16` handles `int32_t`/`long`.
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
