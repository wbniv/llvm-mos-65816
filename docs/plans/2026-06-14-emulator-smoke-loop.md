# M0 — emulator smoke loop (MAME, headless)

**Date:** 2026-06-14
**Status:** Planned
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
- **Proven MAME invocation** (drdevtools `test_bridge.sh`, MAME 0.277, SNES, headless):
  ```sh
  env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
    mame snes -cart build/hello.sfc \
      -autoboot_script dev/smoke.lua \
      -video none -sound none -nothrottle \
      -seconds_to_run 2          # CI hang backstop; the Lua self-exits earlier
  ```
  (`-debug -debugger none` is only needed for debugger-object access like `wpset`; a plain
  `spaces["program"]:read_u8` does **not** require it. Confirm during impl and drop `-debug`
  if the read works without it — fewer moving parts.)
- **Proven Lua read API** (drdevtools `spike_devmem.lua`):
  ```lua
  local sp = manager.machine.devices[":maincpu"].spaces["program"]
  sp:read_u8(0x7E0020)   -- WRAM
  ```
- **Exit-code mechanism:** `manager.machine:exit()` always exits MAME 0. We therefore signal
  result on **stdout** (`SMOKE: PASS` / `SMOKE: FAIL addr=… got=0x… want=0x42`) and let the
  shell wrapper grep stdout to set the process exit code — the same stdout-assertion pattern
  drmon's `test_bridge.py` uses.

## Architecture / files

| File | Change | Notes |
|------|--------|-------|
| `dev/Dockerfile` | add `mame` to the apt line | one package; pin/record the version (Lua API drifts across MAME releases) |
| `dev/smoke.lua` | **NEW** (clean-room) | frame-count periodic callback → read `os.getenv("SMOKE_ADDR")` byte → print `SMOKE: PASS/FAIL` → `manager.machine:exit()` |
| `dev/smoke.sh` | **NEW** | runs in-container: grep `sentinel` addr from `build/hello.map` → export `SMOKE_ADDR` → launch MAME headless → capture stdout → exit 0 iff `SMOKE: PASS` |
| `dev/run.sh` | none | already generic: `dev/run.sh smoke` execs `dev/smoke.sh`. Update its usage comment only. |
| `.github/workflows/smoke.yml` | **NEW** | `dev/run.sh build` then `dev/run.sh smoke` on push/PR; `actions/checkout@v6` |
| `README.md` | doc the `smoke` target | one line under Build |

## Implementation steps

1. **Add MAME to the dev image.** Append `mame` to `dev/Dockerfile`'s apt install; record the
   resolved version in a comment. Rebuild: `dev/run.sh build` still green (regression guard).
2. **Write `dev/smoke.lua`** (clean-room). Periodic callback counts frames; after a small settle
   count (≈30 frames — proven sufficient in the spike) it reads the byte at `SMOKE_ADDR`,
   prints `SMOKE: PASS` if `== 0x42` else `SMOKE: FAIL addr=0x… got=0x… want=0x42`, then
   `manager.machine:exit()`.
3. **Write `dev/smoke.sh`** (`set -euo pipefail`, `-h/--help`). Derive the sentinel address from
   `build/hello.map` (`grep … | … || true` to survive no-match under `set -e`), export
   `SMOKE_ADDR`, launch MAME with the proven headless invocation, tee stdout to a log, and
   `exit 0` iff a `SMOKE: PASS` line is present (else nonzero).
4. **Negative control.** Confirm the assertion actually checks something: point `SMOKE_ADDR` at a
   byte known *not* to be `0x42` (or temporarily change the expected value) and verify `smoke`
   exits **nonzero** with `SMOKE: FAIL`. Guards against silent false-green.
5. **Wire CI.** `.github/workflows/smoke.yml`: checkout (`@v6`), `dev/run.sh build`,
   `dev/run.sh smoke`. Runs headless on the GH runner's Docker.

## Verification

Each numbered step is the bar. Run it, paste raw output in a code block below it, mark PASS/FAIL,
write back here, then promote the TODO item.

1. **MAME present, version recorded.**
   `dev/run.sh smoke` (or a one-off `docker run … mame -help | head -1`) reports a MAME version;
   note it in the Dockerfile comment. (Evidence: version string.)

2. **Build still green** (regression). `dev/run.sh build` produces a 32 KiB `build/hello.sfc`
   with checksum sum `0xFFFF`. (Evidence: `ls -l` + checksum line.)

3. **Smoke PASS — the deliverable.** `dev/run.sh smoke` boots `hello.sfc` in MAME's `snes`
   driver headless, prints `SMOKE: PASS`, and exits **0**. This closes the run-half of ROADMAP
   step 1. (Evidence: full stdout incl. the `SMOKE:` line + `echo $?`.)

4. **Negative control fails loudly.** With a deliberately wrong expected byte/address, `dev/run.sh
   smoke` prints `SMOKE: FAIL …` and exits **nonzero**. (Evidence: stdout + `echo $?`.)

5. **CI green from clean checkout.** The `smoke.yml` workflow runs build + smoke green on a fresh
   clone. (Evidence: GH Actions run URL/log.)

## Risks & open questions

- **MAME version drift.** `ubuntu:26.04` may ship newer than the `0.277` drmon validated against;
  the `spaces["program"]:read_u8` API is stable but pin/record the version and re-confirm if a
  read returns `nil`.
- **`snes` driver romset nag.** drmon runs raw `.sfc` carts in `mame snes -cart` with no system
  BIOS (SNES needs none) across 19/19 tests, so this path is proven — but if MAME complains about
  a missing parent romset on `26.04`, copy drmon's exact flags/env.
- **Settle timing.** 30 frames was enough in the spike; if `sentinel` reads `0x00`, the init chain
  hadn't reached `main()` yet — raise the frame count (cheap, bounded by `-seconds_to_run`).
- **`-debug` necessity.** Resolve in step 2/3 whether the plain read needs `-debug -debugger none`;
  prefer dropping it.

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
