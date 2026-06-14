# llvm-mos 65816 C backend — contribution roadmap

## Context

This is a **roadmap for upstream contribution to [llvm-mos](https://github.com/llvm-mos/llvm-mos)**,
not a change to drdevtools. The work lands in `llvm-mos/llvm-mos` (compiler) and
`llvm-mos/llvm-mos-sdk` (platform target). drdevtools' stake: an optimizing open-source 65816 C
compiler that emits DWARF (spec landed Dec 2025) closes the loop *compile → optimized SNES ROM →
DWARF symbols → source-level debug in drmon* on fully-open tooling. See the
[investigation](INVESTIGATION.md) for the full status,
players, and rival/dead efforts; this plan is the **execution order** distilled from it.

**Upstream baseline at project start (verified 2026-06-13)** — what `llvm-mos`/`llvm-mos-sdk`
shipped before this work; our progress against it is tracked in the milestone + verification
sections below:

- 65816 **assembler + linker**: shipped. `FeatureW65816` subtarget exists in `MOSDevices.td`.
- 65816 **C code generation**: did not exist upstream. Two open, design-only issues:
  [#320](https://github.com/llvm-mos/llvm-mos/issues/320) (24-bit address space) and
  [#321](https://github.com/llvm-mos/llvm-mos/issues/321) (16-bit register mode). _This fork now
  has both, in slice form: #320 far-pointer load/store (M1, PASS) and #321 16-bit-accumulator
  Inc 1a + native-mode crt0 (M2, in progress) — none upstreamed yet._
- **SNES SDK target**: did not exist upstream — open issue
  [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415). SDK ships 46 platforms
  (8 NES variants, C64, …) but no SNES. _This fork's `mos-platform/snes` (+ `snes-far`) target is
  built and green (M0, PASS)._
- **No active implementer** since @asiekierka stepped away (his design notes in #320/#321 stand).

## Goal

A working, then optimizing, open-source 65816 C compiler with an SNES target, built **code-first**
(the maintainers bless ABI decisions only behind a running implementation).

## Approach — one track, three milestones (NOT two phases)

The naive framing is "land a cheap intermediate, *then* implement codegen." That's a false
dichotomy: the bulk of the cheap intermediate is the **SNES SDK target + an emulator/CI test loop**,
which is mandatory infrastructure for testing *any* codegen — you can't validate one far-pointer
lowering rule until a target exists to emit into and run. The only throwaway part is the generated
8-bit machine code, and that is **free** (the existing 6502 backend writes it). So it's one track:
build the bench, ship a validated unoptimized compiler, then layer optimization on top with a
regression baseline already in hand.

### M0 — toy + test bench (no new codegen)

Stand up the infrastructure every later milestone needs, using the *existing* 6502 backend.

- ~~Create the SNES SDK target in llvm-mos-sdk ([#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415)):
  crt0, LoROM linker scripts, interrupt/reset vectors, memory map, ROM header.~~ **Done** —
  `mos-platform/snes` authored (LoROM 32 KiB, `PARENT common`, `COMPLETE`): `crt0.c`, `header.s`,
  `link.ld`, `snes.h`, `clang.cfg`. On the `snes-target` branch of the SDK clone.
- ~~crt0 sets the stack + force-blanks the PPU.~~ **Done** — emulation-mode bring-up
  (`sei`/`cld`, `TXS`→`$01FF`, `NMITIMEN=0`, `INIDISP=$8F`); the `SP=$01FF` nuance is automatic in
  emulation mode (page-1 stack), so it's just `LDX #$FF`/`TXS`.
- ~~Emit a `.sfc` ROM from C.~~ **Done** — `mos-snes-clang` builds `hello.c` → a valid 32 KiB
  headerless `.sfc`. **Structural verification PASS**: reset `$FFFC`→`_start` (`$8000`); boot path
  disassembles byte-exact to the crt0; `main()` compiled + placed (`$8036`); header well-formed;
  checksum `0x3986 + 0xC679 = 0xFFFF`. (See verification step 1 evidence below.)
- ~~Emulator smoke loop: a bank-0 C "hello world" **boots and runs in MAME's `snes` driver**,
  headless, with a programmatic assert (`sentinel == 0x42` in WRAM).~~ **Done** (2026-06-14) —
  `dev/run.sh smoke` (MAME 0.285, `snes` driver) green; negative control + clean-room `repro` +
  manual CI all pass. MAME chosen so the CI bench matches drdevtools `drmon`'s emulation backend
  (green-in-CI == attachable-in-drmon); the bsnes-jg cross-check landed at M1.
  [plan](plans/2026-06-14-emulator-smoke-loop.md).
- ~~Regression corpus: a handful of small C programs with known-correct output.~~ **Done**
  (2026-06-14) — 6 self-contained C programs (`examples/snes/corpus/`), host-checked vs
  `expected.tsv`; `dev/run.sh corpus` → 7/7.
  [plan](plans/2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).

Build is fully containerized (host stays clean) — Dockerfile + `build.sh`/`compile.sh`/`validate.sh`
in the `~/SRC/llvm-mos-snes` workspace.

Deliverable: a merged (or PR-ready) `mos-platform/snes` target + CI smoke. Risk: low — no compiler
changes, only SDK + build glue. This is the credibility artifact that pulls @asiekierka/@mysterymath
into guiding the #320 design.

### M1 — the cheap intermediate, useful form (first real codegen)

Add **[#320](https://github.com/llvm-mos/llvm-mos/issues/320)** — 24-bit address space / far
pointers — keeping registers 8-bit. Follow asiekierka's proposed five-address-space LLVM data layout
(addrspace `0`=32-bit far, `1`=8-bit direct page, `2`=16-bit absolute, `3`=24-bit packed far,
`4`=16-bit zero-bank). Default pointer 32-bit (cheaper than 24-bit on the 65816 — extra mode switch),
24-bit "packed" as a size option. Track near/far calls (JSR vs JSL).

Deliverable: a **working, multi-bank, unoptimized** 65816 C compiler. The corpus from M0 now exercises
real far-pointer codegen and becomes the regression baseline for M2.

### M2 — the optimizing payoff

Add **[#321](https://github.com/llvm-mos/llvm-mos/issues/321) stage 1** — 16-bit accumulator:
model X/Y/C as 16-bit and A as 8-bit; insert `REP`/`SEP` at a late codegen stage from the register
widths each instruction needs. X/Y stay 16-bit (xy16). Build on the
[jackoalan REP/SEP POC](https://github.com/jackoalan/llvm-mos/commit/ec070a70ba8d8b3d3a9da24b4216435f9575f6bb).
Then: hardware-stack ABI (16-bit SP + stack-relative addressing) and the calling convention.

**Later / out of initial scope:** #321 stage 2 (xy8/xy16 switching — asiekierka: "may well be a
pipe dream with our current resources").

## Calling-convention decision (open, blocks the ABI)

Undecided in #320/#321 and gating. Three candidates:

- **PHD/TCD direct-page frame** — what Zardoz / WDC816CC / ORCA-C all did
  (Zardoz ABI (drdevtools research)):
  fast (8-bit DP offsets) but hard 256-byte frame cap.
- **Hardware-stack-relative frame** — now viable on the 65816 (16-bit SP, S-indexed modes).
- **llvm-mos soft static stack** — carried over from the 6502.

The prior-art reference for this decision is the **documented** WDC816CC/ORCA-C ABI (from the WDC
compiler manual + ORCA/C source, captured in the
Zardoz investigation (drdevtools research))
— a manual, not anyone's memory. Zardoz shipped real commercial SNES titles (Will Norris among its
users), which establishes the ABI *worked in production*; but the codegen internals were the
compiler author's domain, not the game developers', so don't expect first-hand recall of the frame
layout. **A low-effort, no-code contribution: surface that documented prior art in #320/#321.**

## Verification

Acceptance test per milestone — each step is the bar that milestone must clear. Paste raw evidence
(build log, emulator screenshot/value dump) under each step as it's met, mark PASS/FAIL.

1. **M0 — target boots.** `mos-snes-clang hello.c -o hello.sfc` produces a valid ROM; the ROM boots
   in **MAME's `snes` driver** (drmon's emulation core) and produces the known-correct output
   (`sentinel == 0x42` in WRAM). CI runs the smoke headless. A bsnes-jg/Mesen2 cross-check is added
   at M1. (Evidence: build log + emulator value dump.)

   **Build + structural half: PASS** (2026-06-13). **Emulator-run half: PASS** (2026-06-14) —
   headless via `dev/run.sh smoke` (MAME 0.285, `snes` driver). Local smoke green; CI run pending
   the `SNES_SPC700_ROM_B64` secret + push. See the
   [smoke loop plan](plans/2026-06-14-emulator-smoke-loop.md) for the full implementation +
   verification (incl. negative control and `mame -verifyroms snes` → "romset snes is good"). Raw evidence:

   ```
   # --- structural (2026-06-13) ---
   $ mos-snes-clang -Os -o hello.sfc examples/hello.c   # in-container, snes-target SDK
   $ stat -c%s hello.sfc
   32768
   $ # internal header @ $FFC0
   00007fc0: 4c4c 564d 2d4d 4f53 2053 4e45 5320 2020  LLVM-MOS SNES
   map mode : 0x20 (LoROM/slow)   country: 0x01   rom size: 0x05
   checksum : 0x3986  complement: 0xC679  (sum=0xffff)
   $ # vectors: emu RESET $FFFC -> $8000  (= _start);  NMI $FFFA->$8022  IRQ $FFFE->$8021
   $ # reset bytes: 78 d8 a2 ff 9a a9 00 8d 00 42 a9 8f 8d 00 21
   $ #   = SEI / CLD / LDX #$FF / TXS / LDA #$00 / STA $4200 / LDA #$8F / STA $2100  (== crt0)
   $ # linker map: _start=$8000  __do_init_stack=$800F  main=$8036 (real C)  sentinel=$20

   # --- emulator run (2026-06-14), dev/run.sh smoke ---
   ==> smoke: ROM=hello.sfc  sentinel@$20 -> WRAM 0x7E0020  (expect 0x42)
   SMOKE: PASS addr=0x7E0020 got=0x42 (ran 60 ticks)      # exit 0
   # negative control (SMOKE_WANT=0x99): SMOKE: FAIL got=0x42 want=0x99  # exit 1
   ```

   So: a valid bootable 32 KiB LoROM `.sfc` is produced from C by the existing 6502 backend, the
   reset path is exactly the crt0, `main()` is compiled and placed — **and it boots and runs**: the
   C-written `sentinel` reads back `0x42` from WRAM in MAME. The only piece left to fully close
   step 1 is the same run going green in CI (needs the BIOS secret).

2. **M0 — bench reproducible.** The regression corpus (≥5 programs) builds and runs green from a
   clean checkout. (Evidence: corpus run + clean-room `repro`.)

   **PASS** (2026-06-14) — 6 self-contained C programs (`examples/snes/corpus/`), each computing a
   result the host checks against `expected.tsv`; exercises ALU, control flow, arrays/`.rodata`,
   structs/pointers, calls/recursion, and the crt0 `.data`/`.bss` init. `dev/run.sh corpus` → **7/7
   passed** (incl. the `hello` liveness row); negative control (corrupt one expected) → that row
   FAILs, exit 1; clean-room `dev/run.sh repro` green from committed `HEAD`; manual CI run
   [27475871789](https://github.com/wbniv/llvm-mos-65816/actions/runs/27475871789) green (corpus step
   executed on a clean runner). Harness + design:
   [corpus plan](plans/2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).
   ```
   hello   PASS sentinel=0x42   arith PASS 0xA9E9   control PASS 0x1DFB   arrays PASS 0x03E1
   structs PASS 0x0340          funcs PASS 0x011E   globals PASS 0xAB55   => corpus: 7/7 passed
   ```

3. **M1 — far pointers work.** A C program that reads/writes data across ≥2 banks (far pointer
   dereference, a `>64 KB` data table) compiles and produces correct output in both emulators.
   8-bit-register codegen still passes the full M0 corpus (no regression). (Evidence: program output
   + corpus green.)

   **PASS** (2026-06-14, both emulators) — delivered in two increments (absolute-long carries the full
   24-bit address and ignores the DBR, so far accesses run in plain **emulation mode** — no native-mode
   crt0 needed; that's an M2/#321 concern): **Increment 2** — a single-bank far load+store round-trip
   executes in MAME (`SMOKE: PASS got=0xF3`); **Increment 2b** — a 64 KiB LoROM (`snes-far` platform)
   places a far global in bank $01 and `lda $018000` (`af 00 80 01`) reads it across the bank boundary,
   round-tripping correctly in MAME. `dev/run.sh far-run` + `far-bank1`; 6502 corpus still 7/7.
   **Both emulators** — a second, independent emulator (**bsnes-jg**, cycle-accurate) cross-checks the
   same far ROMs headless via `dev/run.sh xcheck` and reads back the same WRAM bytes, so the bank-$01
   far read isn't a MAME-specific quirk. (Mesen2 was abandoned: its prebuilt crashes on the 26.04
   glibc-2.43 base; see the xcheck plan.)
   ```
   bank $00  far-run:    MAME PASS got=0xF3   bsnes-jg PASS got=0xF3   -> AGREE
   bank $01  far-bank1:  MAME PASS got=0xF3   bsnes-jg PASS got=0xF3   -> AGREE   (lda $018000)
   far_src @ $018000   linked far load: af 00 80 01   corpus 7/7
   ```
   [Inc 2 plan](plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md) ·
   [Inc 2b plan](plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md) ·
   [xcheck plan](plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).

4. **M1 — address-space model honored.** Spot-check disassembly: near calls emit `JSR`, far calls
   emit `JSL`; direct-page vs absolute vs long accesses match the addrspace of the pointer.
   (Evidence: `llvm-objdump` excerpt.)

5. **M2 — 16-bit A + REP/SEP.** A 16-bit arithmetic kernel (e.g. fixed-point multiply-add loop)
   compiles with correct `REP`/`SEP` placement, produces correct results, and is **smaller/faster**
   than the M1 8-bit-mode output for the same source. The M0+M1 corpus stays green. (Evidence:
   size/cycle comparison + corpus green.)

   _**Increment 1a in progress (2026-06-14): first 16-bit-accumulator codegen, dual-emulator-verified.**
   The new `MOSInsertREPSEP` pass (opt-in `+mos-a16`, reusing the MC `MLow/MHigh` width TSFlags) fuses a
   16-bit store-of-zero to `rep #$20; stz; sep #$20`; run in 65816 native mode it fully zeroes the
   16-bit value → `corpus_result == 0x0042` on **both** MAME and bsnes-jg (`dev/run.sh a16`).
   Non-breaking (corpus 7/7). Findings: (a) 16-bit registers need native mode (XCE) — **now landed**:
   the snes crt0 enters 65816 native mode (`clc; xce` + 16-bit `ldx #$01ff; txs` + `sep #$30`) for
   *every* program, so a16 dropped its 1a test-local `clc; xce` and still reads `0x0042` on both
   emulators; corpus/far/xcheck stay green in native 8-bit
   ([native-crt0 plan](plans/2026-06-14-321-native-mode-crt0.md)); (b) the size win needs amortization
   (one STZ under REP/SEP is +1 byte) — churn-minimization + the dual-width accumulator register
   (16-bit `lda`/`sta`, not just STZ) are the next increments._
   [Inc 1 plan](plans/2026-06-14-321-increment-1-16bit-accumulator.md).

6. **DWARF round-trip (drmon tie-in).** A `-g` build emits llvm-mos DWARF that a source-level
   debugger loads with correct line/variable mapping. (Evidence: drmon or `llvm-dwarfdump` against
   the ROM's symbols.)

## Dependencies & sequencing

- M0 → M1 → M2 strictly (each is the test bench for the next).
- #320 is shared by the "cheap intermediate" and "implement codegen" framings — unavoidable, first
  real codegen, do it at M1.
- Engage on the llvm-mos **Discord** before large PRs (design discussion lives there; the Feb 2024
  codegen breakdown originated there). Coordinate with @asiekierka (design owner) and @mysterymath
  (maintainer / ABI gate).

## Links

- [Investigation: status, players, rivals](INVESTIGATION.md)
- Zardoz / WDC816CC ABI (calling-convention prior art) (drdevtools research)
- Upstream: [#32 umbrella](https://github.com/llvm-mos/llvm-mos/issues/32) ·
  [#320 24-bit addr](https://github.com/llvm-mos/llvm-mos/issues/320) ·
  [#321 16-bit regs](https://github.com/llvm-mos/llvm-mos/issues/321) ·
  [sdk#415 SNES target](https://github.com/llvm-mos/llvm-mos-sdk/issues/415)
