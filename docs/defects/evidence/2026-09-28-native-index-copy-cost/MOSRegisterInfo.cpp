//===-- MOSRegisterInfo.cpp - MOS Register Information --------------------===//
//
// Part of LLVM-MOS, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the MOS implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#include "MOSRegisterInfo.h"

#include "MCTargetDesc/MOSMCTargetDesc.h"
#include "MOS.h"
#include "MOSFrameLowering.h"
#include "MOSInstrBuilder.h"
#include "MOSInstrCost.h"
#include "MOSInstrInfo.h"
#include "MOSMachineFunctionInfo.h"
#include "MOSSubtarget.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetFrameLowering.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/CodeGen/VirtRegMap.h"
#include "llvm/IR/CallingConv.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/Support/ErrorHandling.h"

#define DEBUG_TYPE "mos-reginfo"

#define GET_REGINFO_TARGET_DESC
#include "MOSGenRegisterInfo.inc"

using namespace llvm;

MOSRegisterInfo::MOSRegisterInfo()
    : MOSGenRegisterInfo(/*RA=*/0, /*DwarfFlavor=*/0, /*EHFlavor=*/0,
                         /*PC=*/0, /*HwMode=*/0),
      Imag8SymbolNames(new std::string[getNumRegs()]), Reserved(getNumRegs()) {
  for (unsigned Reg : seq(0u, getNumRegs())) {
    // Pointers are referred to by their low byte in the addressing modes that
    // use them.
    unsigned R = Reg;
    // an Imag32 quad is named by its lowest byte's __rc symbol
    // (low 16-bit word -> low byte), so `lda [dp]` reads dp..dp+2 from there.
    if (MOS::Imag32RegClass.contains(R))
      R = getSubReg(R, MOS::sublo16);
    if (MOS::Imag16RegClass.contains(R))
      R = getSubReg(R, MOS::sublo);
    if (!MOS::Imag8RegClass.contains(R))
      continue;
    std::string &Str = Imag8SymbolNames[Reg];
    Str = "__";
    Str += getName(R);
    std::transform(Str.begin(), Str.end(), Str.begin(), ::tolower);
  }

  // Reserve all imaginary registers beyond the number allowed to the compiler.
  for (Register Ptr : enum_seq_inclusive(MOS::RS16, MOS::RS127))
    reserveAllSubregs(&Reserved, Ptr);

  // Reserve stack pointers.
  reserveAllSubregs(&Reserved, MOS::RS0);

  // Reserve one temporary register for use by register scavenger.
  reserveAllSubregs(&Reserved, MOS::RS8);
}

const MCPhysReg *
MOSRegisterInfo::getCalleeSavedRegs(const MachineFunction *MF) const {
  const MOSFrameLowering &TFI = *getFrameLowering(*MF);
  return TFI.isISR(*MF) ? MOS_Interrupt_CSR_SaveList : MOS_CSR_SaveList;
}

const uint32_t *
MOSRegisterInfo::getCallPreservedMask(const MachineFunction &MF,
                                      CallingConv::ID CallingConv) const {
  return MOS_CSR_RegMask;
}

BitVector MOSRegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  const TargetFrameLowering *TFI = getFrameLowering(MF);
  BitVector Reserved = this->Reserved;
  if (TFI->hasFP(MF))
    reserveAllSubregs(&Reserved, getFrameRegister(MF));
  // an Imag32 quad (RL = RS:RS pair) is unallocatable whenever
  // either of its 16-bit RS words is reserved — the stack pointer (RS0), the
  // scavenger slot (RS8), the frame pointer, or any RS beyond the imaginary
  // window. Reserve the QUAD itself only; its free RS sibling must stay available
  // for ordinary 16-bit allocation (so we can't reserveAllSubregs it). Without
  // this the allocator would happily place a far pointer over the stack pointer.
  for (MCPhysReg Q : MOS::Imag32RegClass) {
    if (Reserved.test(getSubReg(Q, MOS::sublo16)) ||
        Reserved.test(getSubReg(Q, MOS::subhi16)))
      Reserved.set(Q);
  }
  return Reserved;
}

const TargetRegisterClass *
MOSRegisterInfo::getLargestLegalSuperClass(const TargetRegisterClass *RC,
                                           const MachineFunction &) const {
  if (RC->hasSuperClass(&MOS::Anyi1RegClass))
    return &MOS::Anyi1RegClass;
  if (RC->hasSuperClass(&MOS::Anyi8RegClass))
    return &MOS::Anyi8RegClass;
  return RC;
}

const TargetRegisterClass *
MOSRegisterInfo::getCrossCopyRegClass(const TargetRegisterClass *RC) const {
  if (RC == &MOS::Imag8RegClass)
    return &MOS::GPRRegClass;
  if (RC == &MOS::YcRegClass || RC == &MOS::XYRegClass)
    return &MOS::AImag8RegClass;
  return RC;
}

// These values were chosen empirically based on the desired behavior of llc
// test cases. These values will likely need to be retuned as more examples come
// up.  Unfortunately, the way the register allocator actually uses this is very
// heuristic, and if tuning these params doesn't suffice, we'll need to build a
// more sophisticated analysis into the register allocator.
unsigned MOSRegisterInfo::getCSRCost(const MachineFunction &MF) const {
  const MOSFrameLowering &TFL =
      *MF.getSubtarget<MOSSubtarget>().getFrameLowering();
  return TFL.usesStaticStack(MF) ? 15 * 16384 / 10 : 5 * 16384 / 10;
}

static bool pushPullBalanced(MachineBasicBlock::iterator Begin,
                             MachineBasicBlock::iterator End) {
  int64_t PushCount = 0;
  for (const MachineInstr &MI : make_range(Begin, End)) {
    switch (MI.getOpcode()) {
    case MOS::PH:
    // PHA16/PLA16 (the A16 save/restore bracket expandLDSTStk puts around an
    // X16/Y16 soft-stack spill) move two bytes rather than one, but they are
    // always emitted as a matched pair inside a single frame-index expansion, so
    // counting them ±1 like PH/PL keeps this predicate exact: a range containing
    // both is balanced, a range containing exactly one is not.
    case MOS::PHA16:
      ++PushCount;
      break;
    case MOS::PL:
    case MOS::PLA16:
      if (!PushCount)
        return false;
      --PushCount;
      break;
    }
  }
  return !PushCount;
}

// Liveness immediately before Pos (i.e. into the instruction at Pos), computed
// by stepping a basic-block live-out set backward to Pos.
static void computeLiveBefore(MachineBasicBlock::iterator Pos,
                              LivePhysRegs &LPR) {
  MachineBasicBlock &MBB = *Pos->getParent();
  LPR.addLiveOuts(MBB);
  for (MachineBasicBlock::iterator J = std::prev(MBB.end()); J != Pos; --J)
    LPR.stepBackward(*J);
  LPR.stepBackward(*Pos);
}

// Find an 8-bit index register (X or Y) that is dead immediately before Pos, so
// it can serve as a transient courier to move the processor-status byte through
// the hard stack. X/Y are width-safe here: MOSInsertREPSEP runs after register
// scavenging (addPreEmitPass) and classifies any push/pull/load/store of an
// index register as XW_X8, so it will bracket these with sep/rep as needed even
// under +mos-xy16. Returns MOS::NoRegister if neither is free.
static Register findDeadIndexReg(MachineBasicBlock::iterator Pos) {
  const MachineFunction &MF = *Pos->getParent()->getParent();
  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  // Without accurate liveness (e.g. a MIR test without tracksRegLiveness) no
  // index register can be proven dead; the caller then has only the balanced
  // hard-stack path.
  if (!MF.getProperties().hasTracksLiveness())
    return MOS::NoRegister;
  LivePhysRegs LPR(TRI);
  computeLiveBefore(Pos, LPR);
  for (Register R : {MOS::X, MOS::Y})
    if (LPR.available(MRI, R.asMCReg()))
      return R;
  return MOS::NoRegister;
}

