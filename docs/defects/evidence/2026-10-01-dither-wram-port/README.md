# Dither fits at `-O3`: the frame buffer moved out of low WRAM

Canonical record: [`snes-soft-stack-static-data-collision`](../../snes-soft-stack-static-data-collision.json) (stays `confirmed`: the platform guard is separate work). Investigation: [2026‑10‑01 dither `-O3` soft-stack collision](../../../investigations/2026-10-01-dither-o3-soft-stack-collision.md). Baseline evidence: [`../2026-10-01-snes-soft-stack-collision/`](../2026-10-01-snes-soft-stack-collision/README.md).

Attribution: Claude Code 2.1.286 (`claude --version`), model Claude Sonnet 5.5 (`claude-sonnet-5-5`), T2 agent definition (`t2-sonnet-high`; the reasoning effort is not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Done with the user's approval of 2026‑10‑01 to fix the demo's memory budget. No compiler, `vendor/`, patch or platform change.

## What changed

`examples/snes/dither.c` kept a 2304 B band-index buffer (`App.out[48 × 48]`) in the 8 KB low WRAM that static data shares with the soft stack. It now lives in high WRAM at `$7E:2000` and is reached through the WRAM data port (`platforms/snes/snes_wram.h`: `WMADDL/M/H`, `WMDATA`, auto-incrementing). The frame is written once per pixel in ascending order by the dither and read back once per pixel in the same order by the blit, so the port's auto-increment is all the addressing it needs.

`examples/65816/dither.h` turns the `ds_dither` body into the macro `DS_DEFINE_DITHER(NAME, OUTT, PUT)` (the `buddha.h` idiom). The near instance `ds_dither` (`DS_PUT_NEAR`: `out[i] = v`) is what the gate, the host oracle and the corpus slice use; the demo adds `ds_dither_port` (`DS_PUT_PORT`: `*out = v`). The gate, its static `out[576]` and the near `ds_dither` are unchanged. The corpus slice object (`examples/snes/corpus/dither_sim.c`) is byte-identical before and after in 9 of 9 configurations ([`logs/corpus-identity.txt`](logs/corpus-identity.txt)).

**Moved:** the 2304 B frame buffer only. **Not moved:** the gate's `out[576]` (cold, but moving it alone leaves 658 B, under the 512 B target once the 353 B `-O3` frame is counted), the 4 KB canvas `chr` (shared `snesgfx` header, DMA'd from a near pointer by every canvas demo), and `.noinit` (the compiler's static stack).

### Why the WRAM port and not far pointers

The brief pointed at the far-pointer idiom of `lzss-gallery`, `lsystem`, `buddha`, `seamdemo` and `blossom`. Far pointers do not build dither in default `mosw65816`. A first version with `address_space(2)` failed with:

```
LLVM ERROR: unable to legalize instruction: %52:_(s32) = G_MERGE_VALUES %6:_(s8), %1591:_(s8), %1593:_(s8), %6:_(s8) (in function: dither_frame)
```

`dev/build.sh` handles this with the `mos-a16-only` source marker (a far pointer needs `+mos-a16`). Marking dither `mos-a16-only` would drop its default-mode builds, which the investigation and this task gate, and would end the demo's "no far pointers, builds default, `+mos-a16` and `+mos-xy16`" property. The WRAM data port works in every mode, and `snes_wram.h` documents it for exactly this case. Nothing else in the program uses the port, so its address is only set in `dither.c`. The coordinator accepted this choice.

## Identity

| Item | sha256 |
|---|---|
| `build/llvm-mos-install/bin/clang-23` (a real copy of `/home/will/llvm-mos-65816/build/llvm-mos-install`, same hash in the main checkout) | `254624ba26462f49b4c875b16eda3a1d10d7b766dd80175ec69b64bc96485b0c` |
| `…/lld` | `c89b04cb2fb93cd3959ce8a1251ca1a967eb550b1d03e5dbdc81bf12f25323a4` |
| `…/llc` | `cf5355d392bd37cdce2606c6bb19465db68a63e8ffa911613fabc474ffa2d5f7` |
| `build/jgxcheck` (bsnes-jg gate) | `4c9a88d21a6098b4f0a4443aebf03a75c7f6fd5f8b7dee18a4ac5f4d76e7006f` |
| `build/jgxcycles` (cycle probe, copy of the o2-large one) | `3c04775feb68c4d25d904df8b079f0de5a8a58a8e20c7e62adde31060cb5bec3` |

Worktree `/home/will/llvm-mos-65816-ditherwram`, branch `wt/dither-wram-headroom`, off `origin/main` `85f7972a`. "Before" is that commit's `dither.c`/`dither.h`. Every compiler and emulator run was under `ulimit -c 0` (compilers also `ulimit -v 2000000`) and `timeout`, with at most 3 jobs.

## Results

### Margin and gate, per configuration

`reproduce.sh gate OUT LEVEL MODE stock` for default and `a16`, [`tools/gate-xy16.sh`](tools/gate-xy16.sh) for `+mos-a16,+mos-xy16`; bsnes-jg frame 600, `corpus_result == 0x80C4`. Margin is `__stack` (`$2000`) minus `__heap_start` (end of static data). Before: `$1FAE`, 82 B.

| Config | Before | After: end of static data, margin | Gate after |
|---|---|---|---|
| `-O2` default | PASS, margin 82 B | `$16AE`, 2386 B | PASS 0x80C4 |
| `-O2` a16 | PASS, 82 B | 2386 B | PASS |
| `-O2` xy16 | not run | 2386 B | PASS |
| `-O3` default | FAIL 0x0000 | 2386 B | PASS |
| `-O3` a16 | FAIL 0x0000 (record) | 2386 B | PASS |
| `-O3` xy16 | not run | 2386 B | PASS |

MAME frame 900, `dev/dither.lua`, run through `reproduce.sh mame` in `dev/container.sh`: PASS 0x80C4 at `$7E:13E7` for all six ([`logs/mame.log`](logs/mame.log)). Gate logs: `logs/gate-*.log`. The host oracle `tools/dither-sim.c` still prints `dither gate_crc = 0x80C4`.

### Measured soft-stack depth ([`tools/jgxstackhw.cpp`](tools/jgxstackhw.cpp))

The tool fills `[$16AE, $2000)` with a canary byte when crt0 sets the soft stack pointer, runs 900 frames and scans for the first written byte. A byte written with the canary's own value would go unnoticed, so the depth is a lower bound by at most that byte. On the unchanged ROMs with `LOW = $1FAE` it reports all 82 B written at `-O3` default and 0 B at `-O2` default, so it does detect the original overflow.

| Config | Lowest byte written | Depth | Untouched of 2386 B |
|---|---|---|---|
| `-O2` default | `$1EE9` | 279 B | 2107 B |
| `-O2` a16 | `$1EE2` | 286 B | 2100 B |
| `-O2` xy16 | `$1EE2` | 286 B | 2100 B |
| `-O3` default | `$1EC7` | 313 B | 2073 B |
| `-O3` a16 | `$1E9F` | 353 B | 2033 B |
| `-O3` xy16 | `$1E9C` | 356 B | 2030 B |

The worst case is main's own frame; callees add nothing measurable. At `-O2` main's frame grew from 0/2 B to 279/286 B: with 3 gate call sites instead of 4, the inliner now inlines the near `ds_dither` into main. This is harmless with this margin, but it is a code change in `-O2` main.

### Master clocks at `-O2` ([`tools/clocks.sh`](tools/clocks.sh), [`logs/clocks-O2.tsv`](logs/clocks-O2.tsv))

The o2-large method: bsnes-jg cycle probe from `main`'s entry to the instruction that writes the expected `corpus_result`, two runs per ROM (identical), `-O2 -flto`, DITHER_RUN_FRAMES = 6 and 12. Every row passes against the host oracle's folds (0x15CC, 0x21FF). Before uses the original harness [`o2-large/harness/dither_run.c`](../2026-09-30-native-width-pressure-sets/o2-large/harness/dither_run.c); after uses [`harness/dither_run.c`](harness/dither_run.c), which reads the band back through the port in the same order, so the folded byte stream is identical. Loop = (12-frame − 6-frame) / 6 per frame; setup = 6-frame − 6 × loop.

| Mode | 6 frames before → after | 12 frames before → after | Loop per frame before → after | Setup before → after |
|---|---|---|---|---|
| default | 249,197,934 → 209,134,912 | 455,444,096 → 374,724,946 | 34,374,360 → 27,598,339 (−19.7%) | 42,951,772 → 43,544,878 (+1.4%) |
| a16 | 244,321,570 → 190,744,608 | 447,427,806 → 340,731,068 | 33,851,039 → 24,997,743 (−26.2%) | 41,215,334 → 40,758,148 (−1.1%) |
| a16xy16 | 262,516,688 → 186,315,746 | 483,873,544 → 332,027,982 | 36,892,809 → 24,285,373 (−34.2%) | 41,159,832 → 40,603,510 (−1.4%) |

The change is faster, not slower: a `sta $2180` replaces the indexed-array address arithmetic in the dither's inner loop and the blit. The `-O3` before value cannot be measured, since the unmodified demo does not complete its gate there.

### Framebuffer ([`tools/framebuffer.sh`](tools/framebuffer.sh), [`harness/dither_png.c`](harness/dither_png.c), [`logs/framebuffer.log`](logs/framebuffer.log))

The canvas ORs its plots and never clears, so the picture depends on how many dither iterations ran, not on how many video frames elapsed. A faster build is further along at a fixed emulator frame, so a plain frame-N screenshot comparison is meaningless (488 differing pixels at frame 2000 in default `-O2`, unchanged for frames 1994 to 2006). `harness/dither_png.c` keeps the real v-blank wait and freezes the demo once its `t` reaches `3 × PNG_K` (10), so both builds stop at the same iteration. The jgxcheck PNG after 1500 frames is **byte-identical (sha256 `f5742ebc454bfe23…`) for all nine builds**: before at `-O2` in default, a16, a16xy16, and after at `-O2` and `-O3` in the same three modes. The picture has five distinct colours ([`logs/framebuffer-K10.png`](logs/framebuffer-K10.png)).

### `-verify-machineinstrs`

`reproduce.sh verify OUT LEVEL MODE` on the changed demo's precodegen bitcode: exit 0 at `-O2` and `-O3`, default and a16 ([`logs/verify-*.log`](logs/verify-*.log)). `+mos-xy16` was not run.

## Reproduce

```sh
E=docs/defects/evidence/2026-10-01-dither-wram-port
R=docs/defects/evidence/2026-10-01-snes-soft-stack-collision/tools/reproduce.sh
bash $R gate OUT O3 default stock          # after: exit 0, got=0x80C4, 2386 B margin
bash $E/tools/gate-xy16.sh OUT O3
dev/container.sh -- bash $R mame OUT       # OUT holds OUT/<name>/rom.sfc(+.elf)
bash $E/tools/clocks.sh OUT after . $E/harness O2        # needs build/jgxcycles
bash $E/tools/framebuffer.sh OUT SRCROOT_BEFORE .
```

`reproduce.sh gate` builds the current `examples/snes/dither.c`, so on this tree it no longer reproduces the red baseline. **Replay the baseline from a checkout of `85f7972a`** (`git worktree add /tmp/base 85f7972a`, then run that checkout's `reproduce.sh gate OUT O3 default stock`; it needs the same `build/` toolchain) to get `SMOKE: FAIL … got=0x0000`. `tools/clocks.sh` and `tools/framebuffer.sh` take a source root for "before" (a directory with `examples/snes/dither.c` and `examples/65816/dither.h` from `85f7972a`).

## Publication

[biohack.net/snes/dither/](https://biohack.net/snes/dither/) is live (HTTP 200) and was not republished. A future republish moves `corpus_result` from `$1CE7` to `$13E7`, so the site manifest's self-check offset must be regenerated with `dev/sync-manifest-offsets.py`.

## Not covered

The platform guard (a link-time soft-stack reserve, a soft-SP low-water check in the probe, or `nonreentrant main`) is separate work, so the defect record stays open. The 512 B target is met by the demo alone, with a 2030 B minimum margin; another demo that grows into the soft stack would still collide silently.
