# Apply llvm-mos-sdk#415 (SNES target), fix it, then add the 16-bit native variant

**Branch:** `snes-415-reconcile` (off `main`)
**Date:** 2026-06-15

> On execution, copy this plan to `docs/plans/2026-06-15-415-snes-target-apply-and-16bit.md`
> and add a `TODO.md` entry (SRC convention: the plan is the contract, code follows it).

## Context

[llvm-mos-sdk#415 "[SNES] Add target"](https://github.com/llvm-mos/llvm-mos-sdk/pull/415)
(@Phillip-May, draft, one commit `e6a5c17`, stalled) is the existing community SNES SDK:
an **8-bit / 6502-emulation-mode** target riding the stock backend. It contributes real,
reusable assets — a ~301-entry SNES MMIO register map and DMA VRAM/CGRAM/OAM helper
routines (`snesxc/`) — but @asiekierka's single review flagged it as not-yet-mergeable:

1. no `-mcpu=mosw65816`;
2. interrupt handlers hand-roll `pha`/`php` register saves instead of
   `__attribute__((interrupt))` (PC Engine is the model);
3. `startup.s` is a manual `jsr __do_init_stack; …; jsr main` chain instead of the
   linker-ordered `.init.*` crt0;
4. **WDC license incompatibility** — `vectors.s` is *"Based on vectors.asm reference from
   wdc816cc"* (the register header / DMA helpers cite Peter Lemons, not WDC);
5. rough edges (multi-compiler `#ifdef` cruft for VBCC/CC65/TCC816/Calypsi/JCC, own
   `int_snes_xc.h` typedefs duplicating `<stdint.h>`).

Our `docs/415-snes-target-reconciliation.md` already set the posture: **build on #415, don't
throw it away** — reuse what Phillip built, contribute the missing native-mode/16-bit layer
on top. This task realizes that in two phases.

**Naming (decided):** bare **`snes`** = the **16-bit native** target (the headline/"regular"
version, and what every `dev/a16*.sh` + far-pointer script already builds against).
The faithful-but-fixed 8-bit #415 port becomes **`snes-8bit`** (suffix names the codegen
**width**: 8-bit A/X/Y codegen, no 16-bit-register codegen).

**CPU note (decided after the 65816-vs-65C02 question):** the 8-bit target still uses
**`-mcpu=mosw65816`** — *not* the stock 6502 backend. In 6502-emulation mode (`E=1`) the
65816 still decodes its full instruction set (it's a near-superset of the 65C02: it has
`STZ`/`BRA`/`PHX·PHY·PLX·PLY`/`TRB·TSB`/`INC A·DEC A`/`WAI`/`STP`, **lacks** the Rockwell
`RMB/SMB/BBR/BBS`, **adds** long jumps/`TXY·TYX`/block moves/`REP·SEP`). So `snes-8bit` =
8-bit codegen **on a 65816** (strictly better than 6502); it just never sets the `+mos-a16`
16-bit-register feature. This is exactly asiekierka's `-mcpu` point — #415's `clang.cfg`
(no `-mcpu`) left all the enhanced 8-bit instructions on the floor.

## How platforms are wired (grounding)

`dev/build.sh` vendors upstream `llvm-mos-sdk` into `vendor/` and copies each
`platforms/<p>/` into `vendor/llvm-mos-sdk/mos-platform/<p>/`, producing a `mos-<p>.cfg`.
Existing platforms: `snes` (native-mode `crt0.c` + `header.s` + 32 KiB `link.ld` + `snes.h`)
and `snes-far` (child of `snes`, overrides only `link.ld` for banks $00+$01). The `a16*` and
far scripts already invoke `--config mos-snes.cfg -mcpu=mosw65816`. **Phase 1 is purely
additive** (new `platforms/snes-8bit/`); it does not touch `snes`/`snes-far`, so the #320/#321
work and corpus stay green.

---

## Phase 1 — Apply #415 faithfully, then fix it → `platforms/snes-8bit/`

Goal: a clean, **upstreamable** 8-bit emulation-mode SNES target that is recognizably #415
but addresses every review point — the version that could actually help #415 land.

### 1.1 Land #415 as-is (faithful import), then fix in place

Create `platforms/snes-8bit/` from the PR's `mos-platform/snes/` (fetch via
`gh api repos/llvm-mos/llvm-mos-sdk/pulls/415 -H "Accept: application/vnd.github.v3.diff"`),
mapping into this repo's `platforms/` convention + a `CMakeLists.txt` modeled on the existing
`platforms/snes/CMakeLists.txt` (`platform(snes-8bit COMPLETE PARENT common)`).

### 1.2 Apply the reviewer fixes

| Review point | Fix |
|---|---|
| `-mcpu` missing | add `-mcpu=mosw65816` (PCE puts it in `target_compile_options` on the crt0 lib; mirror that) |
| manual `jsr` startup chain | **delete `startup.s`'s jsr chain.** Use the linker-ordered crt0: a tiny `.init.50` mode-setup fragment + `merge_libraries(snes-8bit-crt0 common-init-stack common-copy-data common-zero-bss common-exit-loop)`, exactly like `platforms/snes/CMakeLists.txt`. `_start`/`.call_main` come from `common/ldscripts/text-sections.ld`. |
| manual-save interrupt handlers | rewrite handlers as `__attribute__((interrupt))` C (NES/PCE model); weak `nmi`/`irq` defaults that `rti`. Drop `snesXC_*_wrapper`/`*_handler` plumbing. |
| **WDC-derived `vectors.s`** | **rewrite clean** from the public hardware vector map (native $FFE4–$FFEF + emulation $FFF4–$FFFF). Place vectors in `link.ld` via `SHORT(handler)` (NES/PCE idiom), not a hand-written `.s`. Nothing traces to wdc816cc. |
| `link.ld` | adopt #415's multi-bank LoROM layout (8×$7E00 banks + fixed bank-0), modernized: `INCLUDE c.ld`, region aliases, `SHORT()` vectors, `ENTRY(_start)`. Fix the `OUTPUT_FORMAT` block. |

