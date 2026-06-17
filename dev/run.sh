#!/usr/bin/env bash
# Host-side driver: (re)build the dev image and run a dev/<target>.sh inside it
# against this repo. Usage: dev/run.sh [build|compile|validate|smoke|corpus|toolchain|far|far-run|far-bank1|xcheck|a16|a16add|a16sub|a16bit|a16imm|a16chain|a16local|a16localx|a16localsub|a16localbit|a16localimm|a16loadfold|a16cmp|a16loop|a16call|a16shift|a16ashift|a16eq|a16scmp|a16abscmp|a16mixfold|a16sunfold|a16chainld|a16chainimm|a16bitchain|a16incdec|a16loopred|a16incabs|a16ptr|a16abs|a16copy|a16spill|a16spillr|a16spillir|a16eqval|a16eqvalp|a16eqvalg|a16eqvalc|a16eqvalmg|a16ret|repro] (default: build)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
IMAGE=llvm-mos-65816-dev
TARGET="${1:-build}"

if [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
  cat <<'USAGE'
Usage: dev/run.sh [TARGET] [ARGS...]   (default: build)

(Re)build the dev image and run dev/<TARGET>.sh inside it against this repo.

Targets:
  build      (re)build the dev image, vendor llvm-mos-sdk + platforms/snes,
             compile examples/snes/hello.c -> build/hello.sfc   (default)
  compile    compile the SNES example in the container (image must exist)
  validate   structural validation of build/hello.sfc (reset path, checksum)
  smoke      boot build/hello.sfc headless in MAME, assert sentinel==0x42
             (needs the SPC700 IPL at dev/roms/s_smp/spc700.rom)
  corpus     run the regression corpus headless in MAME: assert each program in
             examples/snes/corpus/ against examples/snes/corpus/expected.tsv
  toolchain  build llvm-mos (clang/lld) FROM SOURCE -> build/llvm-mos-install
             (for M1 codegen; long first build — see dev/toolchain.sh)
  far        #320 Increment 1: compile examples/65816/far-deref.c with the
             from-source toolchain and assert (at the disassembly level) that a
             far (addrspace 2) access lowers to 65816 absolute-long (LDA/STA
             $xxxxxx) while a near access stays 16-bit (needs `toolchain` first)
  far-run    #320 Increment 2: build examples/65816/far-run.c with -mcpu=mosw65816
             into a bootable .sfc, boot headless in MAME, and assert the byte
             produced by a far LOAD and written by a far STORE reads back == 0xF3
             (needs `toolchain` + `build` on the from-source toolchain first)
  far-bank1  #320 Increment 2b: build examples/65816/far-bank1.c against the
             snes-far 64 KiB platform (banks $00+$01), assert the far global lands
             in bank $01 ($018xxx), boot in MAME, and check the cross-bank far read
             round-trips == 0xF3 (needs `toolchain` + `build` first)
  xcheck     second-emulator fidelity cross-check: boot the far ROMs in bsnes-jg
             (cycle-accurate, independent of MAME) headless and assert the same
             WRAM results — confirms the bank-$01 far read isn't a MAME quirk
             (fetches+builds bsnes-jg once; needs `toolchain` + `build` first)
  a16        #321 Increment 1a: build examples/65816/a16.c with +mos-a16, assert a
             16-bit store-of-zero fuses to `rep #$20; stz; sep #$20` (disasm) and
             reads back correct (corpus_result==0x0042) on MAME + bsnes-jg
             (needs `toolchain` + `build`; `xcheck` first for the bsnes-jg leg)
  a16add     #321 Increment 1b: build examples/65816/a16add.c with +mos-a16, assert a
             16-bit add fuses to one `clc; rep #$20; lda; adc; sta; sep #$20` bracket
             (disasm) and reads back correct (corpus_result==0x2345) on MAME + bsnes-jg
             (needs `toolchain` + `build`; `xcheck` first for the bsnes-jg leg)
  a16sub     #321 Increment 1b: build examples/65816/a16sub.c with +mos-a16, assert a
             16-bit subtract fuses to one `sec; rep #$20; lda; sbc; sta; sep #$20`
             bracket and reads back correct (corpus_result==0x0123) on MAME + bsnes-jg
  a16bit     #321 Increment 1b: build examples/65816/a16bit.c with +mos-a16, assert the
             16-bit AND/OR/XOR select to and/ora/eor (disasm) and the AND result
             reads back correct (corpus_result==0x0F00) on MAME + bsnes-jg
  a16imm     #321 Increment 1b: build examples/65816/a16imm.c with +mos-a16, assert
             g = a OP #imm16 selects to adc/and #imm and reads back correct
             (corpus_result==0x1545) on MAME + bsnes-jg
  a16chain   #321 Increment 1c: build examples/65816/a16chain.c with +mos-a16, assert
             g = a + b + c fuses to one rep/sep bracket threading A16 (lda + 2 adc)
             and reads back correct (corpus_result==0x1230) on MAME + bsnes-jg
  a16local   #321 Increment 1d-retry: GISel-native s16 value in Imag16 — a multi-use
             LOCAL add (peephole can't fold) selects to one rep/sep bracket on the
             transient A16 with NO Ac16<->8-bit COPY; corpus_result==0x1122 both emus
  a16localx  #321 Increment 1d-retry step 4: the COMPLEX multi-op case that crashed the
             first prototype's coalescer (5 native s16 adds, reused locals) now compiles
             clean (-verify-machineinstrs) and reads corpus_result==0x33A0 both emus
  a16localsub #321 Increment 1d-retry step 5: a multi-use LOCAL s16 SUBTRACT goes native
             (sec; rep; lda; sbc; sta; sep in Imag16); corpus_result==0x1222 both emus
  a16localbit #321 Increment 1d-retry step 5: three native s16 bitwise ops on reused locals
             (lda; and|ora|eor zp; sta) compile clean; corpus_result==0x000F both emus
  a16localimm #321 native s16 immediate fold: a multi-use local `a + 0x0345` folds the
             constant to `adc #$0345` (no Imag16 materialization); corpus_result==0x1545 both emus
  a16loadfold #321 native s16 load-fold: multi-use `t = a16v + b16v` reads both globals
             directly (lda/adc abs, no Imag16 materialization); corpus_result==0x2345 both emus
  a16cmp     #321 native s16 16-bit unsigned-ordering compares (< <= > >=): each `if` is one
             rep/lda/cmp/sep/bcc, not the 8-bit cpx/cpy chain; corpus_result==0x1103 both emus
  a16loop    #321 cross-block REP/SEP: a 16-bit loop body holds 16-bit mode across iterations —
             one rep hoisted to the preheader, one sep sunk to the exit, NONE in the body;
             corpus_result==0x2340 both emus
  a16call    #321 cross-block REP/SEP: a call inside a 16-bit region runs 8-bit at the call
             boundary (sep before jsl/jsr, rep after); corpus_result==0x4456 both emus
  a16shift   #321 native s16 constant shifts: x<<k / x>>k (unsigned) select to native 16-bit
             asl/lsr under one rep/sep (no 8-bit rol/ror pairs, no libcall);
             corpus_result==0x1278 both emus
  a16ashift  #321 native s16 signed >> (arithmetic): x>>k on short selects to cmp #$8000; ror
             per bit under one rep/sep (sign-extends; no 8-bit byte chain, no libcall);
             corpus_result==0xFE01 both emus
  a16eq      #321 native s16 equality (== !=): each compare feeding a branch is a fused 16-bit
             rep/lda/cmp/sep/beq|bne (no 8-bit cmp/cpx chain); corpus_result==0x0011 both emus
  a16scmp    #321 native s16 signed ordering (< <= > >=): sign-flip to unsigned (eor #$8000) +
             native 16-bit cmp (no 8-bit N^V chain); corpus_result==0x0111 both emus
  a16abscmp  #321 native s16 compare-operand fold: a global-vs-global compare reads BOTH
             operands directly (lda abs; cmp abs) — no `lda abs; sta tmp` round-trip, no `cmp
             zp` off a materialized Imag16 RHS; corpus_result==0x4303 both emus
  a16mixfold #321 native s16 mixed-operand load-fold: an ALU op mixing a near-abs global with
             an Imag16 local reads the global directly (lda abs as LHS, or adc/sbc/and/ora/eor
             abs as operand) — no Imag16 round-trip for the global; corpus_result==0x2DC0 both emus
  a16sunfold #321 native s16 load-fold (b): a both-global ALU op with a single-use non-store
             result folds both operands directly (selectAlu16Native) — no global materialized
             into an Imag16 pair; corpus_result==0x3480 both emus
  a16chainld #321 native s16 load-fold (c): a multi-use >=3-term add chain of globals threads the
             running sum through A16 (add_chain16_ld) — adc abs per term, no intermediate Imag16
             round-trip; corpus_result==0x1234 both emus
  a16chainimm #321 native s16 ALU-chain ext: a constant term in an add chain (a+b+c+K) folds into
             the threaded chain as a final adc #imm (store + multi-use forms), no round-trip;
             corpus_result==0x2569 both emus
  a16bitchain #321 native s16 bitwise chains: a >=3-term AND/OR/XOR chain of globals threads A16
             (and/ora/eor abs, no carry-init, no round-trip; store + multi-use forms);
             corpus_result==0x6261 both emus
  a16incdec  #321 native s16 inc/dec: a register/local 16-bit x+1 / x-1 selects to one inc a
             (1a) / dec a (3a) in M16, not the 8-bit byte inc/dec carry chain;
             corpus_result==0x2668 both emus
  a16loopred #321 native s16 loop strength-reduction: a counted `while(i){x++;i--}` combines to
             a single native 16-bit add (x += n), not a per-iteration inc loop or libcall;
             corpus_result==0x1239 both emus
  a16incabs  #321 native s16 inc/dec on globals: g = g +-1 selects to lda <g>; inc a/dec a;
             sta <g> (long addressing kept; no clc/adc #1, no DBR-relative inc abs);
             corpus_result==0x3502 both emus
  a16ptr     #321 native s16 indirect load/store: *p / a[i] use one 16-bit lda (zp)/sta (zp) in M16
             (no (zp),y byte pair); corpus_result==0xABCE both emus
  a16abs     #321 native s16 absolute load/store: g = gg uses one 16-bit lda abs/sta abs in M16
             (no X/Y byte shuffle); corpus_result==0x5A3D both emus
  a16copy    #321 native s16 fused indirect copy: g = *p folds the indirect load into the store
             (lda (p); sta g, no Imag16 round-trip); corpus_result==0x3456 both emus
  a16spill   #321 F3 regression (compile-time gate, no emulator): a 16-bit-accumulator value
             spilled across a call must use a direct 16-bit STAbs16/LDAbs16, not a COPY through
             an 8-bit GPR (which crashed as `SelectImm $a16`). Asserts +mos-a16 verify clean.
  a16spillr  #321 soft-stack Ac16 spill regression (value test): a recursive (-> soft-stack)
             function with a 16-bit value live across the call spills A16 via 16-bit indirect
             LDAIndir16/STAIndir16; corpus_result==0x3457 host==default==+mos-a16 on both emus.
  a16spillir #321 HERMETIC soft-stack Ac16 spill gate: llc on a frozen .ll (examples/65816/
             a16spillir.ll, the IR of a16spillr.c) must verify clean + still emit STStk/LDStk $a16
             — drift-immune companion to a16spillr (compile-time, no emulator).
  a16eqval   #321 s16 equality-as-value (`b = (a == c)`): corpus_result==0x0101 host==default==
             +mos-a16; asserts the operands load byte-wise (no wasteful 16-bit-load+spill prologue
             before the 8-bit compare).
  a16eqvalp  #321 v1 gated native s16 equality-as-value through an INDIRECT operand (`*p == c`):
             native `rep; lda (zp); cmp; sep; beq/bne`, no 8-bit cpx/cpy; corpus_result==0x0101.
  a16eqvalg  #321 v3 native s16 equality-as-value abs-fold for GLOBALS (`g1 == g2`, `g1 == 0x1234`):
             reads the globals in place (lda abs; cmp abs/#imm), no Imag16 round-trip, no 8-bit
             cpx/cpy; corpus_result==0x1101 host==default==+mos-a16 on both emulators.
  a16eqvalc  #321 v2 native s16 equality-as-value for COMPUTED/Imag16-resident operands
             (`(a+b) == (c+d)`, `(a+b) == 0x1234`): native 16-bit cmp (no 8-bit cpx/cpy); a
             register operand stays 8-bit (avoids the spill); corpus_result==0x1101 both emulators.
  a16eqvalmg #321 task7 native s16 equality-as-value for COMPUTED vs GLOBAL (`(a+b) == g_global`,
             `g_global == (a+b)`): CmpBrImagAbs16 fold — lda zp_computed; cmp abs_global; no
             cpx/cpy; corpus_result==0x0111 host==default==+mos-a16 on both emulators.
  a16ret     #321 calling-convention: lock the A (low) / X (high) RETURN convention as a tested
             ABI invariant (test+docs only, no codegen change). Disasm gate: the i16 return is
             `ldx <high>; lda <low>; rts` (high byte->X, low byte->A, byte-pinned) and the i8 return
             delivers its result in A alone; value: corpus_result==0x2387 host==default==+mos-a16
             on MAME + bsnes-jg. Prior art: WDC816CC p.21 / ORCA `A_X`.
  fuzz       #321 Tier-1 differential fuzzer: generate N random valid C programs (from
             `seed`, default 25 from seed 1), compile each DEFAULT and +mos-a16, and assert
             host-expected == default@MAME == a16@MAME == a16@bsnes-jg + a clean
             -verify-machineinstrs. Mismatches/crashes land in build/fuzz-triage/.
             Usage: dev/run.sh fuzz [N] [seed]   (e.g. dev/run.sh fuzz 1 1234 to repro a seed)
  k_*        #321 Tier-1 realistic kernels (CRC16, fixed-point mul, PRNG, popcount/bit-reverse,
             saturating add, insertion sort): each asserts host==default==+mos-a16 on both emus
  a16mix*    #321 Tier-1 combinatorial mixing: many s16 features in one body (compares + shifts
             + chains + calls + spills); asserts host==default==+mos-a16 on both emus
  repro      clean-room: fresh checkout, then build + corpus in it (host-side)