// Does no part of Reg hold an available value on entry to Pos? The scavenger
// borrows $c (a sub-register of $p) for a frame-index carry, which forces the
// whole $p to be preserved even where $p carries no live value; the resulting
// PHP then reads an undef $p, which the machine verifier rejects unless the
// operand is flagged undef.
//
// This must mirror the verifier's own notion of "defined" exactly, because that
// is the thing being satisfied. MachineVerifier tracks a FORWARD availability
// set (block live-ins, plus each def, minus each kill/dead operand) and accepts
// a use of a composite register when *any* of its sub-registers is in that set
// (`We are fine if just any subregister has a defined value`). So the predicate
// is "no sub-register of $p is available here", not "no def of $p appears
// above": $c may well be defined earlier in the block and then killed or
// dead-flagged before Pos, which leaves $p wholly undefined at Pos even though
// a reaching-definition scan finds a modifier. That is precisely the shape a
// 16-bit-accumulator ALU chain produces — every ADC in the chain defines $c,
// and the last one marks it dead.
//
// Note this is deliberately *not* a backward-liveness test: $p is "live" by
// backward dataflow at this very point (this PHP uses it), so LivePhysRegs
// stepped backward would never report it free. Forward availability is both the
// verifier-faithful and the semantically correct question here — if nothing
// above produced a flag value, the byte this PHP pushes is undefined, and the
// matching PLP restores an undefined byte that nothing reads.
//
// Erring is one-sided: reporting "available" when nothing is leaves the operand
// un-flagged (a verifier complaint, never a miscompile), whereas a spurious
// `undef` on a genuinely live $p would let the flag def move or die. Matching
// the verifier's set exactly keeps that asymmetry intact.
static bool hasNoAvailableValue(Register Reg, MachineBasicBlock::iterator Pos) {
  MachineBasicBlock &MBB = *Pos->getParent();
  const MachineFunction &MF = *MBB.getParent();
  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();
  const MachineRegisterInfo &MRI = MF.getRegInfo();

  // The verifier only checks physical-register liveness when the function
  // tracks it, and block live-ins cannot be read otherwise; leave the operand
  // unflagged in that case (the side that can never miscompile).
  if (!MF.getProperties().hasTracksLiveness())
    return false;

  LivePhysRegs LPR(TRI);
  LPR.addLiveIns(MBB);
  SmallVector<std::pair<MCPhysReg, const MachineOperand *>, 4> Clobbers;
  for (MachineBasicBlock::iterator J = MBB.begin(); J != Pos; ++J) {
    Clobbers.clear();
    LPR.stepForward(*J, Clobbers);
  }
  // available() is false when any alias (here: any sub-register) of Reg is
  // live, which is exactly the verifier's "any subregister has a defined
  // value" escape hatch.
  return LPR.available(MRI, Reg.asMCReg());
}

bool MOSRegisterInfo::saveScavengerRegister(MachineBasicBlock &MBB,
                                            MachineBasicBlock::iterator I,
                                            MachineBasicBlock::iterator &UseMI,
                                            const TargetRegisterClass *RC,
                                            Register Reg) const {

  // Consider the regions in a basic block where a physical register is live.
  // The register scavenger will select one of these regions to spill and mark
  // the physical register as available within that region. Such a region cannot
  // contain any calls, since the physical registers are clobbered by calls.
  // This means that a save/restore pair for that physical register cannot
  // overlap with any other save/restore pair for the same physical register.

  MachineIRBuilder Builder(MBB, I);
  const MOSSubtarget &STI = Builder.getMF().getSubtarget<MOSSubtarget>();

  switch (Reg) {
  default:
    errs() << "Register: " << getName(Reg) << "\n";
    report_fatal_error("Scavenger spill for register not yet implemented.");
  case MOS::A:
  case MOS::Y: {
    // A/Y restores transiently change N/Z. The scavenger preserves live
    // status through its interleaved P save and restore.

    // RS8 is reserved to save A and Y if necessary, but pushing is still
    // preferred.
    Register Save = Reg == MOS::A ? MOS::RC16 : MOS::RC17;
    bool UseHardStack =
        (Reg == MOS::A || STI.hasGPRStackRegs()) && pushPullBalanced(I, UseMI);

    if (UseHardStack)
      Builder.buildInstr(MOS::PH, {}, {Reg});
    else
      Builder.buildInstr(MOS::STImag8, {Save}, {Reg});

    Builder.setInsertPt(MBB, UseMI);

    if (UseHardStack)
      Builder.buildInstr(MOS::PL, {Reg}, {});
    else
      Builder.buildInstr(MOS::LDImag8, {Reg}, {Save});
    break;
  }
  case MOS::P: {
    // The processor-status flags can be live across a scavenge point under
    // 16-bit-accumulator codegen: a 16-bit compare/ALU keeps N (or Z) live
    // across a frame-index materialization whose carry the scavenger must place
    // in $c (a sub-register of $p), forcing the whole $p to be preserved. Unlike
    // A/Y (restored via LD/PL, which only transiently set N/Z), the P restore
    // must reproduce *all* of P exactly.
    //
    // The scavenger borrows $c (a sub-register of $p) for a frame-index carry,
    // which forces the whole $p to be preserved even where $p carries no live
    // value (the carry vreg is Pc-class). In that case the PHP reads an undef
    // $p, which the verifier rejects unless the operand is flagged undef.
    bool PUndef = hasNoAvailableValue(MOS::P, I);

    if (pushPullBalanced(I, UseMI)) {
      // Balanced hard-stack range: PHP / PLP round-trips P and all its flags.
      auto PHP = Builder.buildInstr(MOS::PH, {}, {Reg});
      if (PUndef)
        PHP.getInstr()->getOperand(0).setIsUndef();
      Builder.setInsertPt(MBB, UseMI);
      Builder.buildInstr(MOS::PL, {Reg}, {});
      break;
    }

    // Unbalanced range (net pushes between I and UseMI from frame spills): a
    // plain PLP would pop the wrong byte, and P has no GPR spill home
    // (STImag8/LDImag8 are GPR-only — storing $p is illegal MIR). Route P
    // hard-stack-*neutrally* through a dead 8-bit index register into the
    // reserved RC17 slot:
    //   save:    PHP ; PL<idx> ; ST<idx> RC17
    //   restore: LD<idx> RC17 ; PH<idx> ; PLP
    // Each half is push/pull-balanced (net 0), so it is independent of the
    // surrounding imbalance. The courier pull/load clobbers N/Z, but only
    // inside the borrowed region where the saved flags are not read; the final
    // PLP restores them. RC17 already is the scavenger's reserved P/Y slot.
    Register SaveIdx = findDeadIndexReg(I);
    Register RestoreIdx = findDeadIndexReg(UseMI);
    if (STI.hasGPRStackRegs() && SaveIdx && RestoreIdx) {
      Register Slot(MOS::RC17);
      auto PHP = Builder.buildInstr(MOS::PH, {}, {Reg});
      if (PUndef)
        PHP.getInstr()->getOperand(0).setIsUndef();
      Builder.buildInstr(MOS::PL, {SaveIdx}, {});
      Builder.buildInstr(MOS::STImag8, {Slot}, {SaveIdx});

      Builder.setInsertPt(MBB, UseMI);
      Builder.buildInstr(MOS::LDImag8, {RestoreIdx}, {Slot});
      Builder.buildInstr(MOS::PH, {}, {RestoreIdx});
      Builder.buildInstr(MOS::PL, {Reg}, {});
      break;
    }

    report_fatal_error("saveScavengerRegister: cannot preserve a live "
                       "processor-status register across an unbalanced stack "
                       "range with no free index register");
  }
  }
  return true;
}

