# Soft-stack overlap guard in the bsnes-jg probe

Status 2026‑10‑01: implemented and swept; results in [Results](#results). Defect record: [`snes-soft-stack-static-data-collision`](../defects/snes-soft-stack-static-data-collision.json). Investigation: [dither `-O3` soft-stack collision](../investigations/2026-10-01-dither-o3-soft-stack-collision.md), proposed fix 1. The user approved this check as the first guard on 2026‑10‑01; the link-time reserve (proposed fix 2) stays deferred until the measured depths below are in.

Attribution: Claude Code 2.1.286 (`claude --version`), model Claude Sonnet 5.5 (`claude-sonnet-5-5`), `high` reasoning effort (T2 agent definition; the effort is not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## Contract

Every bsnes-jg run of an SDK-built ROM records the lowest soft-stack pointer and fails when it is below the end of static data. The bounds come from the build, never from constants. A run with no overlap prints exactly what it printed before. Nothing in a demo's source changes.

- **Observation.** The soft-stack pointer is `__rc0`/`__rc1`. `MOSFrameLowering::offsetSP` stores the low byte, then the high byte, so sampling at instruction boundaries sees a torn pair (up to 255 B below the true SP after an epilogue carry). A write watch in the bsnes-jg core (`dev/bsnes-jg-wramwatch.patch`, applied by `dev/xcheck.sh`) reports each WRAM write to `__rc0`/`__rc1`; `tools/stackguard.h` commits a new SP when the high byte lands.
- **Bounds.** `__rc0`, `__stack` and `__heap_start` from `<rom>.elf`, else from the lld map; end of static data is the larger of `__heap_start` and the end of any allocated section in `[$0100, __stack)`. Margin = min SP − end of static data.
- **Failure.** The `SMOKE:` line carries `stackguard: soft stack overlaps static data by N B (program=…, config=…)`; stderr has the minimum SP, the function, the bounds source and the ROM; the exit code is 4 when the value check passed.
- **Wiring.** `build/jgxcheck` is shared by every gate, so any gate that honours its exit code or `SMOKE:` line is covered. The corpus engine opts in explicitly and also gives its default and xy16 ROMs a stack-only bsnes-jg run. Fuzz, Csmith and torture keep the guard off.

## Steps

1. Patch the core and arm the watch from `dev/jgxcheck.cpp` (`tools/stackguard.h`).
2. Fold the verdict into the `SMOKE:` line; add `JGX_STACKGUARD`, `_ONLY`, `_LOG`, `JGX_PROGRAM`, `JGX_CONFIG`.
3. Wire the corpus engine (`tools/a16_fuzz.py`) and `dev/run.sh` env forwarding; make `dev/xcheck.sh` apply the patch and rebuild.
4. Regression check `dev/stackguard-check.sh` (`dev/run.sh stackguard`, `task stackguard`).
5. Sweep every corpus program (default, a16, xy16) and every demo gate with `dev/stackguard-sweep.py`; record violations on the defect record.
6. Document the failure mode in [`agent-handoff.md`](../agent-handoff.md).

No mockup: the only new on-screen output is the failure message, shown verbatim in the handoff and below.

```
jgxcheck: STACKGUARD FAIL: dither [-O3 default] soft stack overlaps static data by 231 B
  min soft SP $1EC7 (first reached near pc $806B, in main) < end of static data $1FAE (__heap_start); stack top $2000, margin -231 B
  rom=…/rom.sfc  bounds=…/rom.sfc.elf
  Frames in [$1EC7, $1FAE) alias .bss/.noinit; see docs/defects/snes-soft-stack-static-data-collision.json
SMOKE: FAIL off=0x1CE7 len=2 got=0x0000 want=0x80C4 stackguard: soft stack overlaps static data by 231 B (program=dither, config=-O3 default)
```

## Results

Toolchain for every measurement: a private snapshot of `build/llvm-mos-install` taken before the 2026‑10‑01 10:06 rebuild (clang-23 `254624ba…`, llc `cf5355d3…`, lld `c89b04cb…`, SDK `mos-snes.cfg` `f12c5b6a…`), run on source `85f7972a`. Harness: `build/jgxcheck` (sweep binary `2c1ebd9e…`; final binary `04ac88b8…`, which differs only in the map-fallback `ALIGN` fix, and no sweep ROM used the map path). Details: [`guard-sweep/README.md`](../defects/evidence/2026-10-01-snes-soft-stack-collision/guard-sweep/README.md).

Verification steps (the steps above are the spec; raw output is in `guard-sweep/`):

1. Regression check, `dev/stackguard-check.sh` (`check.log`): 10 of 10 pass, including dither `-O3` flagged at 231 B (min SP `$1EC7` against `__heap_start` `$1FAE`), the `-O2` ROM clean at 82 B, a synthetic ELF-bounds overlap caught although its result matches, the torn-SP control, and the corpus engine failing an overlapping program in default, a16 and xy16. PASS.
2. Old dither at `-O3` rebuilt with `reproduce.sh gate` (`dither-O3-reproduce.log`): default `SMOKE: FAIL … stackguard: soft stack overlaps static data by 231 B`, a16 by 271 B, `-O2` passes. PASS.
3. Bit-identical on programs without an overlap: 12 corpus ROMs give byte-identical stdout, stderr and exit code with the stock harness and the guarded one, and no demo gate log contains a `SMOKE: FAIL` or a `stackguard` line. PASS.
4. Sweep: 608 runs (249 corpus, 359 demo-gate ROMs from 154 gates), 0 overlaps; smallest margins dither 76 B (pre-move source), msquares 246 B, lsystem 577 B. PASS.

Known limits: the demo gates ran with `JG_ONLY=1` (no MAME leg); `burning-ship`, `cosmzoom` and `percol` end `RESULT: FAIL` on their MAME-side leg in this environment while their bsnes-jg `SMOKE:` line passes; `cartsize-canary` and `lzss-gallery` hit the 30-minute limit after writing 39 and 2 records. The check covers ROMs with an ELF or lld map beside them: published ROMs without either are not checked, and gates with no jgxcheck leg or only a MAME leg are not covered.
