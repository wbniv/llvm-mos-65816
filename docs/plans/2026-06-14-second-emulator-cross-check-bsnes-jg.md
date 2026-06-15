# Second-emulator cross-check — bsnes-jg alongside MAME (ROADMAP step 3 fidelity gate)

**Date:** 2026-06-14 · **Status:** Complete — `dev/run.sh xcheck` boots the far ROMs in bsnes-jg
headless and reads back the same WRAM bytes MAME does (`far-bank1` bank-$01 far read → `0xF3` on both).
ROADMAP step 3's "both emulators" gate is **met**. · **Milestone:** M1 (ROADMAP step 3). **Supersedes**
the Mesen2 plan (see Pivot).

## Context

ROADMAP step 3 ("far pointers work … in **both emulators**") is currently single-emulator: every
result is read from **MAME**'s `snes` driver. Increment 2b's fidelity-critical claim — a far read
crossing into ROM **bank $01** (`lda $018000`) — rests on MAME mapping that 64 KiB LoROM correctly.
A second, independent emulator agreeing on the same WRAM result is the honest bar.

## Pivot — why bsnes-jg, not Mesen2 (recorded so the dead-end isn't re-explored)

The original plan was Mesen2 (clean Lua memory API). Two hard blockers killed it on this bench:
- **ABI crash on the 26.04 base.** The Mesen2 prebuilt (also what the foundry `mesen2` package ships)
  aborts instantly with `free(): invalid pointer` against Ubuntu 26.04's **glibc 2.43** — confirmed
  even with the full runtime dep set (`libicu78` + the whole X stack) under xvfb. It's a binary/ABI
  incompatibility, not a missing dep. On 24.04 (glibc 2.39) it doesn't crash…
- **…but its headless `--testrunner` doesn't work.** On 24.04, `--testrunner rom.sfc script.lua`
  produces no stdout and **does not execute the Lua script** (a file-writing probe wrote nothing).
  Getting a verdict out would need reverse-engineering its testrunner. Dead end.

**bsnes-jg** (which we package for foundry, GPL-3, cycle-accurate fork of bsnes) is the better fit
*because its C++ API exposes memory directly*: `Bsnes::getMemoryRaw(Bsnes::Memory::MainRAM)` returns a
live pointer to the 128 KiB WRAM — so we read `corpus_result` exactly like MAME's `read_u8`, with **no
save-state parsing**. Its core links **without SDL and without `jg.h`**, so the harness is fully
headless on 26.04 (no X/xvfb). Proven: far-bank1 → `SMOKE: PASS got=0xF3` on bsnes-jg.

## Approach

Mirror the MAME contract (`dev/_emu.sh run_assert` reads `0x7E0000 + VMA(symbol)`); for bsnes-jg the
WRAM offset is simply `VMA` into `MainRAM`. Reuse the *same* far ROMs MAME verifies.

### 1. Headless harness — `dev/jgxcheck.cpp` (written, proven)

example.cpp stripped of all SDL: keep the `Bsnes::` callbacks (`setRomLoadCallback`→
`setRomSuperFamicom`, the file/log/video/audio stubs) + `load()`/`power()`/`run()`, then read WRAM via
`getMemoryRaw(MainRAM)`. CLI: `jgxcheck <rom.sfc> <datadir> <offset_hex> <len> <want_hex> [frames]`;
prints a `SMOKE: PASS/FAIL …` line and sets the exit code. `datadir` holds the bsnes game database
(`boards.bml`, `SuperFamicom.bml`, …) served via the open-stream callback. SPC700 IPL is embedded by
bsnes — none needed (unlike MAME).

### 2. Build + run driver — `dev/xcheck.sh` (new) + `dev/run.sh xcheck`

- Fetch **pinned bsnes-jg 2.1.0** (`sha256 a8e0fd36…`) into `vendor/bsnes-jg` (gitignored); build the
  core `make ENABLE_STATIC=1 DISABLE_MODULE=1` (→ `objs/libbsnes.a`, no SDL/jg.h); compile+link
  `dev/jgxcheck.cpp` against it + `-lsamplerate`. Cache the `jgxcheck` binary in `build/`.
- Build-if-missing the far ROMs (reuse the `far-run`/`far-bank1` compiles); use `hello.sfc` from a
  prior `build` as a liveness check.
- For each ROM: derive `(VMA, size)` from the `.map` via `dev/_emu.sh`'s `_emu_map_lookup` (reused),
  run `jgxcheck`, assert against MAME's expected value, and print a per-ROM PASS/FAIL.
- `dev/run.sh xcheck` → `dev/xcheck.sh` (generic dispatch); document the target in `dev/run.sh`.

### 3. Dev image — `dev/Dockerfile`

Add `pkg-config` + `libsamplerate0-dev` (the only extra build deps for the bsnes-jg core; `g++`/`make`
already present). The bsnes-jg source is fetched at run time by `xcheck.sh` (pinned), consistent with
how the SDK/toolchain are vendored.

## Critical files

