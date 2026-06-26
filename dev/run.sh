#!/usr/bin/env bash
# Host-side driver: (re)build the dev image and run a dev/<target>.sh inside it
# against this repo. Usage: dev/run.sh [build|compile|validate|crt0native|smoke|corpus|dwarf|toolchain|asserts-build|far|far-run|far-bank1|far_indir|far_cast|far_arith|far_store|far_memops|far_call|far_near_call|far_tail|far_fnptr|far_indir_tail|farindex|xcheck|xcheck-suite|a16|a16add|a16sub|a16bit|a16imm|a16chain|a16local|a16localx|a16localsub|a16localbit|a16localimm|a16loadfold|a16cmp|a16loop|a16call|a16shift|a16ashift|a16eq|a16scmp|a16abscmp|a16mixfold|a16sunfold|a16chainld|a16chainimm|a16bitchain|a16incdec|a16loopred|a16incabs|a16ptr|a16abs|a16copy|a16spill|a16spillr|a16spillir|a16unmerge|a16eqval|a16eqvalp|a16eqvalg|a16eqvalc|a16eqvalmg|a16ret|a16absidx|a16frameidx|a16indiry|a16cmpidx|a16cmpaudit|a16loadcall|a16s32|a16scavnz|xy16basic|xy16spill|xy16spillr|xy16ops|xy16indiry|xy16call|known-issues|repro] (default: build)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
IMAGE="${MOS_DEV_IMAGE:-llvm-mos-65816-dev}"
DEV_DOCKERFILE="${MOS_DEV_DOCKERFILE:-Dockerfile}"
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
  crt0native #321 native-mode crt0 contract gate: assert the reset preamble is
             byte-exact INCLUDING the explicit DBR=0 establishment (phk/plb = 4b ab
             after sep #$30), the native+emulation interrupt vectors are placed, and
             a DEFAULT (8-bit) build's DBR-relative `abs` global access round-trips
             corpus_result==0x2345 on MAME (+ bsnes-jg) — i.e. DBR=0 holds at runtime
             (needs `toolchain` + `build` first)
  smoke      boot build/hello.sfc headless in MAME, assert sentinel==0x42
             (needs the SPC700 IPL at dev/roms/s_smp/spc700.rom)
  corpus     run the regression corpus headless in MAME: assert each program in
             examples/snes/corpus/ against examples/snes/corpus/expected.tsv
  corpus-a16 run the regression corpus under +mos-a16 (differential): each
             examples/snes/corpus/*.c asserted host == default == +mos-a16 ==
             +mos-xy16 on MAME + bsnes-jg (all programs PASS — globals.c's
             regalloc-out-of-registers was fixed in patch 0009, now a positive gate).
             Closes the "corpus only ever built default 8-bit" gap that hid it.
  mandel-shot #321: render the canonical on-SNES Mandelbrot tester ON the SNES
             (examples/snes/mandel-display.c, +mos-a16; far-stored into high WRAM,
             displayed via Mode 7) and capture a REAL emulator screenshot from BOTH cores
             headless — bsnes-jg (framebuffer dump via jgxcheck) + MAME (video:snapshot
             under Xvfb) — each asserting the on-screen buffer's CRC == the host renderer
             (0x204F; build/mandel-{jg,mame,host}.png). See
             docs/investigations/snes-emulator-screenshots.md.
  invaders   #321 Space Invaders on the snesgfx OOP library (examples/snes/invaders.c):
             run the DETERMINISTIC attract sim and assert its rolling state-CRC host ==
             default@MAME == a16@MAME == default/a16@bsnes-jg (no far pointers, so default +
             a16 both build), then snapshot the rendered frame from MAME (Xvfb) + bsnes-jg
             (build/invaders-{mame,jg}.png).
  mandel-far  #321 beefy demo, Track 3a: fill a HIGH-WRAM buffer ($7E2000, reachable
             only by 24-bit addressing) with the Mandelbrot via #320 far stores
             (sta [dp]), CRC it via far loads; +mos-a16-only, asserts host == +mos-a16
             (0x820B) on MAME + bsnes-jg + a disasm gate (examples/65816/k_mandel_far.c)
  known-issues XPASS guard: assert each tools/a16_fuzz.py KNOWN_ISSUE_REPROS repro
             STILL crashes -verify-machineinstrs under both +mos-a16 and +mos-xy16 with its
             expected signature; fails loudly the moment one verifies clean -> drop the entry
             + promote to a positive gate. Currently VACUOUS — KNOWN_ISSUE_REPROS is empty (all
             tracked crashes FIXED: a16regpress->0009, a16scavnz->0011/0012, both positive gates;
             KNOWN_ISSUES emptied by the pr15296 stale-XFAIL resolution). Re-arms automatically when
             a new XFAIL is added. Toolchain-only (no SDK/emulator/secret).
  dwarf      ROADMAP step 6 compiler-side gate: a `-g` build emits verifiable DWARF
             AND ld.lld writes the <output>.elf debug companion — assert (shapes,
             not addrs): companion present, --verify clean, addr_size 0x04,
             frame_base RS0, the 16-bit local has a DW_OP_regx location, line table
             maps the source (needs `toolchain` + `build`). drmon-side: drdevtools
             `task test-dap`.
  toolchain  build llvm-mos (clang/lld) FROM SOURCE -> build/llvm-mos-install
             (for M1 codegen; long first build — see dev/toolchain.sh)
  cross-toolchain  cross-build the clang/lld/llvm-* HOST tools for a NON-native host
             (linux-arm64 | windows-x86_64 | macos-arm64) from this x86-64 Linux
             container -> build/llvm-mos-install-<profile>. Runs in the cross image
             (dev/Dockerfile.cross); needs `toolchain` first (reuses its native
             tablegens; the host-agnostic mos builtins+SDK are grafted at package time).
             See dev/cross-toolchain.sh / docs/plans/2026-06-25-cross-platform-toolchain-builds.md
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
  far_indir  #320 Increment 3: build examples/65816/far_indir.c (snes-far, +mos-a16),
             assert a RUNTIME far pointer dereference lowers to indirect-long
             (`lda [dp]`, A7) not absolute-long, boot in MAME, and check the
             cross-bank runtime far read round-trips == 0xF3 (needs `toolchain` + `build`)
  far_cast   #320 Increment 3 (3b): build examples/65816/far_cast.c (snes, +mos-a16),
             assert a near->far address-space cast then RUNTIME deref lowers to
             indirect-long (`lda [dp]`, A7), boot in MAME, check bank-$00 read == 0xF3
  far_arith  #320 Increment 3 (3c): build examples/65816/far_arith.c (snes, +mos-a16),
             assert far-pointer arithmetic (fp++ -> G_PTR_ADD {PF,S32}) then RUNTIME
             deref lowers to indirect-long (`lda [dp]`, A7), boot in MAME, read == 0xF3
  far_store  #320 Inc 3 follow-up: build examples/65816/far_store.c (snes, +mos-a16),
             assert a RUNTIME far-pointer STORE lowers to indirect-long (`sta [dp]`,
             87), boot in MAME, read the stored byte back == 0xF3
  far_memops #320/#321: build examples/65816/far_memops.c (snes, +mos-a16), assert a
             far memset/memcpy routes to the FAR runtime (__memset_far/__memcpy_far),
             boot in MAME at -Os/-O2, read high-WRAM ($7E) back == 0x74 (right bank)
  far_loop   #321: build examples/65816/far_loop.c (snes, +mos-a16), assert a far-pointer
             INDUCTION-VARIABLE loop compiles (was: G_PHI(p2) backend abort) -> sta/lda [dp];
             boot in MAME at -Os/-O2, far-ptr IV write+read-back of high-WRAM ($7E) == 0xC9
  far_call   #320 Increment 4: build examples/65816/far_call.c (snes-far), assert a
             call to a bank-$01 function emits JSL ($22) + the leaf returns RTL ($6b),
             boot in MAME, check the value returned across the bank boundary == 0xF3
  far_near_call #320 follow-up (b): far (bank $01) -> near (bank $00) mixed-banking;
             build examples/65816/far_near_call.c (snes-far), assert the far->near call
             emits JSL __call_near_from_far (thunk: pea/jmp-ind/rtl), boot in MAME,
             check the value folded up main->far->near->near == 0xE0
  far_tail   #320 far tail calls: build examples/65816/far_tail.c (snes-far), assert a
             far->far TAIL call is folded to a long jmp ($5C TailJML, not jsl+rtl),
             boot in MAME, check the value folded main->far_outer->far_inner == 0xE0
  far_fnptr  #320 far function pointers: build examples/65816/far_fnptr.c (snes-far,
             +mos-a16), assert a far INDIRECT call routes JSL __call_indir_far (thunk:
             jml (__mos_far_target)), boot in MAME, check far_leaf(0x5A) == 0xFF
  far_indir_tail #320 Phase B: build examples/65816/far_indir_tail.c (snes-far, +mos-a16),
             assert a far function's far-INDIRECT tail folds to a long jmp __call_indir_far
             ($5C TailJML, not jsl+rtl), boot in MAME, check far_outer(0x5A) == 0xFF
  farindex   #320 "far data > 2 banks" gate: a const FAR uint16_t tbl[] spanning banks
             $C1..$C3 (98304 x uint16, snes-hirom) read at 3 volatile indices (100/50000/
             90000) that land in 3 distinct banks via lda [dp] (A7, R_MOS_ADDR24); folds
             corpus_result==0x0001D8A1, host==+mos-a16 on MAME+bsnes-jg (a16-only)
  xcheck     second-emulator fidelity cross-check: boot the far ROMs in bsnes-jg
             (cycle-accurate, independent of MAME) headless and assert the same
             WRAM results — confirms the bank-$01 far read isn't a MAME quirk
             (fetches+builds bsnes-jg once; needs `toolchain` + `build` first)
  torture    #321 Phase 1: run N in-scope gcc c-torture/execute tests through the
             differential gate (default == +mos-a16 == +mos-xy16; default build is the
             oracle, so a non-PASS default SKIPs and any FAIL is a real defect).
             Usage: dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--sample N [--sample-seed S]] [--no-bsnes]
             (--sample N = seeded pseudo-random subset of N tests, reproducible; for sampled CI)
             (host prereq: dev/fetch-torture.sh && python3 tools/torture_filter.py)
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
  a16unmerge #321 HERMETIC +mos-a16 s32 (long/int32_t) gate: a frozen .ll (examples/65816/
             a16unmerge.ll, seed-11 IR) must compile clean under +mos-a16 (was: "unable to
             legalize ... G_UNMERGE_VALUES s32"). s32 is now 2x s16 under a16 (legalizer glue).
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
  xy16basic  #321 xy16 smoke: +mos-xy16 accepted + implies +mos-a16 (rep #$20/stz/sep #$20 fires,
             no spurious rep/sep #$10) + corpus_result==0x0042 on both emulators.
  xy16spill  #321 xy16 static-stack Ac16 spill gate (compile-time, no emulator): Layer 4
             Ac16 spill path (MOSInstrInfo) still fires clean under +mos-xy16 (-verify-machineinstrs).
  xy16spillr #321 xy16 Increment 1e indexed-access gate: LDXImag16+LDAbsXIdx16 fires under
             +mos-xy16 (no Imag16→Xc16 COPY crash); corpus_result==0x3457 both emus.
  xy16ops    #321 xy16 B2 legalizer gate: unmasked volatile 16-bit index triggers
             G_LOAD_ABS_IDX16 → LDXImag16+LDAbsXIdx16; corpus_result==0x2A42 both emus.
  xy16indiry #321 xy16 B2 (zp),Y16 gate: runtime zp pointer + unmasked 16-bit offset
             triggers G_LOAD_INDIR_IDX16 → LDYImag16+LDIndirYIdx16 (lda (dp),Y, no
             byte-walk); corpus_result==0x7E5A host==default==+mos-a16==+mos-xy16 both emus.
  xy16call   #321 xy16 CROSS-CALL boundary gate: a genuine 16-bit index held live across a
             clobbering noinline call (survives in a callee-saved ZP pair, reloaded LDXImag16
             post-call; X narrowed/re-widened around the jsr); corpus_result==0x7E5A both emus.
  a16ret     #321 calling-convention: lock the A (low) / X (high) RETURN convention as a tested
             ABI invariant (test+docs only, no codegen change). Disasm gate: the i16 return is
             `ldx <high>; lda <low>; rts` (high byte->X, low byte->A, byte-pinned) and the i8 return
             delivers its result in A alone; value: corpus_result==0x2387 host==default==+mos-a16
             on MAME + bsnes-jg. Prior art: WDC816CC p.21 / ORCA `A_X`.
  a16absidx  #321 Increment 1e: native 16-bit abs,x indexed load (`lda abs,x` in M16, opcode BD).
             8-bit byte offset from g_bytes[] -> one rep/sep + lda abs,x (no byte pair).
             corpus_result==0x9ABC host==default==+mos-a16 on both emulators.
  a16frameidx #321 regression: eliminateFrameIndex / CmpBrAbsImm16 frame-index scramble (root-caused
             via c-torture 20071210-1; one fix cleared 13 differential miscompiles). A stack s[6]
             compared vs constants folds to static-stack CmpBrAbsImm16; the displacement must come from
             the frame index, not the compare immediate. corpus_result==0x4321 on both emulators.
  a16indiry  #321 Increment 1e: native 16-bit (zp),y indexed load (`lda (zp),y` in M16, opcode B1).
             Runtime pointer + 8-bit Y offset -> one rep/sep + lda (zp),y (no iny/byte pair).
             corpus_result==0x5678 host==default==+mos-a16 on both emulators.
  a16cmpidx  #321 native s16 RHS-indexed unsigned-ordering compare fold: a single-use arr[k]/p[k]
             on the RHS of `lim < arr[k]` folds into one `cmp (zp)` (CMPIndir16, opcode D2) under a
             rep/sep bracket instead of staging through an Imag16 temp; `lim > arr[k]` swaps arr[k]
             to the LHS (lda (zp); cmp). corpus_result==0x1111 host==default==+mos-a16 both emulators.
  a16cmpaudit #321 Phase-3 differential-audit of the WHOLE 16-bit compare surface: 8 predicates x
             {as-value, as-branch} x RHS shapes {reg, imm, global, global-array[k], pointer[k],
             stack-array[k]} + LHS-indexed control, over boundary values. host==default==+mos-a16
             (0x5EE0) on both emulators, -verify-machineinstrs clean.
  a16loadcall #321 regression (gcc c-torture pr34768 class): a 16-bit abs/(zp) load live across a
             memory-clobbering call must NOT fold into the post-call ALU/compare operand (else it
             re-reads the mutated memory). host==default==+mos-a16 (0x0100) both emulators.
  a16s32     #321 32-bit long/int32_t value differential: folds every s32 hazard (2x s16 carry,
             4x s8<->s32 (un)merge, shifts, __mulsi3/__udivsi3/__umodsi3 libcalls, s16->s32 ext,
             s32 compare-as-value) into a 32-bit corpus_result; host==default==+mos-a16==0x50F2B870
             on both emulators (full 4-way — long works in the default 8-bit build too).
  fuzz       #321 Tier-1 differential fuzzer: generate N random valid C programs (from
             `seed`, default 25 from seed 1), compile each DEFAULT, +mos-a16, and +mos-xy16,
             and assert host-expected == default@MAME == a16@MAME == xy16@MAME == a16@bsnes-jg
             + clean -verify-machineinstrs under both +mos-a16 and +mos-xy16.
             Mismatches/crashes land in build/fuzz-triage/.
             --gen csmith  (DEFAULT) the off-the-shelf Csmith generator, run HOST-side
                           (default-build-as-oracle: default == +mos-a16 == +mos-xy16);
                           builds vendor/csmith on demand. See dev/csmith.sh.
             --gen builtin the hand-rolled generator with its own 4-way host oracle, run
                           in-container (today's behavior). See dev/fuzz.sh.
             Usage: dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]
                    (e.g. dev/run.sh fuzz --gen csmith 1 11 to repro one Csmith seed)
  k_*        #321 Tier-1 realistic kernels (CRC16, fixed-point mul, PRNG, popcount/bit-reverse,
             saturating add, insertion sort, Mandelbrot escape-time): each asserts
             host==default==+mos-a16 on both emus. k_mandel is the beefy fixed-point demo
             (gate slice; full image rendered host-side via tools/mandel-render + on-console)
  a16mix*    #321 Tier-1 combinatorial mixing: many s16 features in one body (compares + shifts
             + chains + calls + spills); asserts host==default==+mos-a16 on both emus
  xcheck-suite  bsnes-jg-ONLY confirmation: run the a16/xy16 value tests' second-
             emulator leg with JG_ONLY=1 (MAME skipped), serial + nice. Deterministic
             → needs no quiet box and no SPC700 BIOS. Optional PREFIX arg filters
             (e.g. `xcheck-suite xy16`). Needs `xcheck` run first (builds build/jgxcheck).
  repro      clean-room: fresh checkout, then build + corpus in it (host-side)

Extra ARGS are forwarded to the in-container script (e.g. `fuzz N seed`) or, for
`repro`, to repro.sh.
Env forwarded into the container (when set): SMOKE_WANT, SMOKE_SETTLE, SNES_ROMPATH,
MOS_TOOLCHAIN (toolchain install prefix to build the bench with), BUILD_JOBS,
JG_ONLY (=1 → bsnes-jg-only: skip the MAME leg, used by xcheck-suite / a single test).
USAGE
  exit 0
fi

# `repro` is host-side orchestration (clean-room checkout, then build + smoke in it),
# not an in-container target — run it directly and stop.
if [ "$TARGET" = "repro" ]; then
  exec "$HERE/repro.sh" "${@:2}"
fi

# `fuzz` dispatches by generator (--gen, default csmith). The Csmith generator and its
# differential run are HOST-side (csmith builds on the host into gitignored vendor/csmith;
# MAME + bsnes-jg are host tools) — no Docker, so it's intercepted here like `repro`. The
# builtin generator keeps the in-container path (dev/fuzz.sh) byte-for-byte unchanged.
if [ "$TARGET" = "fuzz" ]; then
  GEN=csmith
  ARGS=()
  S32=()
  for ((i = 2; i <= $#; i++)); do
    case "${!i}" in
      --gen)   i=$((i + 1)); GEN="${!i-}" ;;
      --gen=*) GEN="${!i#--gen=}" ;;
      --s32)   S32=(--s32) ;;   # builtin-only: the 32-bit long/int32_t generator track
      *)       ARGS+=("${!i}") ;;
    esac
  done
  case "$GEN" in
    csmith)  [ ${#S32[@]} -eq 0 ] || { echo "FATAL: dev/run.sh fuzz --s32 applies only to --gen builtin (csmith already emits 32-bit)" >&2; exit 1; }
             exec "$HERE/csmith.sh" "${ARGS[@]}" ;;
    builtin) set -- fuzz "${ARGS[@]}" "${S32[@]}" ;;  # fall through to the in-container dispatch below
    *)       echo "FATAL: dev/run.sh fuzz: unknown --gen '$GEN' (want: csmith | builtin)" >&2; exit 1 ;;
  esac
fi

# `cross-toolchain` builds the llvm-mos HOST tools for a NON-native host (linux-arm64 /
# windows-x86_64 / macos-arm64); `cross-selftest` runs the produced foreign compiler under
# qemu/wine to prove it compiles a SNES ROM warning-free with byte-identical output. Both run
# in a SEPARATE image carrying the cross toolchains + emulators (dev/Dockerfile.cross, FROM
# the base image), so the shared base image stays untouched.
if [ "$TARGET" = "cross-toolchain" ] || [ "$TARGET" = "cross-selftest" ]; then
  IMAGE="${MOS_DEV_IMAGE:-llvm-mos-65816-dev-cross}"
  DEV_DOCKERFILE="${MOS_DEV_DOCKERFILE:-Dockerfile.cross}"
  # Dockerfile.cross is FROM the base image — make sure it exists locally first.
  docker build -t llvm-mos-65816-dev -f "$HERE/Dockerfile" "$HERE" >/dev/null
fi

docker build -t "$IMAGE" -f "$HERE/$DEV_DOCKERFILE" "$HERE" >/dev/null
mkdir -p "$ROOT/build"
# Forward the optional knobs into the container when set (name-only -e reads the
# value from this script's environment — safe under `set -u` via :+).
# Filter the benign, high-volume "different data layouts" linker warnings out of stderr: a
# +mos-a16 object carries the far p2/p3 address spaces in its datalayout, but the prebuilt libcrt
# does not — ld.lld warns per archive member, which buries the real output. The mismatch is
# harmless (the libs use no far pointers); everything else (incl. genuine errors) passes through.
# stdout (the SMOKE/VIEW/RESULT lines) is untouched. docker's exit status is preserved.
docker run --rm \
  -v "$ROOT":/work \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/build \
  ${SMOKE_WANT:+-e SMOKE_WANT} \
  ${SMOKE_SETTLE:+-e SMOKE_SETTLE} \
  ${SNES_ROMPATH:+-e SNES_ROMPATH} \
  ${MOS_TOOLCHAIN:+-e MOS_TOOLCHAIN} \
  ${BUILD_JOBS:+-e BUILD_JOBS} \
  ${REF_SHA:+-e REF_SHA} \
  ${RUNNER:+-e RUNNER} \
  ${STAGE_REL:+-e STAGE_REL} \
  ${JG_ONLY:+-e JG_ONLY} \
  "$IMAGE" bash "/work/dev/${TARGET}.sh" "${@:2}" \
  2> >(grep -vF 'different data layouts' | cat -s >&2)
exit $?
