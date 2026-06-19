# Second-emulator (bsnes-jg) confirmation — a MAME-skipping `JG_ONLY` suite runner

## Context

The correctness bar (CLAUDE.md "The bar") is a four-way differential:
`host == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg`. The **bsnes-jg leg** is the independent
oracle — `build/jgxcheck` (a headless harness over the pinned bsnes-jg 2.1.0 core, `dev/jgxcheck.cpp`)
boots a ROM, runs a **fixed frame count**, and reads WRAM directly:

```cpp
for (int i = 0; i < frames; ++i) Bsnes::run();
... Bsnes::getMemoryRaw(Bsnes::Memory::MainRAM);   // direct read — no Lua bridge, no settle window
```

Today that leg is embedded in each `dev/a16*.sh` / `dev/xy16*.sh` as a **gated add-on** that runs only
*after* the MAME leg (`source dev/_emu.sh; run_assert …`, which is **unconditional**). There is **no way
to run "just the second emulator"** across the suite. This plan adds one.

### Why a bsnes-jg-only pass is worth having (independent of any MAME-contention story)

1. **Deterministic** — fixed frames + direct WRAM read. Same verdict regardless of machine load. (The
   MAME leg, by contrast, can *false-flake* under load — the documented agent-handoff "run on a QUIET
   box" gotcha — so a repeatable second-emulator pass is strictly more trustworthy.)
2. **Fast** — no per-test MAME boot.
3. **Isolates the exact question** "has the second emulator confirmed this codegen?" — re-running MAME
   answers an already-answered question.
4. **No SPC700 BIOS dependency** — MAME's `snes` driver needs the gitignored IPL ROM (`require_bios`);
   `jgxcheck` ships its own Database. A bsnes-jg-only pass runs in environments where MAME can't.

### On "does a concurrent MAME matter?" — corrected: essentially no

An earlier framing in this thread over-weighted it. The truth:
- A bsnes-jg run is **deterministic** → a concurrent MAME cannot change its result.
- The documented "concurrent load flakes MAME" gotcha protects **MAME runs**; a bsnes-jg-only pass is not
  a MAME run, so it doesn't apply.
- The only residual is *politeness*: don't starve a hypothetical concurrent MAME. Running the legs
  **serially** (one core) makes the pass a light neighbor; that's the whole mitigation. It is **not** a
  correctness constraint and **not** a reason to defer.

## Findings (2026-06-19)

- **51** `dev/*.sh` reference `jgxcheck`; the relevant set is the per-feature **value differential**
  micro-tests (`a16*.sh`, `xy16{basic,ops,spillr,indiry}.sh`). Aggregates/special drivers
  (`a16.sh`, `corpus-a16.sh`, `torture.sh`, `fuzz.sh`, `xcheck.sh`, `_check.sh`, `_emu.sh`) are excluded.
- **xy16 second-emulator coverage is complete**: the 4 value-level xy16 tests carry a jgxcheck leg;
  `xy16spill.sh` is a compile-time `-verify-machineinstrs`/MIR gate (no emulator by design — not a gap).
- The **MAME leg is unconditional** (`_emu.sh::run_assert`); **no skip-MAME flag exists** today.
- `build/jgxcheck` + `vendor/bsnes-jg/` are already built/present → the bsnes-jg leg runs **instantly**
  (no core rebuild).

## Design (the contract — code follows this)

### 1. `JG_ONLY` guard in `dev/_emu.sh` (one place, reused by all ~45 scripts)
- `run_assert ROM MAP SYM EXPECT`: when `JG_ONLY=1`, print `SMOKE: SKIP (JG_ONLY — MAME leg skipped)`
  and `return 0` **before** launching MAME. The script's exit code then reflects compile + the bsnes-jg
  leg only.
- `require_bios`: when `JG_ONLY=1`, `return 0` immediately (don't demand the SPC700 IPL — bsnes-jg
  doesn't need it).
- No other change to the 45 scripts — they each still compile their ROM and run their gated jgxcheck leg.

### 2. `dev/xcheck-suite.sh` (dispatched by `dev/run.sh xcheck-suite`)
- Runs **inside the dev container** (generic `dev/run.sh` dispatch already handles any `dev/<t>.sh`; add
  `xcheck-suite` to the usage string for discoverability).
- Enumerate the value-test set (jgxcheck-carrying `a16*`/`xy16*`, minus the aggregate/special exclude
  list). For each: `JG_ONLY=1 nice -n 19 bash /work/dev/<test>.sh`; capture exit code (0 = PASS).
- **Serial** (one core → light neighbor + deterministic). Tally `PASS / FAIL / SKIP`, print a per-test
  line + a final `RESULT: N/N bsnes-jg PASS` summary; exit nonzero if any FAIL.
- Accept an optional arg to run a subset (e.g. `dev/run.sh xcheck-suite xy16` → only `xy16*`).

### 3. (Deferred / optional) container CPU cap
`run.sh`'s `docker run` takes no `--cpus`/`--cpuset`. Serial execution already bounds load to ~1 core, so
a cap is unnecessary for this runner. Add only if a future parallel mode is built.

## Policy — now / wait / both

- **bsnes-jg-only confirmation (`xcheck-suite`): runnable anytime**, including a contended box —
  deterministic, fast, no BIOS dep, light neighbor (serial). This is the second-emulator check you *can*
  run now/continuously as codegen lands.
- **Anything that boots MAME** (the normal `dev/a16*.sh` suite, `dev/run.sh fuzz`): **wait for a quiet
  box** — the documented settle-window flake.
- **Non-codegen work** (e.g. the DWARF doc note): **skip both** — nothing observable changed on either
  emulator; the relevant gate is the task's own (`dev/run.sh dwarf`).

## Verification (run once built — paste raw output here, PASS/FAIL each)

1. **`JG_ONLY=1` skips MAME, keeps the bsnes-jg leg** — `JG_ONLY=1 dev/run.sh a16add` →
   `SMOKE: SKIP (JG_ONLY …)` present, `bsnes-jg: … corpus_result == 0x2345` PASS, exit 0.
2. **`dev/run.sh xcheck-suite`** runs every value test serially, prints a tally, exits 0 on all-pass.
3. **`dev/run.sh xcheck-suite xy16`** runs exactly the 4 xy16 value tests; all bsnes-jg PASS.
4. **BIOS-independence** — temporarily hide `dev/roms/s_smp/spc700.rom`; `JG_ONLY=1 dev/run.sh a16add`
   still passes (require_bios skipped). Restore the BIOS after.

## Scope / non-goals

- Does **not** replace the four-way differential. The quiet-box MAME sweep + `fuzz` remain the acceptance
  gate (the bsnes-jg-only pass confirms the *second oracle* agrees; it does not re-confirm MAME).
- Does **not** change any codegen, `vendor/`, or `0002`. Pure test-harness tooling.

## Running it isolated (worktree note)

A throwaway worktree adds little for a **no-commit run**: it writes only to `build/` (gitignored), so
`main`'s tree stays clean, and ROM outputs are deterministic. The container also mounts a single dir
(`-v "$ROOT":/work`), so a worktree cannot reuse `main`'s prebuilt `build/jgxcheck`+toolchain via
cross-checkout symlink (it dangles inside the container) without a `run.sh` second-mount. So: run
`xcheck-suite` from the **main checkout, backgrounded, serial/niced** — that already delivers the
isolation that matters (deterministic verdict, light CPU). A true second-mount worktree mode is a
possible later `run.sh` enhancement, not needed for this.