Extra ARGS are forwarded to the in-container script (e.g. `fuzz N seed`) or, for
`repro`, to repro.sh.
Env forwarded into the container (when set): SMOKE_WANT, SMOKE_SETTLE, SNES_ROMPATH,
MOS_TOOLCHAIN (toolchain install prefix to build the bench with), BUILD_JOBS.
USAGE
  exit 0
fi

# `repro` is host-side orchestration (clean-room checkout, then build + smoke in it),
# not an in-container target — run it directly and stop.
if [ "$TARGET" = "repro" ]; then
  exec "$HERE/repro.sh" "${@:2}"
fi

docker build -t "$IMAGE" "$HERE" >/dev/null
mkdir -p "$ROOT/build"
# Forward the optional knobs into the container when set (name-only -e reads the
# value from this script's environment — safe under `set -u` via :+).
exec docker run --rm \
  -v "$ROOT":/work \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/build \
  ${SMOKE_WANT:+-e SMOKE_WANT} \
  ${SMOKE_SETTLE:+-e SMOKE_SETTLE} \
  ${SNES_ROMPATH:+-e SNES_ROMPATH} \
  ${MOS_TOOLCHAIN:+-e MOS_TOOLCHAIN} \
  ${BUILD_JOBS:+-e BUILD_JOBS} \
  "$IMAGE" bash "/work/dev/${TARGET}.sh" "${@:2}"