bool MOSRegisterInfo::canSaveScavengerRegister(
    Register Reg, MachineBasicBlock::iterator I,
    MachineBasicBlock::iterator UseMI) const {
  const MOSSubtarget &STI = I->getMF()->getSubtarget<MOSSubtarget>();

  // Easy cases
  switch (Reg) {
  case MOS::X:
    return false;
  case MOS::P:
    // P is saveable on a balanced hard-stack range (PHP/PLP), or — when the
    // range is unbalanced — by routing it through a dead index register into
    // RC17 (see saveScavengerRegister), which needs PHX/PHY and a free index
    // register at both the save and restore points.
    return pushPullBalanced(I, UseMI) ||
           (STI.hasGPRStackRegs() && findDeadIndexReg(I) &&
            findDeadIndexReg(UseMI));
  default:
    break;
  }

  bool UseHardStack =
      (Reg == MOS::A || STI.hasGPRStackRegs()) && pushPullBalanced(I, UseMI);
  if (UseHardStack)
    return true;

  // Because the scavenger may run more than once, the reserved register may
  // already be in use. In such cases, it's not safe to save it, and a
  // different register must be used.
  Register Save = Reg == MOS::A ? MOS::RC16 : MOS::RC17;
  LivePhysRegs LPR(*STI.getRegisterInfo());
  LPR.addLiveOuts(*I->getParent());
  for (MachineBasicBlock::iterator J = std::prev(I->getParent()->end()); J != I;
       --J) {
    LPR.stepBackward(*J);
    if (J == UseMI && LPR.contains(Save))
      return false;
  }
  LPR.stepBackward(*I);
  return !LPR.contains(Save);
}

bool MOSRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                          int SPAdj, unsigned FIOperandNum,
                                          RegScavenger *RS) const {
  MachineFunction &MF = *MI->getMF();
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  const auto &MOSFI = MF.getInfo<MOSFunctionInfo>();

  assert(!SPAdj);

  int Idx = MI->getOperand(FIOperandNum).getIndex();
  int64_t Offset = MFI.getObjectOffset(Idx);
  // Where the frame-index displacement lives depends on the instruction format,
  // so key off the opcode rather than guessing "the operand after the frame
  // index is its displacement immediate". That guess misfires for CmpBrAbsImm16
  // (#321), whose operand after the frame-index address is the COMPARE immediate
  // (not a displacement) — adding it would corrupt the resolved stack address.
  switch (MI->getOpcode()) {
  case MOS::AddrLostk:
  case MOS::AddrHistk:
  case MOS::LDStk:
  case MOS::STStk:
    // These carry the displacement in a separate immediate operand after the FI.
    Offset += MI->getOperand(FIOperandNum + 1).getImm();
    break;
  default:
    // Every other (abs / GA-style) instruction — incl. all CmpBrAbs* — carries
    // the displacement in the frame-index operand's own offset field.
    Offset += MI->getOperand(FIOperandNum).getOffset();
    break;
  }

  if (MFI.getStackID(Idx) == TargetStackID::Default) {
    // All offsets are relative to the incoming SP
    // 1) Addr = Offset_SP + SP
    //
    // However, the incoming SP isn't available throughout the function; only
    // the frame pointer is. So we need to obtain the FP relative offset such
    // that:
    // 2) Addr = Offset_FP + FP
    //
    // Susbtituting (2) into (1) gives:
    // 3) Offset_FP = Offset_SP + SP - FP
    //
    // The frame pointer is:
    // 4) FP = SP - Stack_Size
    //
    // Substituting (4) into (3) gives:
    // 5) Offset_FP = Offset_SP + Stack_Size
    Offset += MFI.getStackSize();
  }

  switch (MI->getOpcode()) {
  default:
    if (MFI.getStackID(Idx) == TargetStackID::MosZeroPage) {
      MI->getOperand(FIOperandNum)
          .ChangeToGA(MOSFI->ZeroPageStackValue, Offset,
                      MI->getOperand(FIOperandNum).getTargetFlags());
    } else {
      assert(MFI.getStackID(Idx) == TargetStackID::MosStatic);
      MI->getOperand(FIOperandNum)
          .ChangeToTargetIndex(MOS::TI_STATIC_STACK, Offset,
                               MI->getOperand(FIOperandNum).getTargetFlags());
    }
    break;
  case MOS::AddrLostk:
  case MOS::AddrHistk:
  case MOS::LDStk:
  case MOS::STStk: {
    // During frame setup or teardown, FP is not valid, so SP instead plays the
    // role of the frame pointer.
    Register FP = (MI->getFlags() &
                   (MachineInstr::FrameSetup | MachineInstr::FrameDestroy))
                      ? MOS::RS0
                      : getFrameRegister(MF);
    MI->getOperand(FIOperandNum).ChangeToRegister(FP, /*isDef=*/false);
    MI->getOperand(FIOperandNum + 1).setImm(Offset);
    break;
  }
  }

  switch (MI->getOpcode()) {
  default:
    return false;
  case MOS::AddrLostk:
    expandAddrLostk(MI);
    break;
  case MOS::AddrHistk:
    expandAddrHistk(MI);
    break;
  case MOS::LDStk:
  case MOS::STStk:
    expandLDSTStk(MI);
    break;
  }
  return true;
}

void MOSRegisterInfo::expandAddrLostk(MachineBasicBlock::iterator MI) const {
  MachineIRBuilder Builder(*MI);
  const TargetRegisterInfo &TRI =
      *Builder.getMF().getSubtarget().getRegisterInfo();

  const MachineOperand &Dst = MI->getOperand(0);
  Register Base = MI->getOperand(3).getReg();
  const MachineOperand &CDef = MI->getOperand(1);
  const MachineOperand &VDef = MI->getOperand(2);

  int64_t OffsetImm = MI->getOperand(4).getImm();
  assert(0 <= OffsetImm && OffsetImm < 65536);
  auto Offset = static_cast<uint16_t>(OffsetImm);
  Offset &= 0xFF;

  Register Src = TRI.getSubReg(Base, MOS::sublo);

  auto LDC = Builder.buildInstr(MOS::LDCImm).add(CDef).addImm(0);
  if (LDC->getOperand(0).getSubReg())
    LDC->getOperand(0).setIsUndef();

  if (!Offset)
    Builder.buildInstr(MOS::COPY).add(Dst).addUse(Src);
  else {
    Register A = Builder.buildCopy(&MOS::AcRegClass, Src).getReg(0);
    auto Instr = Builder.buildInstr(MOS::ADCImm)
                     .addDef(A)
                     .add(CDef)
                     .add(VDef)
                     .addUse(A)
                     .addImm(Offset)
                     .addUse(CDef.getReg(), RegState{}, CDef.getSubReg());
    Instr->getOperand(2).setIsDead();
    Builder.buildInstr(MOS::COPY).add(Dst).addUse(A);
  }

  MI->eraseFromParent();
}

