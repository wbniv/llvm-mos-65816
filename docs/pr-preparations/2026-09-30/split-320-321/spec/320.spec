# Stage assignment for the #320 split (diff lines refer to 320.diff).
#  1 quads   Add the far address space and 32-bit imaginary pointer quads
#  2 farmem  Legalize and select far pointer values and memory accesses
#  3 memops  Route far memory intrinsics to the far runtime
#  4 dpy     Select bounded runtime [dp],Y indexing for far byte accesses

file llvm/lib/Target/MOS/MOSAsmPrinter.cpp 4
file llvm/lib/Target/MOS/MOSCallLowering.cpp 2
file llvm/lib/Target/MOS/MOSCallingConv.td 2
file llvm/lib/Target/MOS/MOSISelLowering.cpp 2

file llvm/lib/Target/MOS/MOSInstrGISel.td 2
range 117 146 4

file llvm/lib/Target/MOS/MOSInstrInfo.cpp 1
file llvm/lib/Target/MOS/MOSInstrInfo.h 2
range 172 184 1

file llvm/lib/Target/MOS/MOSInstrLogical.td 2
range 229 258 4

file llvm/lib/Target/MOS/MOSInstructionSelector.cpp 2
range 294 296 4
range 311 314 4
range 453 487 4
range 497 498 4
range 500 502 4
interim 502 2 4
|       MI.getOpcode() == MOS::G_STORE_FAR_INDIR) {
range 521 523 4
range 537 539 4

file llvm/lib/Target/MOS/MOSLateOptimization.cpp 2

file llvm/lib/Target/MOS/MOSLegalizerInfo.cpp 2
range 561 568 3
range 735 738 4
range 792 1030 4
range 1034 1142 3

file llvm/lib/Target/MOS/MOSLegalizerInfo.h 2
range 1167 1171 4

file llvm/lib/Target/MOS/MOSMCInstLower.cpp 2
range 1201 1212 1

file llvm/lib/Target/MOS/MOSRegisterBanks.td 1
file llvm/lib/Target/MOS/MOSRegisterInfo.cpp 1
range 1285 1316 2
file llvm/lib/Target/MOS/MOSRegisterInfo.td 1
file llvm/lib/Target/MOS/MOSTargetMachine.cpp 1
file llvm/lib/Target/MOS/MOSZeroPageAlloc.cpp 1
file llvm/lib/TargetParser/TargetDataLayout.cpp 1

file llvm/test/CodeGen/MOS/far-addressing.ll 2
file llvm/test/CodeGen/MOS/far-phi.ll 2
file llvm/test/CodeGen/MOS/far-memset.ll 3
file llvm/test/CodeGen/MOS/far-indir-indexed.ll 4

# Focused test added by the split (not in the monolithic patch).
file llvm/test/CodeGen/MOS/imag32-copy.mir 1
