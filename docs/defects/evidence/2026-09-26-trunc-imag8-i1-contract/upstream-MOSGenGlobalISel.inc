/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Global Instruction Selector for the MOS target                             *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifdef GET_GLOBALISEL_PREDICATE_BITSET

const unsigned MAX_SUBTARGET_PREDICATES = 2;
using PredicateBitset = llvm::Bitset<MAX_SUBTARGET_PREDICATES>;

#endif // GET_GLOBALISEL_PREDICATE_BITSET

#ifdef GET_GLOBALISEL_TEMPORARIES_DECL

  mutable MatcherState State;
  typedef ComplexRendererFns(MOSInstructionSelector::*ComplexMatcherMemFn)(MachineOperand &) const;
  typedef void(MOSInstructionSelector::*CustomRendererFn)(MachineInstrBuilder &, const MachineInstr &, int) const;
  const ExecInfoTy<PredicateBitset, ComplexMatcherMemFn, CustomRendererFn> ExecInfo;
  static MOSInstructionSelector::ComplexMatcherMemFn ComplexPredicateFns[];
  static MOSInstructionSelector::CustomRendererFn CustomRenderers[];
  bool testImmPredicate_I64(unsigned PredicateID, int64_t Imm) const override;
  bool testImmPredicate_APInt(unsigned PredicateID, const APInt &Imm) const override;
  bool testImmPredicate_APFloat(unsigned PredicateID, const APFloat &Imm) const override;
  const uint8_t *getMatchTable() const override;
  bool testMIPredicate_MI(unsigned PredicateID, const MachineInstr &MI, const MatcherState &State) const override;
  bool testMOPredicate_MO(unsigned PredicateID, const MachineOperand &MO, const MatcherState &State) const override;
  bool testSimplePredicate(unsigned PredicateID) const override;
  bool runCustomAction(unsigned FnID, const MatcherState &State, NewMIVector &OutMIs) const override;

#endif // GET_GLOBALISEL_TEMPORARIES_DECL

#ifdef GET_GLOBALISEL_TEMPORARIES_INIT

, State(0),
ExecInfo(TypeObjects, NumTypeObjects, FeatureBitsets, ComplexPredicateFns, CustomRenderers)

#endif // GET_GLOBALISEL_TEMPORARIES_INIT

#ifdef GET_GLOBALISEL_IMPL

// LLT Objects.
enum {
  GILLT_s1,
  GILLT_s8,
  GILLT_s16,
};
const static size_t NumTypeObjects = 3;
const static LLT TypeObjects[] = {
  LLT::scalar(1),
  LLT::scalar(8),
  LLT::scalar(16),
};

// Bits for subtarget features that participate in instruction matching.
enum SubtargetFeatureBits : uint8_t {
  Feature_Has65C02Bit = 0,
  Feature_HasBRABit = 1,
};

PredicateBitset MOSInstructionSelector::
computeAvailableModuleFeatures(const MOSSubtarget *Subtarget) const {
  PredicateBitset Features{};
  if (Subtarget->has65C02())
    Features.set(Feature_Has65C02Bit);
  if (Subtarget->hasBRA())
    Features.set(Feature_HasBRABit);
  return Features;
}

void MOSInstructionSelector::setupGeneratedPerFunctionState(MachineFunction &MF) {
  AvailableFunctionFeatures = computeAvailableFunctionFeatures((const MOSSubtarget *)&MF.getSubtarget(), &MF);
}
PredicateBitset MOSInstructionSelector::
computeAvailableFunctionFeatures(const MOSSubtarget *Subtarget, const MachineFunction *MF) const {
  PredicateBitset Features{};
  return Features;
}

// Feature bitsets.
enum {
  GIFBS_Invalid,
  GIFBS_Has65C02,
  GIFBS_HasBRA,
};
constexpr static PredicateBitset FeatureBitsets[] {
  {}, // GIFBS_Invalid
  {Feature_Has65C02Bit, },
  {Feature_HasBRABit, },
};

// ComplexPattern predicates.
enum {
  GICP_Invalid,
};
// See constructor for table contents

MOSInstructionSelector::ComplexMatcherMemFn
MOSInstructionSelector::ComplexPredicateFns[] = {
  nullptr, // GICP_Invalid
};

// PatFrag predicates.
enum {
  GICXXPred_MI_Predicate_ffloor_nnan = GICXXPred_Invalid + 1,
  GICXXPred_MI_Predicate_or_disjoint,
};
bool MOSInstructionSelector::testMIPredicate_MI(unsigned PredicateID, const MachineInstr & MI, const MatcherState &State) const {
  const MachineFunction &MF = *MI.getParent()->getParent();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  const auto &Operands = State.RecordedOperands;
  (void)Operands;
  (void)MRI;
  switch (PredicateID) {
  case GICXXPred_MI_Predicate_ffloor_nnan: {
    
        return MI.getFlag(MachineInstr::FmNoNans);
      
  }
  case GICXXPred_MI_Predicate_or_disjoint: {
    
        return MI.getFlag(MachineInstr::Disjoint);
      
  }
  }
  llvm_unreachable("Unknown predicate");
  return false;
}
// PatFrag predicates.
bool MOSInstructionSelector::testMOPredicate_MO(unsigned PredicateID, const MachineOperand & MO, const MatcherState &State) const {
  const auto &Operands = State.RecordedOperands;
  Register Reg = MO.getReg();
  (void)Operands;
  (void)Reg;
  llvm_unreachable("Unknown predicate");
  return false;
}
// PatFrag predicates.
enum {
  GICXXPred_I64_Predicate_FPNoSaturation = GICXXPred_Invalid + 1,
  GICXXPred_I64_Predicate_Float8E4M3FN,
  GICXXPred_I64_Predicate_Float8E5M2,
  GICXXPred_I64_Predicate_NearestTiesToEven,
};
bool MOSInstructionSelector::testImmPredicate_I64(unsigned PredicateID, int64_t Imm) const {
  switch (PredicateID) {
  case GICXXPred_I64_Predicate_FPNoSaturation: {
     return Imm == 0; 
  }
  case GICXXPred_I64_Predicate_Float8E4M3FN: {
     return Imm == APFloatBase::S_Float8E4M3FN; 
  }
  case GICXXPred_I64_Predicate_Float8E5M2: {
     return Imm == APFloatBase::S_Float8E5M2; 
  }
  case GICXXPred_I64_Predicate_NearestTiesToEven: {
     return Imm == static_cast<int>(RoundingMode::NearestTiesToEven); 
  }
  }
  llvm_unreachable("Unknown predicate");
  return false;
}
// PatFrag predicates.
bool MOSInstructionSelector::testImmPredicate_APFloat(unsigned PredicateID, const APFloat & Imm) const {
  llvm_unreachable("Unknown predicate");
  return false;
}
// PatFrag predicates.
bool MOSInstructionSelector::testImmPredicate_APInt(unsigned PredicateID, const APInt & Imm) const {
  llvm_unreachable("Unknown predicate");
  return false;
}
bool MOSInstructionSelector::testSimplePredicate(unsigned) const {
    llvm_unreachable("MOSInstructionSelector does not support simple predicates!");
  return false;
}
// Custom renderers.
enum {
  GICR_Invalid,
  GICR_renderFrameIndex,
};
MOSInstructionSelector::CustomRendererFn
MOSInstructionSelector::CustomRenderers[] = {
  nullptr, // GICR_Invalid
  &MOSInstructionSelector::renderFrameIndex,
};