void MOSRegisterInfo::expandAddrHistk(MachineBasicBlock::iterator MI) const {
  MachineIRBuilder Builder(*MI);
  const TargetRegisterInfo &TRI =
      *Builder.getMF().getSubtarget().getRegisterInfo();

  MachineOperand Dst = MI->getOperand(0);
  MachineOperand CDef = MI->getOperand(1);
  MachineOperand VDef = MI->getOperand(2);
  Register Base = MI->getOperand(3).getReg();

  int64_t OffsetImm = MI->getOperand(4).getImm();
  assert(0 <= OffsetImm && OffsetImm < 65536);
  auto Offset = static_cast<uint16_t>(OffsetImm);

  MachineOperand CUse = MI->getOperand(5);

  Register Src = TRI.getSubReg(Base, MOS::subhi);

  // Note: We can only elide the high byte of the address into a copy if the
  // whole offset is zero. There may be a carry from the low byte sum if only
  // the high byte is zero.
  if (!Offset)
    Builder.buildInstr(MOS::COPY).add(Dst).addUse(Src);
  else {
    Register A = Builder.buildCopy(&MOS::AcRegClass, Src).getReg(0);
    auto Instr = Builder.buildInstr(MOS::ADCImm)
                     .addDef(A)
                     .add(CDef)
                     .add(VDef)
                     .addUse(A)
                     .addImm(Offset >> 8)
                     .add(CUse);
    Instr->getOperand(1).setIsDead();
    Instr->getOperand(2).setIsDead();
    Builder.buildInstr(MOS::COPY).add(Dst).addUse(A);
  }

  MI->eraseFromParent();
}

// Native indices: does A16 (or either of its bytes, $a / $b) carry a value that is
// live across Pos? Pos is an LDStk/STStk, which never names A16 in an operand,
// so liveness immediately before it equals liveness immediately after it —
// exactly the "is something depending on the accumulator across this spill"
// question expandLDSTStk needs to answer.
//
// LivePhysRegs::available() is alias-aware, so a live 8-bit $a answers yes too.
// That is deliberate, not over-approximation: the staging sequence below is
// `lda (zp)` / `tax` (or `txa` / `sta (zp)`), which destroys $a just as
// thoroughly as it destroys $a16.
//
// Erring is one-sided by construction. A spurious "live" costs one `pha`/`pla`
// pair (2 bytes, 7 cycles) and is always semantically harmless; a missed "live"
// is a miscompile. The estimate can only err toward "live": the scan runs during
// PEI's forward walk over the block, so any LDStk/STStk *below* Pos is still an
// unexpanded pseudo that names no accumulator — it can therefore only fail to
// report a kill of A16, never invent a use of it.
static bool accumulatorLiveAcross(MachineBasicBlock::iterator Pos) {
  const MachineFunction &MF = *Pos->getParent()->getParent();
  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  LivePhysRegs LPR(TRI);
  computeLiveBefore(Pos, LPR);
  return !LPR.available(MRI, Register(MOS::A16).asMCReg());
}

// The spill wrapper saves live A16 around index-register spills. Recursive
// Imag16 byte splits use the same wrapper so every operation observes the
// accumulator preservation contract.
void MOSRegisterInfo::expandLDSTStk(MachineBasicBlock::iterator MI) const {
  const bool IsLoad = MI->getOpcode() == MOS::LDStk;
  Register Loc =
      IsLoad ? MI->getOperand(0).getReg() : MI->getOperand(1).getReg();
  const bool StagesThroughA16 =
      MOS::Xc16RegClass.contains(Loc) || MOS::Yc16RegClass.contains(Loc);

  if (!StagesThroughA16 || !accumulatorLiveAcross(MI)) {
    expandLDSTStkImpl(MI);
    return;
  }

  MachineBasicBlock &MBB = *MI->getParent();
  // Captured before the expansion, which inserts ahead of MI and then erases it;
  // Next therefore still marks the point just past everything it emitted.
  MachineBasicBlock::iterator Next = std::next(MI);
  MachineIRBuilder Builder(MBB, MI);
  Builder.buildInstr(MOS::PHA16).addUse(MOS::A16);
  expandLDSTStkImpl(MI);
  Builder.setInsertPt(MBB, Next);
  Builder.buildInstr(MOS::PLA16).addDef(MOS::A16);
}

