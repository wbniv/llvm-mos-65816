# Soft-stack guard sweep, 2026-10-01

Observations for [`snes-soft-stack-static-data-collision`](../../../snes-soft-stack-static-data-collision.json): the soft-stack overlap guard in `build/jgxcheck` ([plan](../../../../plans/2026-10-01-soft-stack-guard.md)) run across every SNES corpus program and every demo gate. **608 runs, no overlap.**

Attribution: Claude Code 2.1.286 (`claude --version`), model Claude Sonnet 5.5 (`claude-sonnet-5-5`), `high` reasoning effort (T2 agent definition; not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## Identity

| Item | Value |
|---|---|
| Source | `85f7972a` (origin/main when the sweep started) plus the guard change; dither is the pre-move source |
| Toolchain | private snapshot of `build/llvm-mos-install` taken before the 2026-10-01 10:06 rebuild: clang-23 `254624ba26462f49b4c875b16eda3a1d10d7b766dd80175ec69b64bc96485b0c`, llc `cf5355d392bd37cdce2606c6bb19465db68a63e8ffa911613fabc474ffa2d5f7`, lld `c89b04cb2fb93cd3959ce8a1251ca1a967eb550b1d03e5dbdc81bf12f25323a4` |
| SDK | `build/install/bin/mos-snes.cfg` `f12c5b6aecb6cf483a505d2edc338886028ea9c93f` (snapshot; same file in the container as `/work/build/install`) |
| Harness | sweep binary `build/jgxcheck` `2c1ebd9ed763a3323e870ca441fb5382c27cdff951ef085dabfbdb24362626a3`; bsnes-jg 2.1.0 core + `dev/bsnes-jg-wramwatch.patch` (cpu.cpp base `9c3fa4a1…`). The final harness `04ac88b80f4a2844…` adds only the map-fallback `ALIGN` rounding; every sweep ROM had an ELF, so the map path was not used. `check.log` ran on the final binary |
| Corpus build | host `mos-clang --config mos-snes.cfg -mcpu=mosw65816 [+mos-a16 \| +mos-xy16] -Os` (the `tools/a16_fuzz.py compile_rom` command line), run until `corpus_result` equals the expected value (`JGX_POLL`, 1000-frame budget) |
| Demo gates | `JG_ONLY=1 dev/run.sh <gate>` in two disposable worktrees (`-stackguard`, `-stackguard2`), each with its own copy of this toolchain; `JGX_STACKGUARD_LOG` per gate |

## Files

- `report.txt`: every record, smallest margin first, then violations and a margin histogram.
- `corpus-records.tsv`, `demos-records.tsv`: the guard's TSV records (rom, program, config, status, min SP, end of static data, stack top, margin, pc, function, bounds source).
- `corpus-results.tsv`: corpus build and value results; `demos-results.tsv`: per gate rc, seconds, records, overlaps.
- `demo-verdict-lines.txt`: the SMOKE/RESULT/stackguard lines of each gate log. `check.log`: `dev/stackguard-check.sh`. `dither-O3-reproduce.log`: the old dither `-O3`/`-O2` rebuilt with `reproduce.sh gate` under the guard (231 B and 271 B overlap, `-O2` passes). `identity-sweep-start.txt`: hashes taken when the sweep started.

## Findings

- No program overlaps. Smallest margins: dither 76 B at the pre-move source (`main` at `$1FFA`, static data ends `$1FAE`), msquares 246 B, lsystem 577 B, vlastack 614 B, packrec 755 B, permscat 767 B, rdiff 1,060 B.
- Distribution (608 runs): 0 below zero; 2 in 64-255 B; 4 in 256-1,023 B; 192 in 1,024-4,095 B; 407 at 4,096 B or more; median 7,228 B. Corpus alone (249): minimum 5,024 B. Demo-gate ROMs (359): minimum 76 B.
- 207 runs never touch the soft stack (minimum SP stays at `$2000`). The deepest are the NMI-handler demos: `irqgate` 569 B and `dpbank` 305 B, both in `nmi`.
- After the dither buffer move (`07f4fe2f`, rebuilt on the same toolchain with `reproduce.sh gate`; `dither-post-move-records.tsv`) dither passes at `-O3` and `-O2` with margins of 2,073 B (`-O3` default), 2,033 B (`-O3` a16) and 2,107 B (`-O2` default); `main`'s soft-stack frame is unchanged at 313/353/279 B, and static data now ends at `$16AE`.
- Demo gates build their ROMs under their own names, so most records carry `config = unspecified`; the ROM path names the configuration where a gate builds several (`brkcop-a16`, `nmitally-xy16`, ...).
- Not covered: published ROMs with no ELF or map; gates with only a MAME leg or no emulator leg; `cartsize-canary` and `lzss-gallery` hit the 30-minute limit and left 39 and 2 records. `burning-ship`, `cosmzoom` and `percol` end `RESULT: FAIL` on a non-bsnes leg in this environment; their bsnes-jg `SMOKE:` line passes.
- Two containers (`lzss-gallery`, `cartsize-canary`) outlived their timed-out gates and kept running; they did not affect the results.
