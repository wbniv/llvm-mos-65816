# llvm-mos-65816

Bringing an **optimizing, open-source C compiler to the WDC 65816** by way of
[llvm-mos](https://github.com/llvm-mos/llvm-mos) — and the SNES platform support
to use it on. This is the structural gap that Zardoz / WDC816CC filled
commercially for SNES development in the 1990s and that remains unfilled for
open-source toolchains today.

## Two layers

The 65816 splits cleanly into a CPU layer and machine layers — and so does this work:

| Layer | What | Where it lands |
|-------|------|----------------|
| **65816 codegen** | 24-bit addressing, 16-bit `A`/`X`/`Y`, calling convention — *machine-agnostic*, benefits SNES and Apple IIgs alike | upstream **llvm-mos** (the compiler) |
| **Platforms** | per-machine SDK: memory map, ROM header, I/O registers, runtime | upstream **llvm-mos-sdk** (`mos-platform/<machine>/`) |

`platforms/snes/` is the first 65816 platform. Others (e.g. Apple IIgs) could
follow; the codegen they'd share is the prize.

## Status

**M0 — SNES test bench: complete.** Valid bootable LoROM `.sfc` from C, 7/7 corpus
tests green in CI, dual-emulator (MAME + bsnes-jg) differential.

**M1 — Far pointers: substantially complete.** 24-bit absolute-long load/store
working across banks; far calls (JSL/RTL) deferred pending upstream ABI blessing.

**M2 — 16-bit accumulator codegen: in progress.** `+mos-a16` enables the 65816's
native 16-bit accumulator mode. Implemented and differential-verified on both
emulators: full s16 ALU (add/sub/bitwise/shifts/cmp/inc/dec), constant-immediate
folds, indirect and absolute load/store, cross-block REP/SEP mode-tracking,
A16-threading (post-RA store/reload elimination), equality-as-value peephole.
40/40 corpus, 31 micro-tests, 6 realistic kernels, 2 combinatorial tests, 50/50
fuzz. CI green. **In progress:** s32 (`long`/`int32_t`) support; XY16 (`+mos-xy16`).

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and contribution rationale.

## Layout

```
platforms/snes/   the SNES SDK platform (crt0, header, link script, registers)
examples/snes/    smoke-test C programs
tools/            host tools (SNES checksum patcher)
dev/              containerized build env (Dockerfile + scripts) — host stays clean
docs/             roadmap + investigation
vendor/           upstream llvm-mos-sdk, cloned at build time (gitignored)
build/            build output (gitignored)
```

## Build

Everything runs in a throwaway container; nothing is installed on the host.

```sh
dev/run.sh build      # vendor the SDK, build it + our platform, build the smoke ROM
dev/run.sh validate   # structural checks on build/hello.sfc
dev/run.sh compile    # fast recompile after editing the linker script / headers
dev/run.sh smoke      # boot build/hello.sfc headless in MAME, assert it ran (quick)
dev/run.sh corpus     # run the regression corpus: assert every program vs expected.tsv
dev/run.sh repro      # clean-room: export HEAD, build + corpus from scratch (no local state)
dev/run.sh toolchain  # build llvm-mos (clang/lld) FROM SOURCE -> build/llvm-mos-install (for M1 codegen)
```

The first `build` clones upstream `llvm-mos-sdk` into `vendor/` and compiles the
SDK against the pinned llvm-mos toolchain baked into the image (~1–2 min), then builds
every `examples/snes/**/*.c` to its own `.sfc`.

By default the bench uses a **prebuilt** llvm-mos toolchain (immutable). Codegen work
(M1+) needs the compiler built from source: `dev/run.sh toolchain` clones llvm-mos and
builds a lean `clang`+`lld` (dropping `clang-tools-extra`; ~26 min cold) into
`build/llvm-mos-install`. Point the bench at it with `MOS_TOOLCHAIN`:

```sh
MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build && dev/run.sh corpus
```

The self-built compiler is byte-equivalent to the prebuilt, so the corpus stays 7/7 —
that's the green baseline every codegen change is measured against. `build.sh` wipes the
SDK build tree automatically when the toolchain changes. See
[the M1 Phase 0 plan](docs/plans/2026-06-14-m1-from-source-toolchain.md).

`smoke` boots `hello.sfc` in MAME's `snes` driver (the same emulation core drdevtools'
`drmon` debugs against) and asserts the `sentinel == 0x42` byte in WRAM — the fast
liveness check. `corpus` is the **correctness baseline**: each program in
`examples/snes/corpus/` computes a result that the host checks against
`examples/snes/corpus/expected.tsv`, exercising a distinct slice of codegen (ALU,
control flow, arrays/`.rodata`, structs/pointers, calls/recursion, crt0 init). It is
the regression net for when M1/M2 change codegen — same source must keep producing the
same bytes. *Add a program:* drop a `.c` in `corpus/` that writes `volatile uint16_t
corpus_result`, run `build`, then record its value (and how you derived it) in
`expected.tsv`. See
[docs/plans/2026-06-14-emulator-smoke-loop.md](docs/plans/2026-06-14-emulator-smoke-loop.md)
and [the corpus plan](docs/plans/2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).

`repro` is the reproducibility gate: it exports the committed `HEAD` to a temp dir
(no `build/`, no caches, no uncommitted edits), supplies the BIOS, and runs the full
build + corpus there — proving the bench rebuilds from the repo alone. The same check
exists as a manual-only GitHub Actions workflow (`snes-smoke`, `workflow_dispatch`),
parked until the repo goes public / the upstream PR is cut.

**One prerequisite (supplied, not committed):** MAME's `snes` driver needs the 64-byte
SPC700 APU IPL ROM. It is Nintendo content, so it is **gitignored** — drop your copy at
`dev/roms/s_smp/spc700.rom` (sha1 `97e352553e94242ae823547cd853eecda55c20f0`), or point
`SNES_ROMPATH` elsewhere. In CI it is materialized from the `SNES_SPC700_ROM_B64` secret.
`dev/run.sh smoke` prints exactly what to do if it is missing.

## Upstream contribution

`platforms/snes/` is PR material for
[llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415). The PR is
cut by copying it into a fork of llvm-mos-sdk as `mos-platform/snes/` — this repo
stays the development home, decoupled from the full SDK tree.

## License

The SNES platform sources under `platforms/snes/` follow llvm-mos-sdk's license
(Apache-2.0 with LLVM exceptions) for clean upstreaming.