void MOSRegisterInfo::expandLDSTStkImpl(MachineBasicBlock::iterator MI) const {
  MachineFunction &MF = *MI->getMF();
  MachineIRBuilder Builder(*MI);
  MachineRegisterInfo &MRI = *Builder.getMRI();
  const TargetRegisterInfo &TRI = *MRI.getTargetRegisterInfo();

  const bool IsLoad = MI->getOpcode() == MOS::LDStk;

  Register Loc =
      IsLoad ? MI->getOperand(0).getReg() : MI->getOperand(1).getReg();
  int64_t Offset = MI->getOperand(3).getImm();

  // Spill Ac16 with a word access. Imag16 values split into two byte
  // registers, but the hidden high accumulator byte has no byte GPR copy.
  const bool IsAc16 = MOS::Ac16RegClass.contains(Loc);
  // Native indices: X16/Y16 spilled via TXA16/STAIndir16 or LDAIndir16/TAX16 (same
  // indirect-only constraint as Ac16 — the (zp)-indirect ops have no index).
  const bool IsXc16 = MOS::Xc16RegClass.contains(Loc);
  const bool IsYc16 = MOS::Yc16RegClass.contains(Loc);

  // Form an exact slot pointer in the reserved scratch when the access can't use a
  // base+index addressing mode: a far offset (>= 256), OR a 16-bit spill at a nonzero
  // offset (STAIndir16/LDAIndir16 and their X/Y variants are (zp)-indirect with no
  // index). After this the pointer is in operand 2 and the offset is 0, so re-entry
  // lands in the offset-0 paths below.
  if (Offset >= 256 || ((IsAc16 || IsXc16 || IsYc16) && Offset != 0)) {
    Register P = MRI.createVirtualRegister(&MOS::PcRegClass);
    // These accesses need a concrete base pointer, so materialize one here using
    // the pointer provided (the earlyclobber scratch operand).
    Register NewBase =
        IsLoad ? MI->getOperand(1).getReg() : MI->getOperand(0).getReg();
    // We can't scavenge a 16-bit register, so this can't be virtual here
    // (after register allocation).
    assert(!NewBase.isVirtual() && "LDSTStk must not use a virtual base "
                                   "pointer after register allocation.");

    auto Lo = Builder.buildInstr(MOS::AddrLostk)
                  .addDef(TRI.getSubReg(NewBase, MOS::sublo))
                  .addDef(P, RegState{}, MOS::subcarry)
                  .addDef(P, RegState::Dead, MOS::subv)
                  .add(MI->getOperand(2))
                  .add(MI->getOperand(3));
    auto Hi = Builder.buildInstr(MOS::AddrHistk)
                  .addDef(TRI.getSubReg(NewBase, MOS::subhi))
                  .addDef(P, RegState::Dead, MOS::subcarry)
                  .addDef(P, RegState::Dead, MOS::subv)
                  .add(MI->getOperand(2))
                  .add(MI->getOperand(3))
                  .addUse(P, RegState{}, MOS::subcarry)
                  .addUse(NewBase, RegState::Implicit);
    MI->getOperand(2).setReg(NewBase);
    MI->getOperand(3).setImm(0);

    expandAddrLostk(Lo);
    expandAddrHistk(Hi);
    // Straight to the impl: the wrapper already decided (and, if needed,
    // emitted) the A16 bracket for this very instruction, above the AddrLostk
    // chain we just emitted.
    expandLDSTStkImpl(MI);
    return;
  }

  // Native widths: Ac16 spill/reload at offset 0 — operand 2 is now the exact slot pointer
  // (the frame register for a near offset-0 access, or the scratch pointer the block
  // above formed). One 16-bit indirect store/load of A16 through it; the MLow=1 op is
  // rep/sep-bracketed by the later MOSInsertREPSEP pass.
  if (IsAc16) {
    assert(Offset == 0 && "Ac16 nonzero offset should have formed a pointer above");
    Builder.buildInstr(IsLoad ? MOS::LDAIndir16 : MOS::STAIndir16)
        .addReg(Loc, getDefRegState(IsLoad))
        .add(MI->getOperand(2))
        .addMemOperand(*MI->memoperands_begin());
    MI->eraseFromParent();
    return;
  }

  // Native indices: X16/Y16 spill/reload at offset 0, via A16 as a staging register.
  // Store: TXA16 (X16→A16) → STAIndir16 [ptr].
  // Load:  LDAIndir16 [ptr] → TAX16 (A16→X16).
  // Both the XLow=1 and MLow=1 brackets are inserted by MOSInsertREPSEP.
  // A16 is CLOBBERED here and no operand says so, which is why expandLDSTStk (the
  // wrapper) brackets this whole expansion with PHA16/PLA16 whenever the
  // accumulator is live across the spill — see the comment on it.
  if (IsXc16) {
    assert(Offset == 0 && "Xc16 nonzero offset should have formed a pointer above");
    if (!IsLoad) {
      Builder.buildInstr(MOS::TXA16)
          .addReg(MOS::A16, RegState::Define)
          .addReg(MOS::X16);
      Builder.buildInstr(MOS::STAIndir16)
          .addReg(MOS::A16, RegState::Kill)
          .add(MI->getOperand(2))
          .addMemOperand(*MI->memoperands_begin());
    } else {
      Builder.buildInstr(MOS::LDAIndir16)
          .addReg(MOS::A16, RegState::Define)
          .add(MI->getOperand(2))
          .addMemOperand(*MI->memoperands_begin());
      Builder.buildInstr(MOS::TAX16)
          .addReg(MOS::X16, RegState::Define)
          .addReg(MOS::A16, RegState::Kill);
    }
    MI->eraseFromParent();
    return;
  }
  if (IsYc16) {
    assert(Offset == 0 && "Yc16 nonzero offset should have formed a pointer above");
    if (!IsLoad) {
      Builder.buildInstr(MOS::TYA16)
          .addReg(MOS::A16, RegState::Define)
          .addReg(MOS::Y16);
      Builder.buildInstr(MOS::STAIndir16)
          .addReg(MOS::A16, RegState::Kill)
          .add(MI->getOperand(2))
          .addMemOperand(*MI->memoperands_begin());
    } else {
      Builder.buildInstr(MOS::LDAIndir16)
          .addReg(MOS::A16, RegState::Define)
          .add(MI->getOperand(2))
          .addMemOperand(*MI->memoperands_begin());
      Builder.buildInstr(MOS::TAY16)
          .addReg(MOS::Y16, RegState::Define)
          .addReg(MOS::A16, RegState::Kill);
    }
    MI->eraseFromParent();
    return;
  }

  if (MOS::Imag16RegClass.contains(Loc)) {
    if (!IsLoad) {
      // Loc may not be fully alive at this point, which would create uses of
      // undefined subregisters. Issuing a KILL here redefines the full 16-bit
      // register, making both halves alive, regardless of which parts of the
      // register were alive before.
      Builder.buildInstr(MOS::KILL, {Loc}, {Loc});
    }
    Register Lo = TRI.getSubReg(Loc, MOS::sublo);
    Register Hi = TRI.getSubReg(Loc, MOS::subhi);
    auto LoInstr = Builder.buildInstr(MI->getOpcode());
    if (!IsLoad)
      LoInstr.add(MI->getOperand(0));
    LoInstr.addReg(Lo, getDefRegState(IsLoad));
    if (IsLoad)
      LoInstr.add(MI->getOperand(1));
    LoInstr.add(MI->getOperand(2))
        .add(MI->getOperand(3))
        .addMemOperand(MF.getMachineMemOperand(*MI->memoperands_begin(), 0, 1));
    auto HiInstr = Builder.buildInstr(MI->getOpcode());
    if (!IsLoad)
      HiInstr.add(MI->getOperand(0));
    HiInstr.addReg(Hi, getDefRegState(IsLoad));
    if (IsLoad)
      HiInstr.add(MI->getOperand(1));
    HiInstr.add(MI->getOperand(2))
        .addImm(MI->getOperand(3).getImm() + 1)
        .addMemOperand(MF.getMachineMemOperand(*MI->memoperands_begin(), 1, 1));
    MI->eraseFromParent();
    expandLDSTStk(LoInstr);
    expandLDSTStk(HiInstr);
    return;
  }

  Register Loc8 =
      TRI.getMatchingSuperReg(Loc, MOS::sublsb, &MOS::Anyi8RegClass);
  if (Loc8)
    Loc = Loc8;

  // Every spillable register class wider than eight bits has an explicit
  // word-width path above. Only flags and byte registers reach this tail.
  assert(Loc == MOS::C || Loc == MOS::V || MOS::Anyi8RegClass.contains(Loc));

  Register A = Loc;
  if (A != MOS::A)
    A = MRI.createVirtualRegister(&MOS::AcRegClass);

  // Transfer the value to A to be stored (if applicable).
  if (!IsLoad && Loc != A) {
    if (Loc == MOS::C || Loc == MOS::V)
      Builder.buildInstr(MOS::COPY)
          .addDef(A, RegState::Undef, MOS::sublsb)
          .addUse(Loc);
    else {
      assert(MOS::Anyi8RegClass.contains(Loc));
      Builder.buildCopy(A, Loc);
    }
  }

  // This needs to occur after the above copy since the source may be Y.
  Register Y =
      Builder.buildInstr(MOS::LDImm, {&MOS::YcRegClass}, {Offset}).getReg(0);

  Builder.buildInstr(IsLoad ? MOS::LDIndirIdx : MOS::STIndirIdx)
      .addReg(A, getDefRegState(IsLoad))
      .add(MI->getOperand(2))
      .addUse(Y)
      .addMemOperand(*MI->memoperands_begin());

  // Transfer the loaded value out of A (if applicable).
  if (IsLoad && Loc != A) {
    if (Loc == MOS::C || Loc == MOS::V)
      Builder.buildInstr(MOS::COPY, {Loc}, {}).addUse(A, RegState{}, MOS::sublsb);
    else {
      assert(MOS::Anyi8RegClass.contains(Loc));
      Builder.buildCopy(Loc, A);
    }
  }

  MI->eraseFromParent();
  return;
}

Register MOSRegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  const TargetFrameLowering *TFI = getFrameLowering(MF);
  return TFI->hasFP(MF) ? MOS::RS15 : MOS::RS0;
}

bool referencedByShiftRotate(Register Reg, const MachineRegisterInfo &MRI) {
  for (MachineInstr &MI : MRI.reg_nodbg_instructions(Reg)) {
    switch (MI.getOpcode()) {
    default:
      break;
    case MOS::ASL:
    case MOS::LSR:
    case MOS::ROL:
    case MOS::ROR:
      return true;
    }
  }
  return false;
}

bool referencedByIncDec(Register Reg, const MachineRegisterInfo &MRI) {
  for (MachineInstr &MI : MRI.reg_nodbg_instructions(Reg)) {
    switch (MI.getOpcode()) {
    default:
      break;
    case MOS::INC:
    case MOS::DEC:
    case MOS::IncNMOS:
    case MOS::DecNMOS:
    case MOS::IncMB:
    case MOS::DecMB:
    case MOS::DecDcpMB:
      return true;
    }
  }
  return false;
}

bool referencedByIncDecMB(Register Reg, const MachineRegisterInfo &MRI) {
  for (MachineInstr &MI : MRI.reg_nodbg_instructions(Reg)) {
    switch (MI.getOpcode()) {
    default:
      break;
    case MOS::IncMB:
    case MOS::DecMB:
    case MOS::DecDcpMB:
      return true;
    }
  }
  return false;
}

