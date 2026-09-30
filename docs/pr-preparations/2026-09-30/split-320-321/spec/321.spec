# Stage assignment for the #321 split (diff lines refer to 321.diff).
#  1 regs      Model native registers and feature gates
#  2 accforms  Define 16-bit accumulator instruction forms
#  3 idxforms  Define 16-bit index instruction forms and X-width requirements
#  4 repsep    Insert REP/SEP from M/X width requirements
#  5 scav      Preserve status flags across register scavenging
#  6 spill     Spill and copy native-width registers
#  7 coalesce  Keep call-clobbered imaginary copies out of Imag16 pairs
#  8 mem       Legalize and select native 16-bit loads and stores
#  9 wide      Legalize native s32/s64 lanes and wide any-extensions
# 10 alu       Select native 16-bit arithmetic, logic and constant shifts
#              (with the post-RA A16 residency peephole and byte-store tests)
# 11 cmp       Select native 16-bit compares and fused branches
# 12 byteidx   Keep byte indexes byte-wide in absolute indexed addressing
# 13 nowrap    Require a no-wrap proof before folding near indexes on the 65816
# 14 xy16      Select 16-bit index registers under +mos-xy16
# 15 pressure  Keep small 8-bit adds relocatable under +mos-a16
# 16 isr       Preserve interrupted M/X state in 65816 interrupt handlers

file llvm/lib/Target/MOS/MOSFeatures.td 1
file llvm/lib/Target/MOS/MOSSubtarget.h 1
file llvm/lib/Target/MOS/MOSRegisterInfo.td 1
file llvm/lib/Target/MOS/MOSRegisterBanks.td 1

file llvm/lib/Target/MOS/MCTargetDesc/MOSInstPrinter.cpp 2
file llvm/lib/Target/MOS/MCTargetDesc/MOSInstPrinter.h 2
file llvm/lib/Target/MOS/MOSInstrFormats.td 2
range 1080 1085 3
range 1106 1121 3
file llvm/lib/Target/MOS/MOSInstrInfo.td 3
file llvm/lib/Target/MOS/MOSInstrLogical.td 2
range 1546 1554 3
range 1558 1592 14
range 1722 1769 3
range 1923 2079 3

file llvm/lib/Target/MOS/CMakeLists.txt 4
file llvm/lib/Target/MOS/MOS.h 4
file llvm/lib/Target/MOS/MOSInsertREPSEP.cpp 4
file llvm/lib/Target/MOS/MOSInsertREPSEP.h 4
file llvm/lib/Target/MOS/MOSTargetMachine.cpp 4
file llvm/test/CodeGen/MOS/insert-rep-sep-cloned-kills.mir 4
file llvm/test/CodeGen/MOS/insert-rep-sep-stack.mir 4

file llvm/lib/Target/MOS/MOSRegisterInfo.cpp 6
range 4658 4668 7
range 4837 5072 5
range 5074 5101 11
range 5277 5337 7
file llvm/lib/Target/MOS/MOSRegisterInfo.h 6

file llvm/lib/Target/MOS/MOSInstrInfo.cpp 11
range 1290 1358 6
file llvm/lib/Target/MOS/MOSInstrInfo.h 11
file llvm/lib/Target/MOS/MOSInstrPseudos.td 11

file llvm/lib/Target/MOS/MOSInstrGISel.td 8
range 1227 1253 14

file llvm/lib/Target/MOS/MOSLegalizerInfo.h 8
range 4609 4627 9