| File | Change |
|------|--------|
| `dev/jgxcheck.cpp` | **new (written)** — headless bsnes-jg harness; reads WRAM via `getMemoryRaw(MainRAM)` |
| `dev/xcheck.sh` | **new** — fetch+build bsnes-jg core + harness, build-if-missing far ROMs, assert each, report vs MAME |
| `dev/run.sh` | document the `xcheck` target |
| `dev/Dockerfile` | add `pkg-config libsamplerate0-dev` |
| `docs/ROADMAP.md`, `TODO.md` | mark ROADMAP step 3's second-emulator gate met; promote the TODO item |

**Reused (no change):** `dev/_emu.sh` `_emu_map_lookup`, the far ROMs (`far-run.sfc` bank $00,
`far-bank1.sfc` bank $01) + `hello.sfc`, the `SMOKE:` verdict convention. MAME path untouched.

## Risks

- **bsnes-jg fetch at run time.** `xcheck.sh` needs network in the container (as `build.sh`/
  `toolchain.sh` already do). Pinned by sha256; cached after first build.
- **Frame budget.** The ROMs compute in `main()` then spin; 180 frames is ample for crt0+main. (Tuned
  if a ROM ever needs longer.)
- **Cache staleness.** `build/jgxcheck` is cached; `rm build/jgxcheck` (or a clean) forces a rebuild
  after editing the harness or bumping bsnes-jg. Noted in the script header.

## Verification (end-to-end)

Each step pastes raw output + PASS/FAIL into this plan (project rule). Run 2026-06-14, from-source
toolchain; bsnes-jg 2.1.0 core built headless in the dev container.

1. **bsnes-jg cross-check the far ROMs (the deliverable):**
   `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh xcheck` → `far-run` (bank $00) and
   `far-bank1` (bank $01) both `SMOKE: PASS got=0xF3` on bsnes-jg, plus `hello` sentinel `0x42`.

   ```
   ==> build bsnes-jg core (ENABLE_STATIC, no SDL/jg.h) + jgxcheck harness
   ==> bsnes-jg cross-check (independent of MAME)
     PASS  hello.sfc:     SMOKE: PASS off=0x20  len=1 got=0x42 (ran 180 frames, bsnes-jg)
     PASS  far-run.sfc:   SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
     PASS  far-bank1.sfc: SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
   RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
   ```
   **PASS** — bsnes-jg (cycle-accurate, independent of MAME) reads `corpus_result == 0xF3` for the
   bank-$01 far read via `getMemoryRaw(MainRAM)`. Headless on the 26.04 base, no SDL/X/save-state.

2. **Agreement with MAME:** the same ROMs read `0xF3`/`0x42` on MAME and on bsnes-jg.

   ```
   far-bank1 (bank $01):  MAME  SMOKE: PASS got=0xF3   |   bsnes-jg  got=0xF3   -> AGREE
   far-run   (bank $00):  MAME  SMOKE: PASS got=0xF3   |   bsnes-jg  got=0xF3   -> AGREE
   hello     (sentinel):  MAME  SMOKE: PASS got=0x42   |   bsnes-jg  got=0x42   -> AGREE
   ```
   **PASS** — two independent emulators agree on the bank-$01 far read. ROADMAP step 3's "both
   emulators" gate is met (MAME evidence in the Increment-2 / 2b plans).

3. **Negative control:** point `jgxcheck` at a wrong expected value → `SMOKE: FAIL got=0xF3`.

   ```
   $ jgxcheck far-bank1.sfc vendor/bsnes-jg/Database 0x200 1 0x00 180
   SMOKE: FAIL off=0x200 len=1 got=0xF3 want=0x00          (rc=1)
   ```
   **PASS** — asserting the wrong value FAILs with `got=0xF3`; the harness genuinely samples WRAM.

4. **No regression:** the MAME path is structurally untouched (the only change to the existing bench is
   an additive Dockerfile layer for `pkg-config`/`libsamplerate0-dev`; `xcheck` is a new target).
   `dev/run.sh corpus` was 7/7 and `far-run`/`far-bank1` PASS in MAME earlier this session (Increment
   2 / 2b records); the far ROMs `xcheck` cross-checks are the same artifacts.
   **PASS** — no change to `dev/_emu.sh`/`smoke.lua`/the SNES platform or any MAME-side path.

## Out of scope

- **Mesen2** (would need a source build against 26.04 to fix the ABI crash + reverse-engineering its
  headless testrunner) — abandoned per Pivot; revisit only if a 26.04-native Mesen build appears.
- **Cross-checking the full 6502 corpus** on bsnes-jg — cheap to add (same `jgxcheck`), but the corpus
  is standard 6502-in-bank-$00, not the fidelity-critical surface.
- ~~**CI wiring** — follows once the local `xcheck` target is green.~~ **Done** — an `xcheck` job was
  added to `.github/workflows/smoke.yml` (from-source toolchain cached via `actions/cache@v5`, then
  the snes-far SDK, then `dev/run.sh xcheck`). See
  [docs/plans/2026-06-15-wire-bsnes-jg-xcheck-into-ci.md](2026-06-15-wire-bsnes-jg-xcheck-into-ci.md).