// Returns whether there's exactly one RMW operation, and all of the other
// references are to the poorer regclass. In that case, it's better to do the
// operation in the poorer regclass then to copy into a better one then copy
// back out.
bool isRmwPattern(Register Reg, const MachineRegisterInfo &MRI) {
  SmallVector<const MachineInstr *> RMW;
  const MachineInstr *Rmw = nullptr;
  for (MachineInstr &MI : MRI.reg_nodbg_instructions(Reg)) {
    switch (MI.getOpcode()) {
    default:
      break;
    case MOS::ASL:
    case MOS::LSR:
    case MOS::ROL:
    case MOS::ROR:
    case MOS::IncMB:
    case MOS::DecMB:
    case MOS::DecDcpMB:
      if (Rmw && Rmw != &MI)
        return false;
      Rmw = &MI;
      continue;
    }

    if (!MI.isCopy())
      return false;

    Register Dst = MI.getOperand(0).getReg();
    Register Src = MI.getOperand(1).getReg();

    Register Other = Reg == Dst ? Src : Dst;
    assert(Other != Reg);

    if (Other.isPhysical()) {
      if (!MOS::Imag8RegClass.contains(Other))
        return false;
      continue;
    }

    const auto *OtherRC = MRI.getRegClass(Other);
    if (OtherRC != &MOS::Imag8RegClass && OtherRC != &MOS::Imag16RegClass)
      return false;
  }
  assert(Rmw);
  return true;
}

// True if the virtual register Reg's unique definition is a COPY *directly* out of a
// physical imaginary register ($rcN) — `Reg = COPY $rcN` — and Reg is live across a
// call that clobbers that same $rcN.
//
// $rcN are the calling convention's imaginary (zero-page) argument/return scratch: a
// libcall passes and returns values in them and clobbers them (via the call's
// regmask). A `Reg = COPY $rcN` reading such a return value hints Reg back to $rcN.
// If Reg is then folded into an imaginary-register *pair* (a sub-register copy
// building an Imag16) that outlives a libcall re-clobbering $rcN, the pair inherits
// the $rcN hint and the allocator re-binds it to $rcN across the clobber — leaving a
// use of $rcN with no reaching definition on that path. The value survives in $rcN at
// runtime so the code is correct, but the IR is ill-formed and the MachineVerifier
// rejects it ("Using an undefined physical register") — a latent miscompile hazard.
static bool copiedFromClobberedPhysImag(Register Reg,
                                        const MachineRegisterInfo &MRI,
                                        LiveIntervals &LIS) {
  if (!Reg.isVirtual() || !LIS.hasInterval(Reg))
    return false;
  const MachineInstr *Def = MRI.getUniqueVRegDef(Reg);
  if (!Def || !Def->isCopy())
    return false;
  Register Src = Def->getOperand(1).getReg();
  if (!Src.isPhysical() || !MOS::Imag8RegClass.contains(Src))
    return false;
  BitVector Usable;
  return LIS.checkRegMaskInterference(LIS.getInterval(Reg), Usable) &&
         !Usable.test(Src.id());
}

bool MOSRegisterInfo::shouldCoalesce(
    MachineInstr *MI, const TargetRegisterClass *SrcRC, unsigned SubReg,
    const TargetRegisterClass *DstRC, unsigned DstSubReg,
    const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
  const auto &MRI = MI->getMF()->getRegInfo();

  // Don't fold a value read straight out of a call-clobbered imaginary register
  // ($rcN, via `vreg = COPY $rcN`) into an imaginary-register *pair* (a sub-register
  // copy that builds an Imag16) when that value outlives the clobbering call. The
  // pair inherits the physical-$rcN allocation hint and the allocator re-binds it to
  // $rcN across the clobber, producing a disconnected def->use the MachineVerifier
  // rejects ("Using an undefined physical register") — a latent miscompile hazard.
  // Refusing keeps the COPY so the value gets its own spillable vreg.
  //
  // Narrowly gated to stay inert on the common case: it requires (1) a *direct*
  // `vreg = COPY $rcN` read (unique def), (2) that vreg genuinely live across a call
  // clobbering $rcN, and (3) a sub-register copy into an Imag16 pair — the exact shape
  // that re-creates the re-bindable hint. It only ever keeps an extra COPY, never
  // changing correctness. Pure virtual values without a physical-register COPY
  // do not satisfy this guard; their call-clobber constraints belong to allocation.
  if (NewRC == &MOS::Imag16RegClass && (DstSubReg || SubReg)) {
    if (copiedFromClobberedPhysImag(MI->getOperand(0).getReg(), MRI, LIS) ||
        copiedFromClobberedPhysImag(MI->getOperand(1).getReg(), MRI, LIS))
      return false;
  }

  // Don't coalesce Imag8 and AImag8 registers together when used by shifts or
  // rotates.  This may cause expensive ASL zp's to be used when ASL A would
  // have sufficed. It's better to do arithmetic in A and then copy it out.
  // Same concerns apply to INC and DEC.
  if (NewRC == &MOS::Imag8RegClass || NewRC == &MOS::Imag16RegClass) {
    if (DstRC == &MOS::AImag8RegClass &&
        referencedByShiftRotate(MI->getOperand(0).getReg(), MRI) &&
        !isRmwPattern(MI->getOperand(0).getReg(), MRI))
      return false;
    if (SrcRC == &MOS::AImag8RegClass &&
        referencedByShiftRotate(MI->getOperand(1).getReg(), MRI) &&
        !isRmwPattern(MI->getOperand(1).getReg(), MRI))
      return false;
    if (DstRC == &MOS::Anyi8RegClass &&
        referencedByIncDec(MI->getOperand(0).getReg(), MRI) &&
        !isRmwPattern(MI->getOperand(0).getReg(), MRI))
      return false;
    if (SrcRC == &MOS::Anyi8RegClass &&
        referencedByIncDec(MI->getOperand(1).getReg(), MRI) &&
        !isRmwPattern(MI->getOperand(1).getReg(), MRI))
      return false;
  }
  // Don't coalesce GPR and Anyi8 registers together when used by IncMB and
  // DecMB; this can make them impossible to allocate.
  if (NewRC == &MOS::GPRRegClass) {
    if (DstRC == &MOS::Anyi8RegClass &&
        referencedByIncDecMB(MI->getOperand(0).getReg(), MRI))
      return false;
    if (SrcRC == &MOS::Anyi8RegClass &&
        referencedByIncDecMB(MI->getOperand(1).getReg(), MRI))
      return false;
  }
  return true;
}

