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

**M0 — SNES test bench (in progress).** The SNES platform builds a valid,
bootable 32 KiB LoROM `.sfc` from C using llvm-mos's existing 6502 backend — the
65816 boots in 6502-emulation mode, so no 65816 codegen is needed yet. Reset
vector → `_start`, the boot path is the crt0, `main()` is real compiled C, header
+ checksum well-formed. Remaining: live emulator boot test + a regression corpus.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full M0 → M1 → M2 plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for the upstream status, players,
and the contribution rationale.

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
dev/run.sh smoke      # boot build/hello.sfc headless in MAME, assert it ran
```

The first `build` clones upstream `llvm-mos-sdk` into `vendor/` and compiles the
SDK against the pinned llvm-mos toolchain baked into the image (~1–2 min).

`smoke` boots the ROM in MAME's `snes` driver (the same emulation core drdevtools'
`drmon` debugs against) and asserts the `sentinel == 0x42` byte in WRAM — closing the
"it actually runs" half of the M0 acceptance test, headless and in CI. See
[docs/plans/2026-06-14-emulator-smoke-loop.md](docs/plans/2026-06-14-emulator-smoke-loop.md).

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