bool MOSInstructionSelector::selectImpl(MachineInstr &I, CodeGenCoverage &CoverageInfo) const {
  const PredicateBitset AvailableFeatures = getAvailableFeatures();
  MachineIRBuilder B(I);
  State.MIs.clear();
  State.MIs.push_back(&I);

  if (executeMatchTable(*this, State, ExecInfo, B, getMatchTable(), TII, MF->getRegInfo(), TRI, RBI, AvailableFeatures, &CoverageInfo)) {
    return true;
  }

  return false;
}

bool MOSInstructionSelector::runCustomAction(unsigned, const MatcherState&, NewMIVector &) const {
    llvm_unreachable("MOSInstructionSelector does not support custom C++ actions!");
}
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define GIMT_Encode2(Val) uint8_t(Val), uint8_t((Val) >> 8)
#define GIMT_Encode4(Val) uint8_t(Val), uint8_t((Val) >> 8), uint8_t((Val) >> 16), uint8_t((Val) >> 24)
#define GIMT_Encode8(Val) uint8_t(Val), uint8_t((Val) >> 8), uint8_t((Val) >> 16), uint8_t((Val) >> 24),  uint8_t(uint64_t(Val) >> 32), uint8_t(uint64_t(Val) >> 40), uint8_t(uint64_t(Val) >> 48), uint8_t(uint64_t(Val) >> 56)
#else
#define GIMT_Encode2(Val) uint8_t((Val) >> 8), uint8_t(Val)
#define GIMT_Encode4(Val) uint8_t((Val) >> 24), uint8_t((Val) >> 16), uint8_t((Val) >> 8), uint8_t(Val)
#define GIMT_Encode8(Val) uint8_t(uint64_t(Val) >> 56), uint8_t(uint64_t(Val) >> 48), uint8_t(uint64_t(Val) >> 40), uint8_t(uint64_t(Val) >> 32),  uint8_t((Val) >> 24), uint8_t((Val) >> 16), uint8_t((Val) >> 8), uint8_t(Val)
#endif
const uint8_t *MOSInstructionSelector::getMatchTable() const {
  constexpr static uint8_t MatchTable0[] = {
     /*    0 */ GIM_SwitchOpcode, /*MI*/0, /*[*/GIMT_Encode2(55), GIMT_Encode2(250), /*)*//*default:*//*Label 9*/ GIMT_Encode4(1849),
     /*   10 */ /*TargetOpcode::G_ADD*//*Label 0*/ GIMT_Encode4(790),
     /*   14 */ /*TargetOpcode::G_SUB*//*Label 1*/ GIMT_Encode4(1107), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0),
     /*   46 */ /*TargetOpcode::G_AND*//*Label 2*/ GIMT_Encode4(1250),
     /*   50 */ /*TargetOpcode::G_OR*//*Label 3*/ GIMT_Encode4(1347),
     /*   54 */ /*TargetOpcode::G_XOR*//*Label 4*/ GIMT_Encode4(1444), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0),
     /*  362 */ /*TargetOpcode::G_ANYEXT*//*Label 5*/ GIMT_Encode4(1541),
     /*  366 */ /*TargetOpcode::G_TRUNC*//*Label 6*/ GIMT_Encode4(1604), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0),
     /*  382 */ /*TargetOpcode::G_CONSTANT*//*Label 7*/ GIMT_Encode4(1724), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0), GIMT_Encode4(0),
     /*  786 */ /*TargetOpcode::G_BR*//*Label 8*/ GIMT_Encode4(1813),
     /*  790 */ // Label 0: @790
     /*  790 */ GIM_Try, /*On fail goto*//*Label 10*/ GIMT_Encode4(1106),
     /*  795 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s8,
     /*  798 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /*  801 */   GIM_RootCheckType, /*Op*/2, /*Type*/GILLT_s8,
     /*  804 */   GIM_Try, /*On fail goto*//*Label 11*/ GIMT_Encode4(906),
     /*  809 */     GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::Anyi8RegClassID),
     /*  813 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Anyi8RegClassID),
     /*  817 */     GIM_Try_CheckFeatures, /*On fail goto*//*Label 12*/ GIMT_Encode4(837), GIMT_Encode2(GIFBS_Has65C02), // Rule ID 15 //
     /*  824 */       GIM_CheckConstantInt8, /*MI*/0, /*Op*/2, 1,
     /*  828 */       // (add:{ *:[i8] } Anyi8:{ *:[i8] }:$dst, 1:{ *:[i8] })  =>  (INC:{ *:[i8] } Anyi8:{ *:[i8] }:$dst)
     /*  828 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::INC),
     /*  831 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /*  833 */       GIR_RootToRootCopy, /*OpIdx*/1, // dst
     /*  835 */       GIR_RootConstrainSelectedInstOperands,
     /*  836 */       // GIR_Coverage, 15,
     /*  836 */       GIR_EraseRootFromParent_Done,
     /*  837 */     // Label 12: @837
     /*  837 */     GIM_Try_CheckFeatures, /*On fail goto*//*Label 13*/ GIMT_Encode4(857), GIMT_Encode2(GIFBS_Has65C02), // Rule ID 16 //
     /*  844 */       GIM_CheckConstantInt8, /*MI*/0, /*Op*/2, 255,
     /*  848 */       // (add:{ *:[i8] } Anyi8:{ *:[i8] }:$dst, -1:{ *:[i8] })  =>  (DEC:{ *:[i8] } Anyi8:{ *:[i8] }:$dst)
     /*  848 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::DEC),
     /*  851 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /*  853 */       GIR_RootToRootCopy, /*OpIdx*/1, // dst
     /*  855 */       GIR_RootConstrainSelectedInstOperands,
     /*  856 */       // GIR_Coverage, 16,
     /*  856 */       GIR_EraseRootFromParent_Done,
     /*  857 */     // Label 13: @857
     /*  857 */     GIM_Try, /*On fail goto*//*Label 14*/ GIMT_Encode4(881), // Rule ID 1 //
     /*  862 */       GIM_CheckConstantInt8, /*MI*/0, /*Op*/2, 1,
     /*  866 */       // (add:{ *:[i8] } Anyi8:{ *:[i8] }:$src, 1:{ *:[i8] })  =>  (IncNMOS:{ *:[i8] }:{ *:[i1] } Anyi8:{ *:[i8] }:$src)
     /*  866 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::IncNMOS),
     /*  869 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /*  871 */       GIR_RootToRootCopy, /*OpIdx*/1, // src
     /*  873 */       GIR_SetImplicitDefDead, /*InsnID*/0, /*OpIdx for MOS::C*/0,
     /*  876 */       GIR_SetImplicitDefDead, /*InsnID*/0, /*OpIdx for MOS::V*/1,
     /*  879 */       GIR_RootConstrainSelectedInstOperands,
     /*  880 */       // GIR_Coverage, 1,
     /*  880 */       GIR_EraseRootFromParent_Done,
     /*  881 */     // Label 14: @881
     /*  881 */     GIM_Try, /*On fail goto*//*Label 15*/ GIMT_Encode4(905), // Rule ID 2 //
     /*  886 */       GIM_CheckConstantInt8, /*MI*/0, /*Op*/2, 255,
     /*  890 */       // (add:{ *:[i8] } Anyi8:{ *:[i8] }:$src, -1:{ *:[i8] })  =>  (DecNMOS:{ *:[i8] }:{ *:[i1] } Anyi8:{ *:[i8] }:$src)
     /*  890 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::DecNMOS),
     /*  893 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /*  895 */       GIR_RootToRootCopy, /*OpIdx*/1, // src
     /*  897 */       GIR_SetImplicitDefDead, /*InsnID*/0, /*OpIdx for MOS::C*/0,
     /*  900 */       GIR_SetImplicitDefDead, /*InsnID*/0, /*OpIdx for MOS::V*/1,
     /*  903 */       GIR_RootConstrainSelectedInstOperands,
     /*  904 */       // GIR_Coverage, 2,
     /*  904 */       GIR_EraseRootFromParent_Done,
     /*  905 */     // Label 15: @905
     /*  905 */     GIM_Reject,
     /*  906 */   // Label 11: @906
     /*  906 */   GIM_Try, /*On fail goto*//*Label 16*/ GIMT_Encode4(1105),
     /*  911 */     GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /*  915 */     GIM_Try, /*On fail goto*//*Label 17*/ GIMT_Encode4(1044),
     /*  920 */       GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /*  924 */       GIM_Try, /*On fail goto*//*Label 18*/ GIMT_Encode4(987), // Rule ID 11 //
     /*  929 */         GIM_RecordInsn, /*DefineMI*/1, /*MI*/0, /*OpIdx*/2, // MIs[1]
     /*  933 */         GIM_CheckOpcode, /*MI*/1, GIMT_Encode2(TargetOpcode::G_CONSTANT),
     /*  937 */         // MIs[1] Operand 1
     /*  937 */         // No operand predicates
     /*  937 */         GIM_CheckIsSafeToFold, /*NumInsns*/1,
     /*  939 */         // (add:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$imm)  =>  (ADCImm:{ *:[i8] }:{ *:[i1] }:{ *:[i1] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$imm, (LDCImm:{ *:[i1] } 0:{ *:[i1] }))
     /*  939 */         GIR_MakeTempReg, /*TempRegID*/1, /*TypeID*/GILLT_s1,
     /*  942 */         GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s1,
     /*  945 */         GIR_MakeTempReg, /*TempRegID*/2, /*TypeID*/GILLT_s1,
     /*  948 */         GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::LDCImm),
     /*  952 */         GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/2, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /*  957 */         GIR_AddImm8, /*InsnID*/1, /*Imm*/0,
     /*  960 */         GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /*  962 */         GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ADCImm),
     /*  965 */         GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /*  967 */         GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /*  972 */         GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/1, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /*  977 */         GIR_RootToRootCopy, /*OpIdx*/1, // l
     /*  979 */         GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/1, // imm
     /*  982 */         GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/2,
     /*  985 */         GIR_RootConstrainSelectedInstOperands,
     /*  986 */         // GIR_Coverage, 11,
     /*  986 */         GIR_EraseRootFromParent_Done,
     /*  987 */       // Label 18: @987
     /*  987 */       GIM_Try, /*On fail goto*//*Label 19*/ GIMT_Encode4(1043), // Rule ID 12 //
     /*  992 */         GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /*  996 */         // (add:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)  =>  (ADCImag8:{ *:[i8] }:{ *:[i1] }:{ *:[i1] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r, (LDCImm:{ *:[i1] } 0:{ *:[i1] }))
     /*  996 */         GIR_MakeTempReg, /*TempRegID*/1, /*TypeID*/GILLT_s1,
     /*  999 */         GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s1,
     /* 1002 */         GIR_MakeTempReg, /*TempRegID*/2, /*TypeID*/GILLT_s1,
     /* 1005 */         GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::LDCImm),
     /* 1009 */         GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/2, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1014 */         GIR_AddImm8, /*InsnID*/1, /*Imm*/0,
     /* 1017 */         GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1019 */         GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ADCImag8),
     /* 1022 */         GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1024 */         GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1029 */         GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/1, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1034 */         GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1036 */         GIR_RootToRootCopy, /*OpIdx*/2, // r
     /* 1038 */         GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/2,
     /* 1041 */         GIR_RootConstrainSelectedInstOperands,
     /* 1042 */         // GIR_Coverage, 12,
     /* 1042 */         GIR_EraseRootFromParent_Done,
     /* 1043 */       // Label 19: @1043
     /* 1043 */       GIM_Reject,
     /* 1044 */     // Label 17: @1044
     /* 1044 */     GIM_Try, /*On fail goto*//*Label 20*/ GIMT_Encode4(1104), // Rule ID 25 //
     /* 1049 */       GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1053 */       GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1057 */       // (add:{ *:[i8] } Imag8:{ *:[i8] }:$r, Ac:{ *:[i8] }:$l)  =>  (ADCImag8:{ *:[i8] }:{ *:[i1] }:{ *:[i1] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r, (LDCImm:{ *:[i1] } 0:{ *:[i1] }))
     /* 1057 */       GIR_MakeTempReg, /*TempRegID*/1, /*TypeID*/GILLT_s1,
     /* 1060 */       GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s1,
     /* 1063 */       GIR_MakeTempReg, /*TempRegID*/2, /*TypeID*/GILLT_s1,
     /* 1066 */       GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::LDCImm),
     /* 1070 */       GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/2, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1075 */       GIR_AddImm8, /*InsnID*/1, /*Imm*/0,
     /* 1078 */       GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1080 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ADCImag8),
     /* 1083 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1085 */       GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1090 */       GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/1, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1095 */       GIR_RootToRootCopy, /*OpIdx*/2, // l
     /* 1097 */       GIR_RootToRootCopy, /*OpIdx*/1, // r
     /* 1099 */       GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/2,
     /* 1102 */       GIR_RootConstrainSelectedInstOperands,
     /* 1103 */       // GIR_Coverage, 25,
     /* 1103 */       GIR_EraseRootFromParent_Done,
     /* 1104 */     // Label 20: @1104
     /* 1104 */     GIM_Reject,
     /* 1105 */   // Label 16: @1105
     /* 1105 */   GIM_Reject,
     /* 1106 */ // Label 10: @1106
     /* 1106 */ GIM_Reject,
     /* 1107 */ // Label 1: @1107
     /* 1107 */ GIM_Try, /*On fail goto*//*Label 21*/ GIMT_Encode4(1249),
     /* 1112 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s8,
     /* 1115 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1118 */   GIM_RootCheckType, /*Op*/2, /*Type*/GILLT_s8,
     /* 1121 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1125 */   GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1129 */   GIM_Try, /*On fail goto*//*Label 22*/ GIMT_Encode4(1192), // Rule ID 13 //
     /* 1134 */     GIM_RecordInsn, /*DefineMI*/1, /*MI*/0, /*OpIdx*/2, // MIs[1]
     /* 1138 */     GIM_CheckOpcode, /*MI*/1, GIMT_Encode2(TargetOpcode::G_CONSTANT),
     /* 1142 */     // MIs[1] Operand 1
     /* 1142 */     // No operand predicates
     /* 1142 */     GIM_CheckIsSafeToFold, /*NumInsns*/1,
     /* 1144 */     // (sub:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$imm)  =>  (SBCImm:{ *:[i8] }:{ *:[i1] }:{ *:[i1] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$imm, (LDCImm:{ *:[i1] } -1:{ *:[i1] }))
     /* 1144 */     GIR_MakeTempReg, /*TempRegID*/1, /*TypeID*/GILLT_s1,
     /* 1147 */     GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s1,
     /* 1150 */     GIR_MakeTempReg, /*TempRegID*/2, /*TypeID*/GILLT_s1,
     /* 1153 */     GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::LDCImm),
     /* 1157 */     GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/2, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1162 */     GIR_AddImm8, /*InsnID*/1, /*Imm*/255,
     /* 1165 */     GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1167 */     GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::SBCImm),
     /* 1170 */     GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1172 */     GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1177 */     GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/1, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1182 */     GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1184 */     GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/1, // imm
     /* 1187 */     GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/2,
     /* 1190 */     GIR_RootConstrainSelectedInstOperands,
     /* 1191 */     // GIR_Coverage, 13,
     /* 1191 */     GIR_EraseRootFromParent_Done,
     /* 1192 */   // Label 22: @1192
     /* 1192 */   GIM_Try, /*On fail goto*//*Label 23*/ GIMT_Encode4(1248), // Rule ID 14 //
     /* 1197 */     GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1201 */     // (sub:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)  =>  (SBCImag8:{ *:[i8] }:{ *:[i1] }:{ *:[i1] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r, (LDCImm:{ *:[i1] } -1:{ *:[i1] }))
     /* 1201 */     GIR_MakeTempReg, /*TempRegID*/1, /*TypeID*/GILLT_s1,
     /* 1204 */     GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s1,
     /* 1207 */     GIR_MakeTempReg, /*TempRegID*/2, /*TypeID*/GILLT_s1,
     /* 1210 */     GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::LDCImm),
     /* 1214 */     GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/2, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1219 */     GIR_AddImm8, /*InsnID*/1, /*Imm*/255,
     /* 1222 */     GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1224 */     GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::SBCImag8),
     /* 1227 */     GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1229 */     GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1234 */     GIR_AddTempRegister, /*InsnID*/0, /*TempRegID*/1, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define|RegState::Dead)),
     /* 1239 */     GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1241 */     GIR_RootToRootCopy, /*OpIdx*/2, // r
     /* 1243 */     GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/2,
     /* 1246 */     GIR_RootConstrainSelectedInstOperands,
     /* 1247 */     // GIR_Coverage, 14,
     /* 1247 */     GIR_EraseRootFromParent_Done,
     /* 1248 */   // Label 23: @1248
     /* 1248 */   GIM_Reject,
     /* 1249 */ // Label 21: @1249
     /* 1249 */ GIM_Reject,
     /* 1250 */ // Label 2: @1250
     /* 1250 */ GIM_Try, /*On fail goto*//*Label 24*/ GIMT_Encode4(1346),
     /* 1255 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s8,
     /* 1258 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1261 */   GIM_RootCheckType, /*Op*/2, /*Type*/GILLT_s8,
     /* 1264 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1268 */   GIM_Try, /*On fail goto*//*Label 25*/ GIMT_Encode4(1321),
     /* 1273 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1277 */     GIM_Try, /*On fail goto*//*Label 26*/ GIMT_Encode4(1304), // Rule ID 3 //
     /* 1282 */       GIM_RecordInsn, /*DefineMI*/1, /*MI*/0, /*OpIdx*/2, // MIs[1]
     /* 1286 */       GIM_CheckOpcode, /*MI*/1, GIMT_Encode2(TargetOpcode::G_CONSTANT),
     /* 1290 */       // MIs[1] Operand 1
     /* 1290 */       // No operand predicates
     /* 1290 */       GIM_CheckIsSafeToFold, /*NumInsns*/1,
     /* 1292 */       // (and:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)  =>  (ANDImm:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)
     /* 1292 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ANDImm),
     /* 1295 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1297 */       GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1299 */       GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/1, // r
     /* 1302 */       GIR_RootConstrainSelectedInstOperands,
     /* 1303 */       // GIR_Coverage, 3,
     /* 1303 */       GIR_EraseRootFromParent_Done,
     /* 1304 */     // Label 26: @1304
     /* 1304 */     GIM_Try, /*On fail goto*//*Label 27*/ GIMT_Encode4(1320), // Rule ID 4 //
     /* 1309 */       GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1313 */       // (and:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)  =>  (ANDImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1313 */       GIR_MutateOpcode, /*InsnID*/0, /*RecycleInsnID*/0, /*Opcode*/GIMT_Encode2(MOS::ANDImag8),
     /* 1318 */       GIR_RootConstrainSelectedInstOperands,
     /* 1319 */       // GIR_Coverage, 4,
     /* 1319 */       GIR_Done,
     /* 1320 */     // Label 27: @1320
     /* 1320 */     GIM_Reject,
     /* 1321 */   // Label 25: @1321
     /* 1321 */   GIM_Try, /*On fail goto*//*Label 28*/ GIMT_Encode4(1345), // Rule ID 22 //
     /* 1326 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1330 */     GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1334 */     // (and:{ *:[i8] } Imag8:{ *:[i8] }:$r, Ac:{ *:[i8] }:$l)  =>  (ANDImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1334 */     GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ANDImag8),
     /* 1337 */     GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1339 */     GIR_RootToRootCopy, /*OpIdx*/2, // l
     /* 1341 */     GIR_RootToRootCopy, /*OpIdx*/1, // r
     /* 1343 */     GIR_RootConstrainSelectedInstOperands,
     /* 1344 */     // GIR_Coverage, 22,
     /* 1344 */     GIR_EraseRootFromParent_Done,
     /* 1345 */   // Label 28: @1345
     /* 1345 */   GIM_Reject,
     /* 1346 */ // Label 24: @1346
     /* 1346 */ GIM_Reject,
     /* 1347 */ // Label 3: @1347
     /* 1347 */ GIM_Try, /*On fail goto*//*Label 29*/ GIMT_Encode4(1443),
     /* 1352 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s8,
     /* 1355 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1358 */   GIM_RootCheckType, /*Op*/2, /*Type*/GILLT_s8,
     /* 1361 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1365 */   GIM_Try, /*On fail goto*//*Label 30*/ GIMT_Encode4(1418),
     /* 1370 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1374 */     GIM_Try, /*On fail goto*//*Label 31*/ GIMT_Encode4(1401), // Rule ID 7 //
     /* 1379 */       GIM_RecordInsn, /*DefineMI*/1, /*MI*/0, /*OpIdx*/2, // MIs[1]
     /* 1383 */       GIM_CheckOpcode, /*MI*/1, GIMT_Encode2(TargetOpcode::G_CONSTANT),
     /* 1387 */       // MIs[1] Operand 1
     /* 1387 */       // No operand predicates
     /* 1387 */       GIM_CheckIsSafeToFold, /*NumInsns*/1,
     /* 1389 */       // (or:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)  =>  (ORAImm:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)
     /* 1389 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ORAImm),
     /* 1392 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1394 */       GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1396 */       GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/1, // r
     /* 1399 */       GIR_RootConstrainSelectedInstOperands,
     /* 1400 */       // GIR_Coverage, 7,
     /* 1400 */       GIR_EraseRootFromParent_Done,
     /* 1401 */     // Label 31: @1401
     /* 1401 */     GIM_Try, /*On fail goto*//*Label 32*/ GIMT_Encode4(1417), // Rule ID 8 //
     /* 1406 */       GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1410 */       // (or:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)  =>  (ORAImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1410 */       GIR_MutateOpcode, /*InsnID*/0, /*RecycleInsnID*/0, /*Opcode*/GIMT_Encode2(MOS::ORAImag8),
     /* 1415 */       GIR_RootConstrainSelectedInstOperands,
     /* 1416 */       // GIR_Coverage, 8,
     /* 1416 */       GIR_Done,
     /* 1417 */     // Label 32: @1417
     /* 1417 */     GIM_Reject,
     /* 1418 */   // Label 30: @1418
     /* 1418 */   GIM_Try, /*On fail goto*//*Label 33*/ GIMT_Encode4(1442), // Rule ID 24 //
     /* 1423 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1427 */     GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1431 */     // (or:{ *:[i8] } Imag8:{ *:[i8] }:$r, Ac:{ *:[i8] }:$l)  =>  (ORAImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1431 */     GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::ORAImag8),
     /* 1434 */     GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1436 */     GIR_RootToRootCopy, /*OpIdx*/2, // l
     /* 1438 */     GIR_RootToRootCopy, /*OpIdx*/1, // r
     /* 1440 */     GIR_RootConstrainSelectedInstOperands,
     /* 1441 */     // GIR_Coverage, 24,
     /* 1441 */     GIR_EraseRootFromParent_Done,
     /* 1442 */   // Label 33: @1442
     /* 1442 */   GIM_Reject,
     /* 1443 */ // Label 29: @1443
     /* 1443 */ GIM_Reject,
     /* 1444 */ // Label 4: @1444
     /* 1444 */ GIM_Try, /*On fail goto*//*Label 34*/ GIMT_Encode4(1540),
     /* 1449 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s8,
     /* 1452 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1455 */   GIM_RootCheckType, /*Op*/2, /*Type*/GILLT_s8,
     /* 1458 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1462 */   GIM_Try, /*On fail goto*//*Label 35*/ GIMT_Encode4(1515),
     /* 1467 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1471 */     GIM_Try, /*On fail goto*//*Label 36*/ GIMT_Encode4(1498), // Rule ID 5 //
     /* 1476 */       GIM_RecordInsn, /*DefineMI*/1, /*MI*/0, /*OpIdx*/2, // MIs[1]
     /* 1480 */       GIM_CheckOpcode, /*MI*/1, GIMT_Encode2(TargetOpcode::G_CONSTANT),
     /* 1484 */       // MIs[1] Operand 1
     /* 1484 */       // No operand predicates
     /* 1484 */       GIM_CheckIsSafeToFold, /*NumInsns*/1,
     /* 1486 */       // (xor:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)  =>  (EORImm:{ *:[i8] } Ac:{ *:[i8] }:$l, (imm:{ *:[i8] }):$r)
     /* 1486 */       GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::EORImm),
     /* 1489 */       GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1491 */       GIR_RootToRootCopy, /*OpIdx*/1, // l
     /* 1493 */       GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/1, // r
     /* 1496 */       GIR_RootConstrainSelectedInstOperands,
     /* 1497 */       // GIR_Coverage, 5,
     /* 1497 */       GIR_EraseRootFromParent_Done,
     /* 1498 */     // Label 36: @1498
     /* 1498 */     GIM_Try, /*On fail goto*//*Label 37*/ GIMT_Encode4(1514), // Rule ID 6 //
     /* 1503 */       GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1507 */       // (xor:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)  =>  (EORImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1507 */       GIR_MutateOpcode, /*InsnID*/0, /*RecycleInsnID*/0, /*Opcode*/GIMT_Encode2(MOS::EORImag8),
     /* 1512 */       GIR_RootConstrainSelectedInstOperands,
     /* 1513 */       // GIR_Coverage, 6,
     /* 1513 */       GIR_Done,
     /* 1514 */     // Label 37: @1514
     /* 1514 */     GIM_Reject,
     /* 1515 */   // Label 35: @1515
     /* 1515 */   GIM_Try, /*On fail goto*//*Label 38*/ GIMT_Encode4(1539), // Rule ID 23 //
     /* 1520 */     GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1524 */     GIM_RootCheckRegBankForClass, /*Op*/2, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1528 */     // (xor:{ *:[i8] } Imag8:{ *:[i8] }:$r, Ac:{ *:[i8] }:$l)  =>  (EORImag8:{ *:[i8] } Ac:{ *:[i8] }:$l, Imag8:{ *:[i8] }:$r)
     /* 1528 */     GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::EORImag8),
     /* 1531 */     GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1533 */     GIR_RootToRootCopy, /*OpIdx*/2, // l
     /* 1535 */     GIR_RootToRootCopy, /*OpIdx*/1, // r
     /* 1537 */     GIR_RootConstrainSelectedInstOperands,
     /* 1538 */     // GIR_Coverage, 23,
     /* 1538 */     GIR_EraseRootFromParent_Done,
     /* 1539 */   // Label 38: @1539
     /* 1539 */   GIM_Reject,
     /* 1540 */ // Label 34: @1540
     /* 1540 */ GIM_Reject,
     /* 1541 */ // Label 5: @1541
     /* 1541 */ GIM_Try, /*On fail goto*//*Label 39*/ GIMT_Encode4(1603), // Rule ID 17 //
     /* 1546 */   GIM_RootCheckType, /*Op*/0, /*Type*/GILLT_s16,
     /* 1549 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1552 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::Imag16RegClassID),
     /* 1556 */   GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Anyi8RegClassID),
     /* 1560 */   // (anyext:{ *:[i16] } Anyi8:{ *:[i8] }:$s)  =>  (INSERT_SUBREG:{ *:[i16] } (IMPLICIT_DEF:{ *:[i16] }), Anyi8:{ *:[i8] }:$s, sublo:{ *:[i32] })
     /* 1560 */   GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s16,
     /* 1563 */   GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(TargetOpcode::IMPLICIT_DEF),
     /* 1567 */   GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1572 */   GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1574 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(TargetOpcode::INSERT_SUBREG),
     /* 1577 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1579 */   GIR_AddSimpleTempRegister, /*InsnID*/0, /*TempRegID*/0,
     /* 1582 */   GIR_RootToRootCopy, /*OpIdx*/1, // s
     /* 1584 */   GIR_AddImm8, /*InsnID*/0, /*Imm*/3,
     /* 1587 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/0, GIMT_Encode2(MOS::Imag16RegClassID),
     /* 1592 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/1, GIMT_Encode2(MOS::Imag16RegClassID),
     /* 1597 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/2, GIMT_Encode2(MOS::Anyi8RegClassID),
     /* 1602 */   // GIR_Coverage, 17,
     /* 1602 */   GIR_EraseRootFromParent_Done,
     /* 1603 */ // Label 39: @1603
     /* 1603 */ GIM_Reject,
     /* 1604 */ // Label 6: @1604
     /* 1604 */ GIM_SwitchType, /*MI*/0, /*Op*/0, /*[*/GIMT_Encode2(0), GIMT_Encode2(2), /*)*//*default:*//*Label 42*/ GIMT_Encode4(1723),
     /* 1615 */ /*GILLT_s1*//*Label 40*/ GIMT_Encode4(1623),
     /* 1619 */ /*GILLT_s8*//*Label 41*/ GIMT_Encode4(1684),
     /* 1623 */ // Label 40: @1623
     /* 1623 */ GIM_Try, /*On fail goto*//*Label 43*/ GIMT_Encode4(1683), // Rule ID 18 //
     /* 1628 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s8,
     /* 1631 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::GPR_LSBRegClassID),
     /* 1635 */   GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::AcRegClassID),
     /* 1639 */   // (trunc:{ *:[i1] } Ac:{ *:[i8] }:$s)  =>  (EXTRACT_SUBREG:{ *:[i1] } (ANDImm:{ *:[i8] } Ac:{ *:[i8] }:$s, 1:{ *:[i8] }), sublsb:{ *:[i32] })
     /* 1639 */   GIR_MakeTempReg, /*TempRegID*/0, /*TypeID*/GILLT_s8,
     /* 1642 */   GIR_BuildMI, /*InsnID*/1, /*Opcode*/GIMT_Encode2(MOS::ANDImm),
     /* 1646 */   GIR_AddTempRegister, /*InsnID*/1, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(static_cast<uint16_t>(RegState::Define)),
     /* 1651 */   GIR_Copy, /*NewInsnID*/1, /*OldInsnID*/0, /*OpIdx*/1, // s
     /* 1655 */   GIR_AddImm8, /*InsnID*/1, /*Imm*/1,
     /* 1658 */   GIR_ConstrainSelectedInstOperands, /*InsnID*/1,
     /* 1660 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(TargetOpcode::COPY),
     /* 1663 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1665 */   GIR_AddTempSubRegister, /*InsnID*/0, /*TempRegID*/0, /*TempRegFlags*/GIMT_Encode2(0), GIMT_Encode2(MOS::sublsb),
     /* 1672 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/0, GIMT_Encode2(MOS::GPR_LSBRegClassID),
     /* 1677 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/1, GIMT_Encode2(MOS::AcRegClassID),
     /* 1682 */   // GIR_Coverage, 18,
     /* 1682 */   GIR_EraseRootFromParent_Done,
     /* 1683 */ // Label 43: @1683
     /* 1683 */ GIM_Reject,
     /* 1684 */ // Label 41: @1684
     /* 1684 */ GIM_Try, /*On fail goto*//*Label 44*/ GIMT_Encode4(1722), // Rule ID 19 //
     /* 1689 */   GIM_RootCheckType, /*Op*/1, /*Type*/GILLT_s16,
     /* 1692 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1696 */   GIM_RootCheckRegBankForClass, /*Op*/1, /*RC*/GIMT_Encode2(MOS::Imag16RegClassID),
     /* 1700 */   // (trunc:{ *:[i8] } Imag16:{ *:[i16] }:$s)  =>  (EXTRACT_SUBREG:{ *:[i8] } Imag16:{ *:[i16] }:$s, sublo:{ *:[i32] })
     /* 1700 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(TargetOpcode::COPY),
     /* 1703 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1705 */   GIR_CopySubReg, /*NewInsnID*/0, /*OldInsnID*/0, /*OpIdx*/1, /*SubRegIdx*/GIMT_Encode2(3), // s
     /* 1711 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/0, GIMT_Encode2(MOS::Imag8RegClassID),
     /* 1716 */   GIR_ConstrainOperandRC, /*InsnID*/0, /*Op*/1, GIMT_Encode2(MOS::Imag16RegClassID),
     /* 1721 */   // GIR_Coverage, 19,
     /* 1721 */   GIR_EraseRootFromParent_Done,
     /* 1722 */ // Label 44: @1722
     /* 1722 */ GIM_Reject,
     /* 1723 */ // Label 42: @1723
     /* 1723 */ GIM_Reject,
     /* 1724 */ // Label 7: @1724
     /* 1724 */ GIM_SwitchType, /*MI*/0, /*Op*/0, /*[*/GIMT_Encode2(0), GIMT_Encode2(2), /*)*//*default:*//*Label 47*/ GIMT_Encode4(1812),
     /* 1735 */ /*GILLT_s1*//*Label 45*/ GIMT_Encode4(1743),
     /* 1739 */ /*GILLT_s8*//*Label 46*/ GIMT_Encode4(1763),
     /* 1743 */ // Label 45: @1743
     /* 1743 */ GIM_Try, /*On fail goto*//*Label 48*/ GIMT_Encode4(1762), // Rule ID 20 //
     /* 1748 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::CV_GPR_LSBRegClassID),
     /* 1752 */   // MIs[0] Operand 1
     /* 1752 */   // No operand predicates
     /* 1752 */   // (imm:{ *:[i1] }):$s  =>  (LDImm1:{ *:[i1] } (imm:{ *:[i1] }):$s)
     /* 1752 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::LDImm1),
     /* 1755 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1757 */   GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/0, // s
     /* 1760 */   GIR_RootConstrainSelectedInstOperands,
     /* 1761 */   // GIR_Coverage, 20,
     /* 1761 */   GIR_EraseRootFromParent_Done,
     /* 1762 */ // Label 48: @1762
     /* 1762 */ GIM_Reject,
     /* 1763 */ // Label 46: @1763
     /* 1763 */ GIM_Try_CheckFeatures, /*On fail goto*//*Label 49*/ GIMT_Encode4(1792), GIMT_Encode2(GIFBS_Has65C02), // Rule ID 0 //
     /* 1770 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::Anyi8RegClassID),
     /* 1774 */   // MIs[0] Operand 1
     /* 1774 */   GIM_CheckLiteralInt, /*MI*/0, /*Op*/1, GIMT_Encode8(0),
     /* 1785 */   // 0:{ *:[i8] }  =>  (LDZ:{ *:[i8] })
     /* 1785 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::LDZ),
     /* 1788 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1790 */   GIR_RootConstrainSelectedInstOperands,
     /* 1791 */   // GIR_Coverage, 0,
     /* 1791 */   GIR_EraseRootFromParent_Done,
     /* 1792 */ // Label 49: @1792
     /* 1792 */ GIM_Try, /*On fail goto*//*Label 50*/ GIMT_Encode4(1811), // Rule ID 21 //
     /* 1797 */   GIM_RootCheckRegBankForClass, /*Op*/0, /*RC*/GIMT_Encode2(MOS::GPRRegClassID),
     /* 1801 */   // MIs[0] Operand 1
     /* 1801 */   // No operand predicates
     /* 1801 */   // (imm:{ *:[i8] }):$s  =>  (LDImm:{ *:[i8] } (imm:{ *:[i8] }):$s)
     /* 1801 */   GIR_BuildRootMI, /*Opcode*/GIMT_Encode2(MOS::LDImm),
     /* 1804 */   GIR_RootToRootCopy, /*OpIdx*/0, // DstI[dst]
     /* 1806 */   GIR_CopyConstantAsSImm, /*NewInsnID*/0, /*OldInsnID*/0, // s
     /* 1809 */   GIR_RootConstrainSelectedInstOperands,
     /* 1810 */   // GIR_Coverage, 21,
     /* 1810 */   GIR_EraseRootFromParent_Done,
     /* 1811 */ // Label 50: @1811
     /* 1811 */ GIM_Reject,
     /* 1812 */ // Label 47: @1812
     /* 1812 */ GIM_Reject,
     /* 1813 */ // Label 8: @1813
     /* 1813 */ GIM_Try, /*On fail goto*//*Label 51*/ GIMT_Encode4(1848),
     /* 1818 */   GIM_CheckIsMBB, /*MI*/0, /*Op*/0,
     /* 1821 */   GIM_Try_CheckFeatures, /*On fail goto*//*Label 52*/ GIMT_Encode4(1835), GIMT_Encode2(GIFBS_HasBRA), // Rule ID 9 //
     /* 1828 */     // (br (bb:{ *:[Other] }):$tgt)  =>  (BRA (bb:{ *:[Other] }):$tgt)
     /* 1828 */     GIR_MutateOpcode, /*InsnID*/0, /*RecycleInsnID*/0, /*Opcode*/GIMT_Encode2(MOS::BRA),
     /* 1833 */     GIR_RootConstrainSelectedInstOperands,
     /* 1834 */     // GIR_Coverage, 9,
     /* 1834 */     GIR_Done,
     /* 1835 */   // Label 52: @1835
     /* 1835 */   GIM_Try, /*On fail goto*//*Label 53*/ GIMT_Encode4(1847), // Rule ID 10 //
     /* 1840 */     // (br (bb:{ *:[Other] }):$tgt)  =>  (JMP (bb:{ *:[Other] }):$tgt)
     /* 1840 */     GIR_MutateOpcode, /*InsnID*/0, /*RecycleInsnID*/0, /*Opcode*/GIMT_Encode2(MOS::JMP),
     /* 1845 */     GIR_RootConstrainSelectedInstOperands,
     /* 1846 */     // GIR_Coverage, 10,
     /* 1846 */     GIR_Done,
     /* 1847 */   // Label 53: @1847
     /* 1847 */   GIM_Reject,
     /* 1848 */ // Label 51: @1848
     /* 1848 */ GIM_Reject,
     /* 1849 */ // Label 9: @1849
     /* 1849 */ GIM_Reject,
     /* 1850 */ }; // Size: 1850 bytes
  return MatchTable0;
}
#undef GIMT_Encode2
#undef GIMT_Encode4
#undef GIMT_Encode8


#endif // GET_GLOBALISEL_IMPL

#ifdef GET_GLOBALISEL_PREDICATES_DECL

PredicateBitset AvailableModuleFeatures;
mutable PredicateBitset AvailableFunctionFeatures;
PredicateBitset getAvailableFeatures() const {
  return AvailableModuleFeatures | AvailableFunctionFeatures;
}
PredicateBitset
computeAvailableModuleFeatures(const MOSSubtarget *Subtarget) const;
PredicateBitset
computeAvailableFunctionFeatures(const MOSSubtarget *Subtarget,
                                 const MachineFunction *MF) const;
void setupGeneratedPerFunctionState(MachineFunction &MF) override;

#endif // GET_GLOBALISEL_PREDICATES_DECL

#ifdef GET_GLOBALISEL_PREDICATES_INIT

AvailableModuleFeatures(computeAvailableModuleFeatures(&STI)),
AvailableFunctionFeatures()

#endif // GET_GLOBALISEL_PREDICATES_INIT