bool MOSRegisterInfo::getRegAllocationHints(Register VirtReg,
                                            ArrayRef<MCPhysReg> Order,
                                            SmallVectorImpl<MCPhysReg> &Hints,
                                            const MachineFunction &MF,
                                            const VirtRegMap *VRM,
                                            const LiveRegMatrix *Matrix) const {
  const MOSSubtarget &STI = MF.getSubtarget<MOSSubtarget>();
  const auto &TRI = *STI.getRegisterInfo();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  DenseMap<Register, MOSInstrCost> RegScores;
  auto CostMode = MOSInstrCost::getModeFor(MF);

  DenseMap<Register, int> OriginalIndex;
  for (const auto &R : enumerate(Order))
    OriginalIndex[R.value()] = R.index();

  if (std::optional<Register> StrongHint =
          getStrongCopyHint(VirtReg, MF, VRM)) {
    if (*StrongHint)
      Hints.push_back(*StrongHint);
    return true;
  }

  MOSInstrCost INCzp = MOSInstrCost(2, 5);
  MOSInstrCost INCxy = MOSInstrCost(1, 2);
  MOSInstrCost ASLzp = MOSInstrCost(2, 5);
  MOSInstrCost ASLa = MOSInstrCost(1, 2);
  if (STI.hasHUC6280()) {
    INCzp = MOSInstrCost(2, 6);
    ASLzp = MOSInstrCost(2, 6);
  }
  if (STI.has65CE02() || STI.hasSPC700()) {
    INCzp = MOSInstrCost(2, 4);
    ASLzp = MOSInstrCost(2, 4);
  }
  if (STI.has65CE02()) {
    INCxy = MOSInstrCost(1, 1);
    ASLa = MOSInstrCost(1, 1);
  }

  SmallSet<const MachineInstr *, 32> Visited;
  for (MachineInstr &MI : MRI.reg_nodbg_instructions(VirtReg)) {
    if (!Visited.insert(&MI).second)
      continue;
    switch (MI.getOpcode()) {
    default:
      continue;
    case MOS::COPY: {
      const MachineOperand &Self = MI.getOperand(0).getReg() == VirtReg
                                       ? MI.getOperand(0)
                                       : MI.getOperand(1);
      const MachineOperand &Other = MI.getOperand(0).getReg() == VirtReg
                                        ? MI.getOperand(1)
                                        : MI.getOperand(0);
      Register OtherReg = Other.getReg();
      if (OtherReg.isVirtual()) {
        if (!VRM->hasPhys(OtherReg))
          break;
        OtherReg = VRM->getPhys(OtherReg);
      }
      if (Other.getSubReg())
        OtherReg = TRI.getSubReg(OtherReg, Other.getSubReg());
      // the Imag32 (p2) decompose creates sub-register copies
      // whose hint candidate can differ in size from the other operand. copyCost
      // only costs a same-size copy, so skip invalid/mismatched-size pairs (not a
      // real copy to hint). Same-size pairs (all pre-far code) are unaffected.
      const auto &SizeMismatch = [&](Register SelfReg) {
        return !SelfReg || !OtherReg ||
               TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(SelfReg)) !=
                   TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(OtherReg));
      };
      MOSInstrCost WorstCost;
      for (Register R : Order) {
        Register SelfReg = R;
        if (Self.getSubReg())
          SelfReg = TRI.getSubReg(SelfReg, Self.getSubReg());
        if (SizeMismatch(SelfReg))
          continue;
        MOSInstrCost Cost = copyCost(SelfReg, OtherReg, STI);
        if (Cost.value(CostMode) > WorstCost.value(CostMode))
          WorstCost = Cost;
      }
      for (Register R : Order) {
        Register SelfReg = R;
        if (Self.getSubReg())
          SelfReg = TRI.getSubReg(SelfReg, Self.getSubReg());
        if (SizeMismatch(SelfReg))
          continue;
        MOSInstrCost Cost = copyCost(SelfReg, OtherReg, STI);
        if (Cost.value(CostMode) < WorstCost.value(CostMode))
          RegScores[R] += (WorstCost - Cost);
      }
      break;
    }
    case MOS::ASL:
    case MOS::LSR:
    case MOS::ROR:
    case MOS::ROL:
      if (is_contained(Order, MOS::A))
        RegScores[MOS::A] += ASLzp - ASLa;
      break;

    case MOS::CmpBrZero: {
      // Branch costs are uniform; factor them out.
      // CmpZero GPR best case: 0 (TAX)
      // CmpZero GPR worst case: 4 (CMP #0)
      // Splitting the difference: 2
      MOSInstrCost CmpZeroGPR = MOSInstrCost(2, 2) / 2;
      // CmpZero ZP best case: 0 (elided)
      // CmpZero ZP worst case: 14 (INC DEC)
      // Splitting the difference: 7
      MOSInstrCost CmpZeroZP = INCzp * 2 / 2;
      if (is_contained(Order, MOS::A))
        RegScores[MOS::A] += CmpZeroZP - CmpZeroGPR;
      if (is_contained(Order, MOS::X))
        RegScores[MOS::X] += CmpZeroZP - CmpZeroGPR;
      if (is_contained(Order, MOS::Y))
        RegScores[MOS::Y] += CmpZeroZP - CmpZeroGPR;
      break;
    }

    case MOS::INC:
    case MOS::DEC:
    case MOS::IncNMOS:
    case MOS::DecNMOS:
    case MOS::IncMB:
    case MOS::DecMB:
    case MOS::DecDcpMB: {
      // The first operand to DecMB is scratch.
      if ((MI.getOpcode() == MOS::DecMB || MI.getOpcode() == MOS::DecDcpMB) &&
          MI.getOperand(0).getReg() == VirtReg)
        break;

      if (STI.hasGPRIncDec() && is_contained(Order, MOS::A))
        RegScores[MOS::A] += INCzp - INCxy;
      if (is_contained(Order, MOS::X))
        RegScores[MOS::X] += INCzp - INCxy;
      if (is_contained(Order, MOS::Y))
        RegScores[MOS::Y] += INCzp - INCxy;

      // Prefer placing adjacent IncMB/DecMB bytes into consecutive Imag8
      // pairs so post-RA expansion can emit INW/DEW word operations.
      if (STI.has65CE02() && VRM &&
          (MI.getOpcode() == MOS::IncMB || MI.getOpcode() == MOS::DecMB ||
           MI.getOpcode() == MOS::DecDcpMB)) {
        unsigned NumDefs = MI.getNumExplicitDefs();
        for (unsigned I = NumDefs, E = MI.getNumExplicitOperands(); I < E;
             ++I) {
          if (!MI.getOperand(I).isReg() ||
              MI.getOperand(I).getReg() != VirtReg)
            continue;
          unsigned ByteIdx = I - NumDefs;
          unsigned PartnerI = NumDefs + (ByteIdx ^ 1);
          if (PartnerI >= E || !MI.getOperand(PartnerI).isReg())
            break;
          Register PartnerVReg = MI.getOperand(PartnerI).getReg();
          if (!PartnerVReg.isVirtual() || !VRM->hasPhys(PartnerVReg))
            break;
          MCPhysReg PartnerPhys = VRM->getPhys(PartnerVReg);
          if (!MOS::Imag8RegClass.contains(PartnerPhys))
            break;
          bool IsLo = (ByteIdx % 2 == 0);
          MCRegister Super = TRI.getMatchingSuperReg(
              PartnerPhys, IsLo ? MOS::subhi : MOS::sublo,
              &MOS::Imag16RegClass);
          if (!Super)
            break;
          MCPhysReg HintReg =
              TRI.getSubReg(Super, IsLo ? MOS::sublo : MOS::subhi);
          if (HintReg && is_contained(Order, HintReg))
            Hints.push_back(HintReg);
          break;
        }
      }
      break;
    }
    }
  }

  SmallVector<std::pair<Register, MOSInstrCost>> RegsAndScores(
      RegScores.begin(), RegScores.end());
  sort(RegsAndScores, [&](const std::pair<Register, MOSInstrCost> &A,
                          const std::pair<Register, MOSInstrCost> &B) {
    auto AVal = A.second.value(CostMode);
    auto BVal = B.second.value(CostMode);
    if (AVal > BVal)
      return true;
    if (AVal < BVal)
      return false;
    return OriginalIndex[A.first] < OriginalIndex[B.first];
  });
  append_range(Hints, make_first_range(RegsAndScores));
  return false;
}