### 1.3 Bring in the `snesxc/` library — original parts only, conformed to conventions

- **Keep** `snes_regs_xc.h` (the ~301-entry register map) → rename/relocate as the platform's
  register header. **Strip** every non-`__mos__` `#ifdef` (VBCC/CC65/TCC816/Calypsi/JCC/WDC),
  replace `int_snes_xc.h` typedefs with `<stdint.h>`, drop `farMalloc`/compiler stubs.
- **Keep** the DMA helper routines in `snesxc.c` that are Phillip's own (`initSNES`,
  `LoadCGRam`, `LoadVram`/`LoadLoVram`/`LoadHiVram`, `ClearVram`, `LoadOAMCopy`/`initOAMCopy`,
  `snesXC_memcpy_banked`, `snesXC_setDataBank`, `emitWAI`/`emitCLI`) — cleaned to llvm-mos only,
  handlers via `__attribute__((interrupt))`. **Drop** the WDC-derived interrupt plumbing.
- Keep `putchar_stub.c` (`__putchar`) so `sprintf` links.
- License headers: Apache-2.0-with-LLVM-exceptions (repo convention), crediting Phillip-May
  and Peter Lemons where due.

### 1.4 Example + smoke

Port `examples/snes/cgramtest.c` → `examples/snes-8bit/cgramtest.c` (fix the upstream
`cgramtest.c.c` typo), build it against `mos-snes-8bit.cfg`, boot headless in MAME.

**Phase 1 files:** `platforms/snes-8bit/{CMakeLists.txt,clang.cfg,link.ld,crt0.c (or .init
fragment),snes_regs.h,snesxc.c,snesxc.h,putchar_stub.c}`, `examples/snes-8bit/cgramtest.c`,
a `dev/` build/smoke hook (mirror `dev/compile.sh`/`dev/far*.sh`).

---

## Phase 2 — 16-bit native target → `platforms/snes/` (crt0 + register map only)

Scope (decided): **native crt0 + the cleaned register-map header only.** Defer porting the
DMA/VRAM helper routines to 16-bit to a later phase.

The bare `platforms/snes/` already has a native-mode `crt0.c` (XCE → E=0, 16-bit stack via
`REP #$10`/`txs`, native vectors) — it is effectively the Phase-2 starting point. Phase 2:

1. **Refine the native crt0** as the canonical 16-bit-native bring-up: confirm XCE + page-1
   stack + native-vector wiring in `link.ld`, M/X back to 8-bit before entering codegen
   (default), so `-mcpu=mosw65816 +mos-a16` codegen (the #321 work) sits cleanly on top.
   Reuse the existing `crt0.c` / `header.s` / `link.ld`; do not regress `snes-far` or the
   `a16*` scripts.
2. **Add the cleaned register map** (the Apache-2.0 `snes_regs.h` produced in 1.3) to
   `platforms/snes/`, installed alongside `snes.h` (or fold into `snes.h`) so native-mode C
   has the full MMIO surface. `vu16` register access (e.g. `REG_VMADD`, `REG_VMDATA`) is the
   natural consumer of the 16-bit accumulator codegen.
3. **No new helper port, no new showcase example** beyond a minimal corpus/smoke program that
   reads/writes a 16-bit register through native codegen and is asserted on the MAME/bsnes
   harness (extends the existing corpus rather than a bespoke demo).

**Phase 2 files:** `platforms/snes/{snes_regs.h (new), snes.h, crt0.c, link.ld}` (mostly
additive/refinement), one corpus program under `examples/snes/corpus/` + `expected.tsv` row.

---

## Verification

Run inside the dev container (host stays clean). Paste raw output under each step in the
docs/plans copy; mark PASS/FAIL.

**Phase 1**
1. `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build` — SDK + `snes-8bit`
   platform build clean; `mos-snes-8bit.cfg` is produced.
2. Compile `examples/snes-8bit/cgramtest.c` → `.sfc` with `--config mos-snes-8bit.cfg`
   (no `-mcpu` needed for the 8-bit target, but it must accept `-mcpu=mosw65816`); link
   succeeds, header/checksum well-formed (`dev/validate.sh`).
3. Boot the ROM headless in MAME (`dev/run.sh smoke` analog for snes-8bit) — asserts it runs.
4. `llvm-objdump` the crt0: **no** `jsr __do_init_stack` chain in `startup.s`; `_start`
   resolves into the `.init.*`-ordered chain; interrupt handlers are `__attribute__((interrupt))`.
5. `grep -ri wdc platforms/snes-8bit` → no WDC-derived code remains.

**Phase 2**
6. `dev/run.sh build` then `dev/run.sh corpus` — existing 7/7 corpus still green (no regression
   to `snes`/`snes-far`).
7. New 16-bit-register corpus program: built with `--config mos-snes.cfg -mcpu=mosw65816`,
   boots in MAME **and** cross-checked in bsnes-jg (`dev/xcheck.sh` idiom), `corpus_result`
   matches `expected.tsv`.
8. `dev/run.sh repro` — clean-room export + build + corpus from HEAD alone passes.

## Out of scope / follow-ups

- Porting the DMA/VRAM helpers to 16-bit codegen (deferred per Phase-2 scope decision).
- Upstreaming: cutting the actual `llvm-mos-sdk` PR from `platforms/snes-8bit/` (README already
  documents the copy-into-fork flow); engaging @asiekierka on the #321 thread with the
  native-mode layer (`docs/415-snes-target-reconciliation.md`).
