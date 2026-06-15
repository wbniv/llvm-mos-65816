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
- **SNES SDK target**: none merged in the SDK; a **draft PR is open** —
  [llvm-mos-sdk#415 "[SNES] Add target"](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) by
  @Phillip-May (opened 2025-10-29, stalled since; reviewed once by @asiekierka). It is
  **8-bit / emulation-mode only** (no `-mcpu=mosw65816`, no native mode) — SDK scaffolding, not
  codegen. SDK ships 46 platforms (8 NES variants, C64, …) but no merged SNES. _This fork's
  `mos-platform/snes` (+ `snes-far`) target is built and green (M0, PASS); reconciliation with #415
  in [415-snes-target-reconciliation](415-snes-target-reconciliation.md)._
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

- ~~Create the SNES SDK target in llvm-mos-sdk ([#415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415)):
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

   _**PARTIAL** (2026-06-14). **Data-access half: PASS** — far loads/stores lower to absolute-long
   (`af`/`8f`, see step 3's `lda $018000` = `af 00 80 01`) and near data stays 16-bit absolute, so
   accesses match the pointer's addrspace. **Far-call half (JSR vs JSL): DEFERRED** — far *function*
   calls have no codegen yet; emitting `JSL`/`RTL` requires the compiler to know a callee's bank,
   which is the calling-convention decision (open, ABI-gating — see "Calling-convention decision"
   above) and is upstream-coordinated. It lands with the full #320 model + ABI, not the #320
   far-data slice. Tracked as TODO "#320 full model + upstream"._

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

   _**Increment 1b DONE (2026-06-14): a real 16-bit ALU through the dual-width A16 accumulator —
   this step's "smaller/faster" bar met.** Modeled the 65816 16-bit accumulator `A16 = B:A` (class
   `Ac16`), then a pre-legalizer combiner fuses `g = a OP b` (and `g = a OP #imm`) to a REP/SEP-
   bracketed 16-bit sequence via `G_{ADD,SUB,AND,OR,XOR}16_ABS` + `selectAlu16Abs`. The whole basic
   ALU works on **both** MAME and bsnes-jg: `+` (0x2345), `-` (0x0123), `& | ^` (0x0F00), and
   immediate operands (`a + 0x0345` → 0x1545); `dev/run.sh a16add|a16sub|a16bit|a16imm`. Add is
   **31 B vs 48 B** for the 8-bit carry chain; consecutive ops share one bracket (the REP/SEP pass now
   treats the carry-init as M-width-agnostic). Non-breaking (corpus 7/7, Inc 1a + far green, SDK
   builds). The genuine hard core of #321 — real values flow through a 16-bit register.
   Findings: a legalizer rule for a MOS-specific generic opcode corrupts the legalizer tables (skip by
   opcode-range instead); the carry-init must not split the REP/SEP run.
   [Inc 1b plan](plans/2026-06-14-321-increment-1b-dual-width-accumulator.md)._

   _**Increment 1c (2026-06-14): a value stays live in A16 across ops — the general path begins.**
   `g = a + b + c` fuses to one bracket `rep #$20; lda b; clc; adc a; clc; adc c; sta g; sep #$20`,
   threading the running sum through A16 (the intermediate `a+b` survives in the accumulator for the
   `+c`) → `corpus_result == 0x1230` on **both** MAME and bsnes-jg (`dev/run.sh a16chain`). First
   codegen where a 16-bit value survives across operations in the register, not just within one fused
   op. Still a combiner peephole (all-load ADD chains); the full general path is GISel-native s16
   register allocation (A16 ⊕ Imag16 + spilling) + loops + cross-block mode-tracking.
   [Inc 1c plan](plans/2026-06-14-321-increment-1c-chained-16bit-alu.md)._

   _**Increment 1d (2026-06-14): GISel-native s16 — attempted, reverted, blocker isolated.** A prototype
   kept s16 `G_ADD`/sub/bitwise un-narrowed (gated on `hasAccum16`) and selected to one 16-bit op on a
   resident `Imag16` pair; it compiled **correct** code for simple cases (a multi-use local add read
   `0x1122` on both emulators) but **crashes the register coalescer on complex multi-op functions**: an
   8-bit constant `LDImm` gets coalesced into `A16` (which aliases the 8-bit `A` as its sublo),
   producing a malformed `$a16 = LDImm`. That `A16`-aliases-`A` allocator entanglement is the genuine
   hard core of #321; the prototype was reverted to keep the tree green (1a-1c peephole stands). The
   fix needs allocator/coalescer-level work to keep `A16` and 8-bit `A` from entangling.
   [Inc 1d plan](plans/2026-06-14-321-increment-1d-gisel-native-s16.md)._

   _**Increment 1d-retry (2026-06-14): GISel-native s16 — the coalescer crash SOLVED; native add ships.**
   Re-diagnosed from the code: the crash wasn't the `A16=A` aliasing (the peephole creates `Ac16` vregs
   and is fine; the aliasing is needed for transient-`A16` soundness) — it was the prototype keeping the
   s16 value resident *in* `Ac16` and shuffling it to/from `Imag16` with `copyPhysReg` (COPY-like), so an
   8-bit `LDImm` coalesced into that COPY. The fix mirrors the proven peephole: the s16 **value lives in
   `Imag16`** and the native add selects to a self-contained `lda zp; clc; adc zp; sta zp` on the
   transient `A16` (new `LDAImag16`/`ADCImag16`/`STAImag16` ops) — the accumulator is entered/left **only
   via load/store, never a COPY to/from 8-bit**, so nothing for the coalescer to corrupt. A multi-use
   **local** add (`a16local.c`, peephole-impossible) runs `0x1122`, and the exact complex multi-op shape
   that crashed the prototype (`a16localx.c`: 5 native adds + reused locals) now **compiles clean
   (`-verify-machineinstrs`)** and runs `0x33A0` — both on **both** MAME and bsnes-jg. **Step 5**
   generalized the selector to native s16 **sub** (`sec/sbc` → `a16localsub` 0x1222) and **bitwise**
   (`and/ora/eor` → `a16localbit` 0x000F), widening the legalizer gate to s16 `G_SUB` + `G_AND/OR/XOR`
   under `+mos-a16`. So the full basic 16-bit ALU now flows through `Imag16` for locals/multi-use, not
   just the all-global peephole. A follow-up **immediate fold** makes `selectAlu16Native` use the
   `*Imm16` forms (`adc #$0345`) instead of materializing a constant operand into `Imag16` (the constant
   arrives as a `G_MERGE` of two byte-constants → reconstructed; dead def auto-erased) — `a16localimm`
   reads 0x1545 with no materialization. A further **load-fold** (combiner rule `alu16_absld` + the
   register-result `G_{...}16_ABSLD` pseudos + `selectAlu16AbsLd`) reads near-abs **global** operands
   directly via the 16-bit absolute forms for the multi-use case the store-fused peephole can't reach:
   `t = a16v + b16v` (reused) → `clc; rep; lda b16v; adc a16v; sta __rc; sep`, dropping the ~8-instr
   byte-wise Imag16 materialization (`a16loadfold` reads 0x2345). The `>1 use` guard keeps the
   single-store peephole (`alu16_abs`) firing. **Native 16-bit comparisons** (slice 1: unsigned
   ordering `< <= > >=`) follow: the legalizer keeps s16 UGE un-narrowed (a 16-bit `G_SBC`) and
   `selectSbc16` emits one `rep; lda; cmp; sep; bcc` (new `CMPImag16`/`CMPAbs16`/`CMPImm16`) instead of
   the old multi-block 8-bit `cpx/cpy` chain — `a16cmp` reads 0x1103 (incl. a high-byte-differs case
   proving the full 16 bits compare). **Native 16-bit equality** (`== !=`) follows: unlike the carry
   (ordering) path, the Z flag can't be a plain i1 (it must fuse into a terminator), so the legalizer
   keeps an s16 `ICMP_EQ` un-narrowed only when its result feeds a branch, and a fused 16-bit
   compare-branch (`CmpBrImag16`/`CmpBrImm16`) expands to `lda; cmp` (`MLow=1`, so REP/SEP brackets it)
   + `beq/bne` reading Z — `a16eq` reads 0x0011, no 8-bit `cpx/cpy` chain. **Native 16-bit signed
   ordering** (`< <= > >=` on `short`) then reuses both: signed order equals unsigned order after
   flipping the sign bit (`a <ₛ b ⟺ (a^0x8000) <ᵤ (b^0x8000)`), so `legalizeICmp` rewrites s16 `SLT`
   to `ULT` on the XOR'd operands — the XORs are the native EOR and the compare re-legalizes through the
   native UGE carry path, with no new flag handling (`a16scmp` reads 0x0111 incl. negative operands).
   Compare→select/stored-bool compares are follow-ups. Non-breaking (corpus 7/7, all 13 a16* tests
   green). **Cross-block REP/SEP mode-tracking** then makes the per-op
   16-bit features pay off across control flow: `MOSInsertREPSEP` was per-block and 8-bit-anchored, so
   a loop with a 16-bit body re-ran `rep … sep` every iteration; it now runs a forward dataflow over
   the M-width lattice (`{None, M8, M16, Conflict}`) and places switches only at genuine transitions —
   inside a block (seeded with the block's entry width, no forced 8-bit at exit) and on CFG edges
   `P→B` where `Out[P]≠In[B]`. Function entry, calls, and returns stay 8-bit (the ABI boundary); v1
   conservatively falls back to the old per-block anchoring for any switch on a true critical edge. The
   must-win case lands: a 16-bit loop body holds 16-bit mode across iterations — `rep` hoists to the
   preheader, `sep` sinks to the exit, none in the body (`a16loop` reads 0x2340), and a call inside a
   16-bit region executes 8-bit (`a16call` reads 0x4456). The X-flag (xy16) and a 16-bit calling
   convention remain follow-ups. Non-breaking (corpus 7/7, all 13 a16* tests green, patch `0002`
   round-trips). **Native 16-bit constant shifts** then close the next per-op gap: `x << k` /
   unsigned `x >> k` (k constant) had been narrowing to the 8-bit `asl/rol` (or `lsr/ror`) byte-pair
   chain even under `+mos-a16`. The legalizer now leaves a small s16 `G_SHL`/`G_LSHR` (amount 1–7)
   un-narrowed and `selectShift16Native` emits one `lda; (asl|lsr)×k; sta` run on the `Imag16` value
   (new `ASLAcc16`/`LSRAcc16` `MLow=1` forms) — `a16shift` reads 0x1278 with 4× `asl` + 2× `lsr` under
   a single rep/sep (the mode tracker even folds a following add into the same bracket), no `rol/ror`
   pairs and no `__ashlhi3` libcall. **Signed** `>>` (ASHR) follows: the 65816 has no native ASR, so
   `selectShift16Native` emits `cmp #$8000; ror a` per bit (the compare sets carry from the sign bit,
   `ror` replicates it into bit 15) via a carry-threaded `RORAcc16` — `a16ashift` sign-extends
   0xF000 >> 3 to 0xFE00 (reads 0xFE01), no 8-bit byte chain, no libcall. Variable shifts, amount ≥ 8,
   and the 1-byte `inc a`/`dec a` form are follow-ups. Non-breaking (corpus 7/7, all 17 a16* tests
   green, patch `0002` round-trips). **Native 16-bit indirect load/store** then closes the
   indexed/array-access gap (no X-flag dimension needed — llvm-mos lowers arrays via computed pointers
   whose arithmetic is already native 16-bit): a 16-bit value through a runtime pointer had loaded/
   stored as two 8-bit indirect ops (`lda (zp); lda (zp),y`); now an s16 `G_LOAD`/`G_STORE` through a
   non-absolute 16-bit pointer routes (in `legalizeLoadStore16`) to `G_LOAD16_INDIR`/`G_STORE16_INDIR`,
   selected to `lda (zp)`/`sta (zp)` (new `LDAIndir16`/`STAIndir16` `MLow=1` forms) in one rep/sep —
   `a16ptr` round-trips 0xABCE via `*p`, no `(zp),y` byte pair. The **absolute** case follows
   (`legalizeLoadStore16` routes a global-addressed s16 access to `G_LOAD16_ABS`/`G_STORE16_ABS` →
   `lda abs`/`sta abs` via the existing `LDAbs16`/`STAbs16`): `g = gg` is one 16-bit copy instead of a
   4-op X/Y byte shuffle (`a16abs` reads 0x5A3D), and register-valued `corpus_result = …` stores across
   the suite go native and merge into their preceding bracket. Constant-valued stores stay on the
   STZ-fusion/byte path. A `copy16abs` combiner then fuses the pure global-to-global copy — `g = gg`
   was `lda gg; sta tmp; lda tmp; sta g` (an Imag16 temp round-trip from independent load/store
   selection); `G_STORE(single-use G_LOAD(absSrc), absDst)` now folds to `G_COPY16_ABS` →
   `lda gg; sta g` (2 ops, no temp), and a selection-time fold (`loadStoreValueIntoA16`, gated by
   `shouldFoldMemAccess`) extends this to the **indirect** copy — `g = *p` is `lda (p); sta g` instead
   of the Imag16 round-trip (`a16copy` reads 0x3456). The indexed `abs,x` form is moot (llvm-mos is
   fully pointer-based) and the X-flag dimension remains an optional follow-up. A **compare-operand
   fold** then closes the comparison's analogue of the load-fold: a global-vs-global s16 compare
   (`a < gv`, `a >= gv`) had materialized BOTH operands into Imag16 pairs (`lda abs; sta tmp` ×2, then
   `lda tmp; cmp tmp`); `selectSbc16` now recognizes a single-use near-abs `G_LOAD16_ABS` operand and
   reads it directly — the LHS via `lda abs` (existing `LDAbs16`), the RHS via `cmp abs` (existing
   `CMPAbs16`) — so each compare is just `rep; lda abs; cmp abs; sep; bcc/bcs` with no Imag16
   round-trip (`a16abscmp` reads 0x4303, no `cmp zp`). Volatile-safe (the fold is 1-to-1: exactly one
   read of each global, same program order — the same property `selectAlu16AbsLd` relies on); signed
   compares feed XOR'd operands so they stay on the Imag16 path, and the equality `CmpBr*16` branch
   path (a possible `CmpBrAbs16`) is a separate follow-up. The **mixed-operand load-fold** then closes
   the ALU analogue of the same gap: an op with one near-abs global and one Imag16 register (a local /
   multi-use value) — the case neither both-global combiner (`alu16_abs`/`alu16_absld`) can reach —
   had materialized the global into an Imag16 pair first. `selectAlu16Native` now folds it directly at
   two sites: operand A into the LHS `lda abs` (`LDAbs16`), operand B into the absolute ALU form
   (`adc|sbc|and|ora|eor abs`) — uniform across all five ops and correct for both SUB directions with
   no commutativity swap (the minuend is always the loaded A). `a16mixfold` reads 0x2DC0 with every one
   of its six mixed ops reading the global in place (no `lda abs; sta tmp` round-trip). Because that
   fold is keyed on the operands (not the result's use-count or consumer), it also closes load-fold
   follow-up **(b)** — a both-global ALU op with a **single-use non-store** result (the case
   `alu16_absld` skips via its `>1 use` guard and `alu16_abs` skips as a non-store) now folds both
   operands in `selectAlu16Native` (`lda abs a; OP abs b`), identical to the `alu16_absld` output;
   `a16sunfold` reads 0x3480 with zero globals materialized into Imag16 pairs (a regression guard — no
   new codegen). Non-breaking (corpus 7/7, all 25 a16* tests green, patch `0002` round-trips).
   [Inc 1d-retry plan](plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md) ·
   [imm-fold plan](plans/2026-06-14-321-native-s16-immediate-operand-optimization-adc.md) ·
   [load-fold plan](plans/2026-06-14-321-native-s16-fold-global-operand-loads-into-the.md) ·
   [compares plan](plans/2026-06-14-321-native-16bit-compares.md) ·
   [cross-block REP/SEP plan](plans/2026-06-15-321-cross-block-repsep-mode-tracking.md) ·
   [constant-shifts plan](plans/2026-06-15-321-native-16bit-constant-shifts.md) ·
   [signed-shift plan](plans/2026-06-15-321-native-16bit-signed-shift-ashr.md) ·
   [equality-compares plan](plans/2026-06-15-321-native-16bit-equality-compares.md) ·
   [signed-compares plan](plans/2026-06-15-321-native-16bit-signed-compares.md) ·
   [indirect-load-store plan](plans/2026-06-15-321-native-16bit-indirect-load-store.md) ·
   [absolute-load-store plan](plans/2026-06-15-321-native-16bit-absolute-load-store.md) ·
   [compare-operand-fold plan](plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md) ·
   [mixed-operand-fold plan](plans/2026-06-15-321-native-s16-mixed-operand-load-fold.md) ·
   [single-use-non-store-fold plan](plans/2026-06-15-321-native-s16-single-use-non-store-fold.md)._

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
  [sdk#415 SNES target](https://github.com/llvm-mos/llvm-mos-sdk/pull/415)