// If the VirtReg is rematerializable, and the only uses of VirtReg
// are copies with exactly one register, returns a hint containing that
// register. If there are more than one such register, returns Some(0).
// Otherwise, returns None. This prevents the register allocator from
// assigning a value to a useless register; it's always better to split or
// spill in such cases, since absolutely nothing can use the value in that
// register.
std::optional<Register>
MOSRegisterInfo::getStrongCopyHint(Register VirtReg, const MachineFunction &MF,
                                   const VirtRegMap *VRM) const {
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  const MOSSubtarget &STI = MF.getSubtarget<MOSSubtarget>();
  const auto &TRI = *STI.getRegisterInfo();
  const auto &TII = *STI.getInstrInfo();

  if (!MRI.hasOneDef(VirtReg))
    return std::nullopt;
  if (!TII.isReMaterializable(*MRI.getOneDef(VirtReg)->getParent()))
    return std::nullopt;

  std::optional<Register> Hint;
  for (MachineInstr &MI : MRI.use_nodbg_instructions(VirtReg)) {
    if (MI.getOpcode() != MOS::COPY)
      return std::nullopt;
    const MachineOperand &Self = MI.getOperand(0).getReg() == VirtReg
                                     ? MI.getOperand(0)
                                     : MI.getOperand(1);
    const MachineOperand &Other = MI.getOperand(0).getReg() == VirtReg
                                      ? MI.getOperand(1)
                                      : MI.getOperand(0);
    Register OtherReg = Other.getReg();
    if (OtherReg.isVirtual()) {
      if (!VRM->hasPhys(OtherReg))
        return std::nullopt;
      OtherReg = VRM->getPhys(OtherReg);
    }
    if (Other.getSubReg())
      OtherReg = TRI.getSubReg(OtherReg, Other.getSubReg());

    Register Reg = OtherReg;
    if (Self.getSubReg())
      Reg = TRI.getMatchingSuperReg(Reg, Self.getSubReg(),
                                    MRI.getRegClass(Self.getReg()));
    if (!Reg || !MRI.getRegClass(Self.getReg())->contains(Reg))
      return std::nullopt;
    if (Hint && *Hint != Reg) {
      *Hint = MOS::NoRegister;
      break;
    }
    if (!Hint)
      Hint = Reg;
  }
  return Hint;
}

void MOSRegisterInfo::reserveAllSubregs(BitVector *Reserved,
                                        Register Reg) const {
  for (Register R : subregs_inclusive(Reg))
    Reserved->set(R);
}

MOSInstrCost MOSRegisterInfo::copyCost(Register DestReg, Register SrcReg,
                                       const MOSSubtarget &STI) const {
  if (DestReg == SrcReg)
    return MOSInstrCost();

  const auto &AreClasses = [&](const TargetRegisterClass &Dest,
                               const TargetRegisterClass &Src) {
    return Dest.contains(DestReg) && Src.contains(SrcReg);
  };

  auto TransferCost = MOSInstrCost(1, STI.has65CE02() ? 1 : 2);
  auto PushCost = MOSInstrCost(1, STI.hasSPC700() ? 4 : 3);
  auto PopCost = MOSInstrCost(1, STI.has65CE02() ? 3 : 4);
  auto ClvCost = MOSInstrCost(1, STI.has65CE02() ? 1 : 2);
  auto JumpCost = MOSInstrCost(3, 3);
  auto BranchCost = MOSInstrCost(2, 3);
  auto LoadImmCost = MOSInstrCost(2, 2);
  auto AluImmCost = MOSInstrCost(2, 2);

  if (AreClasses(MOS::GPRRegClass, MOS::GPRRegClass)) {
    if (MOS::AcRegClass.contains(SrcReg)) {
      assert(MOS::XYRegClass.contains(DestReg));
      // TAX
      return TransferCost;
    }
    if (MOS::AcRegClass.contains(DestReg)) {
      // TXA
      return TransferCost;
    }

    // X<->Y copies
    if (STI.hasW65816Or65EL02()) {
      // TXY, TYX
      return TransferCost;
    }
    MOSInstrCost XYCopyCost;
    if (STI.hasGPRStackRegs()) {
      // PHX/PLY, PHY/PLX
      XYCopyCost = PushCost + PopCost;
    } else {
      // May need to PHA/PLA around.
      XYCopyCost = (PushCost + PopCost) / 2 + copyCost(DestReg, MOS::A, STI) +
                   copyCost(MOS::A, SrcReg, STI);
    }
    if (STI.hasHUC6280()) {
      // SXY can be used, but only if the source register is killed. As such,
      // average the cost.
      XYCopyCost = (XYCopyCost + MOSInstrCost(1, 3)) / 2;
    }
    return XYCopyCost;
  }
  if (AreClasses(MOS::Imag8RegClass, MOS::GPRRegClass)) {
    // STImag8
    return MOSInstrCost(2, (STI.hasHUC6280() || STI.hasSPC700()) ? 4 : 3);
  }
  if (AreClasses(MOS::GPRRegClass, MOS::Imag8RegClass)) {
    // LDImag8
    return MOSInstrCost(2, (STI.hasHUC6280() || STI.hasSPC700()) ? 4 : 3);
  }
  if (AreClasses(MOS::Imag8RegClass, MOS::Imag8RegClass)) {
    // MOV dp, dp
    if (STI.hasSPC700())
      return MOSInstrCost(3, 5);
    // May need to PHA/PLA around.
    return (PushCost + PopCost) / 2 + copyCost(DestReg, MOS::A, STI) +
           copyCost(MOS::A, SrcReg, STI);
  }
  if (AreClasses(MOS::Imag16RegClass, MOS::Imag16RegClass)) {
    return copyCost(MOS::RC0, MOS::RC1, STI) * 2;
  }
  if (AreClasses(MOS::Imag32RegClass, MOS::Imag32RegClass)) {
    // An Imag32 copy costs four byte copies, matching copyPhysRegImpl's
    // recursive decomposition into two Imag16 copies.
    return copyCost(MOS::RC0, MOS::RC1, STI) * 4;
  }
  if (AreClasses(MOS::Anyi1RegClass, MOS::Anyi1RegClass)) {
    Register SrcReg8 =
        getMatchingSuperReg(SrcReg, MOS::sublsb, &MOS::Anyi8RegClass);
    Register DestReg8 =
        getMatchingSuperReg(DestReg, MOS::sublsb, &MOS::Anyi8RegClass);
    // BIT imm (HUC6280), BIT abs
    auto BitCost = STI.hasHUC6280()  ? MOSInstrCost(2, 2)
                   : STI.has65CE02() ? MOSInstrCost(3, 5)
                                     : MOSInstrCost(3, 4);

    if (SrcReg8) {
      SrcReg = SrcReg8;
      if (DestReg8) {
        DestReg = DestReg8;
        return copyCost(DestReg, SrcReg, STI);
      }
      if (DestReg == MOS::C) {
        // Cmp #1
        MOSInstrCost Cost = AluImmCost;
        if (!MOS::GPRRegClass.contains(SrcReg))
          Cost += copyCost(MOS::A, SrcReg, STI);
        return Cost;
      }

      assert(DestReg == MOS::V);
      if (STI.hasSPC700()) {
        // PHP, PLA, ORA #imm, PHA, PLP; may PHA/PLA
        return ((PushCost + PopCost) * 5 / 2) + AluImmCost;
      }

      const TargetRegisterClass &StackRegClass =
          STI.hasGPRStackRegs() ? MOS::GPRRegClass : MOS::AcRegClass;

      if (StackRegClass.contains(SrcReg)) {
        // PHA; PLA; BNE; BIT setv; JMP; CLV
        return PushCost + PopCost + BranchCost + BitCost + JumpCost + ClvCost;
      }
      // [PHA]; COPY; BNE; BIT setv; JMP; CLV; [PLA]
      return copyCost(MOS::A, SrcReg, STI) + BranchCost + BitCost + JumpCost +
             ClvCost;
    }
    if (DestReg8) {
      DestReg = DestReg8;

      Register Tmp = DestReg;
      if (!MOS::GPRRegClass.contains(Tmp))
        Tmp = MOS::A;
      // LDImm; BNE; LDImm;
      MOSInstrCost Cost = LoadImmCost * 2 + BranchCost;
      if (Tmp != DestReg)
        Cost += copyCost(DestReg, Tmp, STI);
      return Cost;
    }
    if (STI.hasSPC700()) {
      // PHA, PHP, PLA, ORA #imm, PHA, PLP, PLA, BR, CLV
      return (PushCost + PopCost) * 3 + AluImmCost + BranchCost + ClvCost;
    }
    // BIT setv; BR; CLV;
    return BitCost + BranchCost + ClvCost;
  }

  llvm_unreachable("Unexpected physical register copy.");
}
