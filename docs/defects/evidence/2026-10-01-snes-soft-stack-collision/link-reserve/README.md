# Link-time soft-stack reserve, 2026-10-01

Observations for [`snes-soft-stack-static-data-collision`](../../../snes-soft-stack-static-data-collision.json): every SNES linker script now requires `__soft_stack_min = 256` bytes between static data and `__stack` (proposed fix 2 of the record; the runtime guard, `guard-sweep/`, is proposed fix 1). N = 256 B was chosen by the user on 2026-10-01 from the guard sweep, whose smallest static-data-to-`__stack` gap is msquares at 338 B.

Attribution: Claude Code 2.1.286 (`claude --version`), model Claude Sonnet 5.5 (`claude-sonnet-5-5`), `high` reasoning effort (T2 agent definition; not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## The change

`PROVIDE(__soft_stack_min = 256);` and `ASSERT(__heap_start + __soft_stack_min <= __stack, "soft-stack reserve violated: …")` directly after `__stack = 0x2000;` in `platforms/snes/link.ld` (with the rationale comment), `snes-far`, `snes-hirom`, `snes-exhirom`, `snes-gallery`, and in the scripts `tools/snes-cartcanary.py emit-platform` generates. `__heap_start` is defined by the SDK's `noinit.ld` in all five, at the end of `.noinit`, so it is the end of static data in low WRAM (`.data`, `.bss`, `.noinit`); the one thing it does not count is a `.ram` section (nothing uses one). The runtime guard's bound is `max(__heap_start, end of any allocated section)`, identical for every program built here. `-Wl,--defsym=__soft_stack_min=N` overrides it for one link; lld prints a fixed assert string, so the message names the shortfall as `__heap_start + __soft_stack_min - __stack` rather than a number.

| Linker script | sha256 (first 16) |
|---|---|
| `platforms/snes/link.ld` | `f7648ebf372e5fdc` (pre-reserve `9eb48681d0088e37`, the script the original evidence used) |
| `platforms/snes-far/link.ld` | `d6d42942b6a86b0d` |
| `platforms/snes-hirom/link.ld` | `e8be0fb10a2368d4` |
| `platforms/snes-exhirom/link.ld` | `b170f1ade5833e59` |
| `platforms/snes-gallery/link.ld` | `9e40d964d9d3cd10` |

## Identity

| Item | Value |
|---|---|
| Source | `fa59e66d` (origin/main) plus the reserve change |
| Toolchain | `build/llvm-mos-install` after the 2026-10-01 10:06 rebuild (origin `0ec78ab1`): clang-23 `e532fbee9b78871393d3f990b72dc66cec8e7d04b3443621f40a7fd8cf3822b9`, lld `0d74dddcab805faf5e2848e9667af5af8b58bae2a66284099c1f63738e6094e1`, installed llc `cf5355d392bd37cdce2606c6bb19465db68a63e8ffa911613fabc474ffa2d5f7` (stale since 2026-09-28: `dev/toolchain.sh` builds llc into `build/llvm-mos/bin/` only, where it is `6f303945beb17ab3c8a5…`; nothing here runs llc) |
| SDK | the worktree copy of `build/install` (`/home/will/llvm-mos-65816-sdkres/build/install`) with the five `link.ld` replaced from `platforms/`; the shared `build/install` after the stamp rebuild is identical except for those scripts |
| Harness | `build/jgxcheck` `04ac88b80f4a2844…`, rebuilt from `dev/jgxcheck.cpp` against the patched bsnes-jg core |
| Limits | every compiler and emulator run under `ulimit -c 0` (and `ulimit -v 2000000` for host runs), with `timeout` |

## Red and green on the same input

Input: `examples/snes/dither.c` at `85f7972a` (git blob `1be807bc12c4fcb7eceff3d910468b7d7b87479f`, with `examples/65816/dither.h` blob `8c6c0f74c52e5552b5763dfd1965090a403bbec3`; the copies are in `../input/`), `-O3`, default `mosw65816`, LTO. Static data ends at `$1FAE`, 82 B below `__stack`. [`dither-85f7972a-link.log`](dither-85f7972a-link.log):

| SDK | Result |
|---|---|
| Pre-reserve (`link.ld` `9eb48681…`) | links, writes a 32 KiB ROM; on bsnes-jg it fails exactly as in the record: `STACKGUARD FAIL … overlaps static data by 231 B`, min SP `$1EC7`, `got=0x8185 want=0x80C4` |
| Reserve (`link.ld` `f7648ebf…`) | `ld.lld: error: soft-stack reserve violated: static data ends at __heap_start, leaving fewer than __soft_stack_min bytes below __stack (…)`, exit 1, no ROM |

[`dev/stackguard-check.sh`](../../../../../dev/stackguard-check.sh) (`dev/run.sh stackguard`) holds the same input as a regression, rebuilt from `../input/`:

- [`stackguard-check-reserve-sdk.log`](stackguard-check-reserve-sdk.log): 21 passed, 0 failed. New legs: the 85f7972a dither is rejected with the message and no ROM; with `--defsym=__soft_stack_min=0` it links with a gap of 82 B; the boundary is exact on that input (`=82` links, `=83` is rejected); the current dither (`07f4fe2f`, buffers in high WRAM) links with 2,386 B; a synthetic program leaving exactly 256 B links and one leaving 254 B is rejected; the same pair on all five installed platform scripts; the generated platform carries the lines.
- [`stackguard-check-pre-reserve-sdk.log`](stackguard-check-pre-reserve-sdk.log): the same script against a copy of the pre-reserve SDK (`SDK_INSTALL=`): 13 passed, 8 failed, every link-time leg red (the 85f7972a dither links silently).

## No current program is rejected

| Sweep | Result |
|---|---|
| Corpus, 83 programs x default / `+mos-a16` / `+mos-xy16` at `-Os`, linked and run on bsnes-jg with the guard ([`corpus-links-results.tsv`](corpus-links-results.tsv), [`corpus-links-records.tsv`](corpus-links-records.tsv)) | 249 of 249 build, link and pass; smallest gap 5,228 B (vlastack_sim) |
| 35 demo gates with the smallest gaps in the earlier sweep (every gate with a ROM under 2,500 B of room, `JG_ONLY=1`; [`demos-lowgap-results.tsv`](demos-lowgap-results.tsv), [`demos-lowgap-records.tsv`](demos-lowgap-records.tsv)) | 35 of 35 link and run their bsnes-jg leg; smallest gap 338 B (msquares), then vlastack 670 B, packrec 786 B, permscat 790 B; `percol` exits 1 in its MAME snapshot leg, as it did in the 2026-10-01 guard sweep; the soft-stack guard reports no overlap on any |
| Corpus and `corpus-a16` in the shared checkout after the SDK stamp rebuild (reserve not yet installed) | `dev/run.sh corpus` 84 of 84 PASS; `dev/run.sh corpus-a16` 83 of 83 PASS (default == `+mos-a16` == `+mos-xy16` on MAME and bsnes-jg), 4,444 s |
| Reserve installed in the shared SDK: all demos in `dev/run.sh build`, then `corpus` / `corpus-a16` | recorded in the install addendum below |

The earlier 359-ROM demo records (`../guard-sweep/demos-records.tsv`) have a smallest gap of 82 B (the pre-move dither, since fixed) then 338 B (msquares); the other 357 ROMs have 670 B or more.

## SDK rebuild on toolchain change (same session)

`dev/build.sh` now stamps `build/.mos-toolchain` with the prefix plus the sha256 of the installed clang, llc and lld (`dev/toolchain-stamp.sh`). Before the change `build/install` held libraries from 2026-09-15 under a path-only stamp. The first `dev/run.sh build` after it printed `==> toolchain changed (/work/build/llvm-mos-install -> /work/build/llvm-mos-install clang=e532fbee… llc=cf5355d3… lld=0d74ddda…); wiping SDK build tree` and rebuilt 984 SDK targets. [`sdk-install-before-stamp-change.sha256`](sdk-install-before-stamp-change.sha256) (567 files) against [`sdk-install-after-stamp-change.sha256`](sdk-install-after-stamp-change.sha256) (537 files): 30 files changed, all `libcrt0.a` (29) and geos-cbm `libcrt.a`; `libc.a`, the common `libcrt.a` (the builtins merge), `crt0.o`, `link.ld` and every `.cfg` are byte-identical; the 30 removed files are the generated `snes-cart-*` / `snes-video-exhirom` platforms (15 `.cfg` + 15 `link.ld`) that individual gates install with `tools/snes-cartcanary.py emit-platform` and re-create on their next run.

## Install addendum: the reserve in the shared SDK

Installed with `dev/run.sh build` in the main checkout at `f7e63e9c`, under `flock -w 14400 build/.heavy-build.lock`, with no other `dev/run.sh`, `jgxcheck` or MAME process reading `build/install`.

- **The stamp held.** The build log has no `toolchain changed` line, so the SDK build tree was kept: ninja ran 10 steps (the SNES platform's own objects, whose sources `dev/build.sh` re-copies on every run) instead of the 984 of the stamp rebuild, and the results are byte-identical (the other half of `dev/toolchain-stamp-check.sh`: unchanged toolchain, no rebuild).
- **Installed scripts.** [`sdk-install-after-reserve.sha256`](sdk-install-after-reserve.sha256) against [`sdk-install-after-stamp-change.sha256`](sdk-install-after-stamp-change.sha256) (537 files each): exactly seven files differ, the five `platforms/snes*/link.ld` (each now byte-identical to its source) and the two generated platforms the build regenerates (`snes-cart-battery-lorom512k`, `snes-cart-seamdemo`, from `tools/snes-cartcanary.py emit-platform`, which carry the reserve). Every library, `crt0.o` and `.cfg` is byte-identical.
- **Every demo links.** `dev/run.sh build` builds 296 programs (default, `-Os`, each demo's own markers: the far, gallery and generated platforms included) with the reserve in place and no `soft-stack reserve violated`. It reports three failures, `ascast`, `ascast_sim` (`unable to legalize instruction … G_MERGE_VALUES … in function: ac_to_far`) and `lzss-gallery` (`ran out of registers during register allocation in function 'record_result'`). They are compiler errors that do not involve the linker script and are not new: [`preexisting-demo-build-failures.log`](preexisting-demo-build-failures.log) compiles them by hand with the pre-0071 toolchain (clang-23 `254624ba…`) and SDK copy and gets the same two errors.
- **Corpus.** `dev/run.sh corpus` after the install: 84 of 84 PASS (491 s). `corpus-a16` was not re-run after the install; its 249 default / `+mos-a16` / `+mos-xy16` ROMs were linked against the same five scripts in the sweep above (bsnes-jg leg) and ran clean before it.
