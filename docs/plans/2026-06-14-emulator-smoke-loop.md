# M0 — emulator smoke loop (MAME, headless)

**Date:** 2026-06-14
**Status:** Implemented — smoke green locally via `dev/run.sh smoke` (verification steps 1–4 PASS,
2026-06-14). Step 5 (CI) authored; **pending** the `SNES_SPC700_ROM_B64` GitHub secret + a push.
**Milestone:** M0 (test bench). Closes the *run-half* of ROADMAP verification step 1.
**Predecessor:** structural verification PASS (2026-06-13) — `examples/snes/hello.c` →
valid 32 KiB LoROM `.sfc`, reset path byte-exact to crt0, `main()` placed. See
[ROADMAP.md](../ROADMAP.md) step 1.

## Goal

A bank-0 C "hello world" **boots and runs in an emulator, headless, with a programmatic
pass/fail assertion**, driven from `dev/run.sh smoke` and from CI on a clean checkout. This
is the last open piece of ROADMAP step 1 (structural half already PASS) and the first half
of step 2 (reproducible bench) — the harness this builds is what the M0 regression corpus
will reuse.

## Emulator decision: MAME (settled)

We use **MAME's `snes` driver**, not bsnes/Mesen. Rationale (see the discussion that led
here, and `/home/will/SRC/drdevtools`):

1. **One emulation core across the whole loop.** drdevtools' `drmon` source-level debugger —
   the downstream consumer in this project's reason-for-being (compile → ROM → DWARF →
   source-level debug) — already drives a **live SNES target in MAME's `snes` driver via a
   custom Lua bridge** (drdevtools Phase 2, done 2026-06-11, 19/19 SNES protocol tests green).
   Running the CI smoke test on the *same* core means **green-in-CI == attachable-in-drmon**:
   no emulator-fidelity gap between the bench and the debugger. Any other emulator reintroduces
   exactly the discrepancy class we'd be testing to avoid.
2. **Packaging.** MAME is in Ubuntu universe (`apt install mame`, `0.277` as of writing);
   bsnes/higan/Mesen are not packaged for our `ubuntu:26.04` base — they'd mean building from
   source or vendoring a .NET runtime/AppImage into the image. One apt line vs. a build stage.
3. **Headless + scriptable assertion.** MAME runs headless (`-video none`,
   `SDL_VIDEODRIVER=offscreen`) and exposes a Lua memory API
   (`manager.machine.devices[":maincpu"].spaces["program"]:read_u8(addr)`) — exactly what a
   "boot N frames, assert a RAM byte" smoke test needs. bsnes has no scripting API (you'd be
   reduced to framebuffer-hash diffs).

**Cross-check emulator (bsnes-jg / Mesen2) is deferred to M1**, when codegen correctness
starts depending on emulator fidelity (far pointers, REP/SEP). At M0 the ROM only force-blanks
the PPU and writes a byte in 6502-emulation mode; any solid 65816 core nails that.

## Licensing boundary (must respect)

- `platforms/snes/` is **Apache-2.0** and is copied verbatim into a fork of `llvm-mos-sdk` as
  `mos-platform/snes` for upstreaming. **Nothing GPL may enter that subtree.**
- `drdevtools` is **GPL v2**. Its Lua bridge (`devsys/tools/drmon/linux/mame_bridge.lua`) and
  spikes (`spikes/spike_devmem.lua`, `verify_ppu.lua`) are used **as a reference pattern only** —
  we write a **fresh, clean-room** smoke Lua. A "run N frames, read one byte, compare, exit"
  script is near-trivial; no GPL expression is copied.
- The smoke harness lives under **`dev/`** (dev/CI tooling, not upstreamed), never under
  `platforms/snes/`. This keeps the upstream PR clean.

## Grounding facts (verified 2026-06-14)

- **Observable:** `examples/snes/hello.c` sets the backdrop green, releases force-blank, then
  loops `sentinel = 0x42;`. The robust, emulator-agnostic assertion is the **`sentinel` byte**.
- **Address:** `build/hello.map` places `sentinel` at **`$0020`** (direct page). On SNES this
  is WRAM, canonically `$7E0020`, also mirrored at `$000020` (bank-0 low-RAM mirror). The smoke
  wrapper derives the address from the map (not hardcoded) so it survives relayout.