file llvm/lib/Target/MOS/MOSLegalizerInfo.cpp 8
range 3582 3582 14
range 3584 3584 13
range 3588 3667 9
range 3668 3705 10
range 3733 3849 9
range 3850 3886 10
range 3887 4093 11
range 4098 4174 14
range 4286 4286 14
range 4292 4300 14
range 4359 4375 13
range 4390 4392 14
range 4394 4402 14
interim 4402 8 14
|   // Returns the abs-indexed or indir-indexed opcode for the access.
|   auto AbsIdxOpc = [&]() -> unsigned {
|     return IsLoad ? MOS::G_LOAD16_ABS_IDX : MOS::G_STORE16_ABS_IDX;
|   };
|   auto IndirIdxOpc = [&]() -> unsigned {
|     return IsLoad ? MOS::G_LOAD16_INDIR_IDX : MOS::G_STORE16_INDIR_IDX;
|   };
range 4447 4448 13
range 4479 4485 14
range 4501 4501 14
interim 4501 8 14
|     if (!VarIndex && ConstOffset >= 1 && ConstOffset <= 255) {
range 4523 4524 13
range 4532 4573 12
range 4574 4579 14
range 4587 4589 13
range 4597 4601 14

file llvm/lib/Target/MOS/MOSInstructionSelector.cpp 11
range 2148 2151 10
range 2152 2153 14
range 2154 2156 10
range 2157 2177 8
range 2185 2224 10
range 2227 2232 14
range 2240 2255 8
range 2256 2263 14
range 2267 2315 15
range 2316 2341 10
range 2536 2538 10
range 2539 2553 14
range 2554 2557 10
range 2558 2559 14
range 2560 2588 10
range 2589 2589 14
interim 2589 10 14
|       noClobberBetween(Def, User, AA))
range 2590 2593 10
range 2701 2867 10
range 2868 3211 14
range 3212 3275 10
range 3276 3452 8

file llvm/lib/Target/MOS/MOSAsmPrinter.cpp 14
file llvm/lib/Target/MOS/MOSLateOptimization.cpp 10
file llvm/lib/Target/MOS/MOSFrameLowering.cpp 16

file llvm/test/CodeGen/MOS/a16-byte-store.ll 10
file llvm/test/CodeGen/MOS/a16-indirect-byte-store.ll 10
file llvm/test/CodeGen/MOS/a16-immediate-width.ll 11
file llvm/test/CodeGen/MOS/anyext-masked-byte.ll 9
file llvm/test/CodeGen/MOS/anyext-wide.mir 9
file llvm/test/CodeGen/MOS/legalizer.mir 12
file llvm/test/CodeGen/MOS/legalizer-indexed-offset-observer.mir 12
file llvm/test/CodeGen/MOS/zp-byte-index.ll 12
file llvm/test/CodeGen/MOS/xy16-near-indir-y.ll 14
file llvm/test/CodeGen/MOS/interrupt-width-65816.ll 16

# The pressure-set hooks take the optimization level from the subtarget.
file llvm/lib/Target/MOS/MOSSubtarget.cpp 8

# Focused tests added by the split (not in the monolithic patch).
file llvm/test/CodeGen/MOS/native-width-registers.mir 1
file llvm/test/CodeGen/MOS/a16-accumulator-forms.mir 2
file llvm/test/MC/MOS/index-width-mapping-65816.s 3
file llvm/test/CodeGen/MOS/xy16-index-forms.mir 3
file llvm/test/CodeGen/MOS/scavenger-p-undef-6502.ll 5
file llvm/test/CodeGen/MOS/native-spill-copy.mir 6
file llvm/test/CodeGen/MOS/coalesce-call-clobbered-imag.mir 7
file llvm/test/CodeGen/MOS/a16-load-store.ll 8
file llvm/test/CodeGen/MOS/near-index-nowrap.ll 13
file llvm/test/CodeGen/MOS/a16-small-add.ll 15
file llvm/test/CodeGen/MOS/native-width-default-pressure.ll 1
file llvm/test/CodeGen/MOS/native-width-pressure-opt-level.ll 8

# Native-width pressure sets: lines only in the regenerated diff.
range 4662 4662 8
range 4673 4686 8
range 4689 4692 8
range 4700 4815 8
range 5346 5346 8
range 5349 5349 8
range 5357 5357 8
range 5361 5372 8
range 5374 5375 8
range 5383 5393 8
range 5450 5454 1
range 5464 5464 1
range 5477 5478 8
range 7529 7652 1
range 7659 7688 8