- **SPC700 IPL ROM is a hard, non-distributable prerequisite** (corrects an earlier assumption
  that "SNES needs no BIOS"). MAME's `snes` driver requires the 64-byte SPC700 APU boot ROM
  `spc700.rom` (sha1 `97e352553e94242ae823547cd853eecda55c20f0`) and aborts before our assert
  with *"Required files are missing, the machine cannot be run"* if absent. It is Nintendo
  content → **never committed**; supplied out-of-band via `-rompath` at
  `dev/roms/s_smp/spc700.rom` (gitignored), exactly as drdevtools treats its `roms/` ("User-
  supplied ROMs (copyrighted; never commit)"). This is "code + a handful of secrets": the ROM is
  the secret-like input. `dev/smoke.sh` preflights it and exits **2** (≠ a `1` assert failure) if
  missing, so a missing-BIOS prereq is distinguishable from a real codegen failure.
- **As-built MAME invocation** (MAME **0.285** on `ubuntu:26.04`, SNES, headless — verified):
  ```sh
  env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
    mame snes -cart build/hello.sfc \
      -rompath dev/roms \
      -autoboot_script dev/smoke.lua \
      -skip_gameinfo \
      -video none -sound none -nothrottle \
      -seconds_to_run 3          # CI hang backstop; the Lua self-exits earlier
  ```
  Resolved open questions: `-debug` is **not** needed (the plain `spaces["program"]:read_u8`
  works without it — dropped); `-skip_gameinfo` is needed to bypass the warnings screen; Debian
  installs the binary to `/usr/games` (not on the default non-login PATH) → added to PATH in the
  Dockerfile. The lone `ALSA … /dev/snd/seq` line is a harmless headless-MIDI probe, non-fatal.
- **As-built Lua read API** (clean-room `dev/smoke.lua`; same API drdevtools' `spike_devmem.lua`
  uses, no GPL code copied):
  ```lua
  local sp = manager.machine.devices[":maincpu"].spaces["program"]
  sp:read_u8(0x7E0020)   -- WRAM mirror of the `sentinel` direct-page byte
  ```
- **Exit-code mechanism:** `manager.machine:exit()` always exits MAME 0. We therefore signal
  result on **stdout** (`SMOKE: PASS` / `SMOKE: FAIL addr=… got=0x… want=0x42`) and let the
  shell wrapper grep stdout to set the process exit code — the same stdout-assertion pattern
  drmon's `test_bridge.py` uses.

## Architecture / files

| File | Change | Notes |
|------|--------|-------|
| `dev/Dockerfile` | add `mame` (own layer, after the toolchain); `ENV PATH` += `/usr/games` | Debian installs the binary to `/usr/games`; mame layer last so a version bump never re-downloads the toolchain |
| `dev/smoke.lua` | **NEW** (clean-room) | frame-count periodic callback → read `os.getenv("SMOKE_ADDR")` byte → print `SMOKE: PASS/FAIL` → `manager.machine:exit()` |
| `dev/smoke.sh` | **NEW** | runs in-container: BIOS preflight (exit 2 if missing) → grep `sentinel` addr from `build/hello.map` → launch MAME headless with `-rompath` → exit 0 iff `SMOKE: PASS` |
| `dev/roms/s_smp/spc700.rom` | **user-supplied, gitignored** | the SPC700 IPL; never committed |
| `.gitignore` | add `/dev/roms/` | keep the copyrighted BIOS out of the repo |
| `dev/run.sh` | usage comment only | already generic: `dev/run.sh smoke` execs `dev/smoke.sh` |
| `.github/workflows/smoke.yml` | **NEW** | `dev/run.sh build` then `dev/run.sh smoke`; `@v6`; materializes the BIOS from a repo secret before the smoke step |
| `README.md` | doc the `smoke` target + BIOS prerequisite | under Build |

## Implementation steps

1. **Add MAME to the dev image.** New `mame` apt layer (after the toolchain layer); add
   `/usr/games` to `ENV PATH`. Record the resolved version (0.285) in the Dockerfile comment.
   Rebuild: `dev/run.sh build` still green (regression guard).
2. **Provide the SPC700 IPL out-of-band.** Place `spc700.rom` at `dev/roms/s_smp/spc700.rom`;
   add `/dev/roms/` to `.gitignore`. (On this dev machine: copied from `~/mame/roms/s_smp/`.)
3. **Write `dev/smoke.lua`** (clean-room). Periodic callback counts frames; after a settle count
   (default 60) it reads the byte at `SMOKE_ADDR`, prints `SMOKE: PASS` if `== 0x42` else
   `SMOKE: FAIL addr=0x… got=0x… want=0x42`, then `manager.machine:exit()`.
4. **Write `dev/smoke.sh`** (`set -euo pipefail`, `-h/--help`). BIOS preflight (exit 2 if the
   IPL is missing, with an actionable message). Derive the sentinel address from `build/hello.map`
   (`grep … || true` to survive no-match under `set -e`), map it into the WRAM mirror, launch
   MAME with the as-built headless invocation (`-rompath`, `-skip_gameinfo`), tee stdout to a log,
   and `exit 0` iff a `SMOKE: PASS` line is present (else 1).
5. **Negative control.** Confirm the assertion checks something: with a deliberately wrong
   `SMOKE_WANT`, verify `smoke` prints `SMOKE: FAIL` and exits **nonzero**. Guards against
   silent false-green.
6. **Wire CI.** `.github/workflows/smoke.yml`: checkout (`@v6`), materialize the BIOS from a repo
   secret (base64 → `dev/roms/s_smp/spc700.rom`), `dev/run.sh build`, `dev/run.sh smoke`. Runs
   headless on the GH runner's Docker.

## Verification

Each numbered step is the bar. Run it, paste raw output in a code block below it, mark PASS/FAIL,
write back here, then promote the TODO item.

1. **MAME present, version recorded.**
   `dev/run.sh smoke` (or a one-off `docker run … mame -help | head -1`) reports a MAME version;
   note it in the Dockerfile comment. (Evidence: version string.)

   **PASS** (2026-06-14):
   ```
   ==> MAME version: 0.285 (unknown)
   ```

2. **Build still green** (regression). `dev/run.sh build` produces a 32 KiB `build/hello.sfc`
   with checksum sum `0xFFFF`. (Evidence: `ls -l` + checksum line.)

   **PASS** (structural verification 2026-06-13, ROADMAP step 1; artifacts reused unchanged by the
   smoke run — `build/hello.sfc` 32768 bytes, checksum `0x3986 + 0xC679 = 0xFFFF`).

3. **Smoke PASS — the deliverable.** `dev/run.sh smoke` boots `hello.sfc` in MAME's `snes`
   driver headless, prints `SMOKE: PASS`, and exits **0**. This closes the run-half of ROADMAP
   step 1. (Evidence: full stdout incl. the `SMOKE:` line + `echo $?`.)

   **PASS** (2026-06-14) — clean run through the real entrypoint, image rebuilt, no PATH override:
   ```
   ==> MAME version: 0.285 (unknown)
   ==> smoke: ROM=hello.sfc  sentinel@$20 -> WRAM 0x7E0020  (expect 0x42)
   ALSA lib seq_hw.c:540:(snd_seq_hw_open) [error.sequencer] open /dev/snd/seq failed: No such file or directory
   SMOKE: PASS addr=0x7E0020 got=0x42 (ran 60 ticks)

   ==> smoke PASS
   === pipeline exit: 0 ===
   ```

4. **Negative control fails loudly.** With a deliberately wrong expected byte/address, `dev/run.sh
   smoke` prints `SMOKE: FAIL …` and exits **nonzero**. (Evidence: stdout + `echo $?`.)

   **PASS** (2026-06-14) — `SMOKE_WANT=0x99`:
   ```
   ==> smoke: ROM=hello.sfc  sentinel@$20 -> WRAM 0x7E0020  (expect 0x99)
   SMOKE: FAIL addr=0x7E0020 got=0x42 want=0x99
   ==> smoke FAIL
   === exit code: 1 (expect nonzero) ===
   ```

5. **CI green from clean checkout.** The `smoke.yml` workflow runs build + smoke green on a fresh
   clone (BIOS materialized from the `SNES_SPC700_ROM_B64` secret). (Evidence: GH Actions run URL/log.)
   **PENDING** — needs the secret set on the GitHub repo + a push.

## Risks & open questions

- **SPC700 IPL prerequisite (resolved, documented).** The `snes` driver requires `spc700.rom`.
  Supplied out-of-band via `-rompath dev/roms` (gitignored); CI materializes it from a secret.
  `dev/smoke.sh` exits 2 with an actionable message if it is missing. A fresh clone without the
  ROM cannot run the smoke loop until the BIOS is supplied — this is the one manual/secret input.
- **MAME version drift (resolved).** `ubuntu:26.04` ships **0.285** (newer than the 0.277 drmon
  validated against); the `spaces["program"]:read_u8` API works unchanged. Version is recorded by
  the smoke run; re-confirm if a future bump makes a read return `nil`.
- **Settle timing (resolved).** Default 60 ticks; the PASS run reported `got=0x42` at 60 ticks. If a
  future program reads `0x00`, the init chain hadn't reached `main()` — raise `SMOKE_SETTLE`
  (cheap, bounded by `-seconds_to_run`).
- **`-debug` (resolved).** Not needed — the plain read works without it; dropped.

## Out of scope / later

- **Regression corpus (≥5 programs)** — ROADMAP step 2 / TODO. This harness is its foundation;
  the corpus is a follow-up item, not this plan.
- **Cross-check emulator (bsnes-jg / Mesen2)** — M1, when fidelity matters.
- **DWARF round-trip via drmon DAP** — M2 / ROADMAP step 6; drdevtools' `mame-65816-gdbstub`
  already pre-wires it on the same MAME core.

## Links

- [ROADMAP.md](../ROADMAP.md) — M0 step 1/2, full milestone plan
- [INVESTIGATION.md](../INVESTIGATION.md) — drmon / DWARF tie-in (the "why MAME" downstream)
- drdevtools (GPL v2, **reference pattern only**): `devsys/tools/drmon/linux/mame_bridge.lua`,
  `spikes/spike_devmem.lua`, `test_bridge.sh`, `test_bridge.py`;
  `docs/plans/2026-06-11-drmon-mame-backend.md`,
  `docs/investigations/2026-06-11-mesen2-bsnes-plus-vs-drmon.md`
