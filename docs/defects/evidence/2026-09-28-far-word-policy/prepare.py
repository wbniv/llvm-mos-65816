from pathlib import Path
import difflib
w=Path('.scratch/far-word-policy');p=w/'source/MOSLegalizerInfo.cpp'
s=(w/'source/MOSLegalizerInfo.baseline.cpp').read_text()
def replace(a,b):
 global s
 assert s.count(a)==1,(a,s.count(a))
 s=s.replace(a,b)
replace('#include "llvm/Support/MathExtras.h"', '#include "llvm/Support/MathExtras.h"\n#include "llvm/Target/TargetMachine.h"')
replace('// The pointer add disappears only when every use', '''enum class FarWordIndexPolicy { Off, Speed, All };
static cl::opt<FarWordIndexPolicy> FarWordIndex(
    "mos-far-word-index", cl::Hidden, cl::init(FarWordIndexPolicy::Speed),
    cl::desc("Fold bounded native far word loads into Y8 indexing"),
    cl::values(clEnumValN(FarWordIndexPolicy::Off, "off", "Retain explicit pointers"),
               clEnumValN(FarWordIndexPolicy::Speed, "speed", "Enable in functions optimized for speed"),
               clEnumValN(FarWordIndexPolicy::All, "all", "Enable regardless of size attributes")));

static bool isPlainFarWordLoad(const MachineInstr &MI,
                               const MachineRegisterInfo &MRI) {
  const auto *Load = dyn_cast<GLoad>(&MI);
  return Load && MRI.getType(Load->getReg(0)) == LLT::scalar(16) &&
         Load->getMemSize() == LocationSize::precise(2);
}

// The pointer add disappears only when every use''')
replace('bool FnMayCall, unsigned Depth) {','bool FnMayCall, bool AllowWord, bool &HasWord, unsigned Depth) {')
replace('''          MRI.getType(U.getOperand(0).getReg()) != LLT::scalar(8))
        return false;''','''          (MRI.getType(U.getOperand(0).getReg()) != LLT::scalar(8) &&
           !(AllowWord && isPlainFarWordLoad(U, MRI))))
        return false;
      HasWord |= isPlainFarWordLoad(U, MRI);''')
replace('NumAccesses, FnMayCall, Depth + 1)', 'NumAccesses, FnMayCall, AllowWord, HasWord, Depth + 1)')
replace('''  // The indexed pseudos below carry one byte. A native word access must retain
  // its own lowering, and wider siblings must not keep a partially folded add.
  if (MRI.getType(MI.getOperand(0).getReg()) != LLT::scalar(8))''','''  const Function &F = Builder.getMF().getFunction();
  const bool AllowWord = STI.hasAccum16() &&
      (FarWordIndex == FarWordIndexPolicy::All ||
       (FarWordIndex == FarWordIndexPolicy::Speed && !F.hasOptSize() &&
        !F.hasOptNone() && Builder.getMF().getTarget().getOptLevel() >=
            CodeGenOptLevel::Default));
  const bool Word = AllowWord && isPlainFarWordLoad(MI, MRI);
  if (!Word && MRI.getType(MI.getOperand(0).getReg()) != LLT::scalar(8))''')
replace('const uint64_t Limit = STI.hasIndex16() ? 0xFFFF : 0xFF;', 'uint64_t Limit = !Word && STI.hasIndex16() ? 0xFFFF : 0xFF;')
replace('''  unsigned NumAccesses = 0;
  if (!allUsesAreFoldableFarAccesses''','''  unsigned NumAccesses = 0;
  bool HasWord = false;
  if (!allUsesAreFoldableFarAccesses''')
replace('FnMayCall, 0))', 'FnMayCall, AllowWord, HasWord, 0))')
replace('''  if (MaxOff + MaxEnd > Limit)
    return false;''','''  // Native word pseudos consume Y8. Every sibling must fit that same limit,
  // including a byte access visited before the word access.
  if (HasWord)
    Limit = 0xFF;
  if (MaxOff + MaxEnd > Limit)
    return false;''')
replace('''  unsigned Opcode =
      Wide ? (IsLoad ? MOS::G_LOAD_FAR_INDIR_IDX16 : MOS::G_STORE_FAR_INDIR_IDX16)
           : (IsLoad ? MOS::G_LOAD_FAR_INDIR_IDX : MOS::G_STORE_FAR_INDIR_IDX);''','''  unsigned Opcode = Word ? MOS::G_LOAD16_FAR_INDIR_IDX
      : Wide ? (IsLoad ? MOS::G_LOAD_FAR_INDIR_IDX16 : MOS::G_STORE_FAR_INDIR_IDX16)
             : (IsLoad ? MOS::G_LOAD_FAR_INDIR_IDX : MOS::G_STORE_FAR_INDIR_IDX);''')
p.write_text(s)
(w/'candidate.patch').write_text(''.join(difflib.unified_diff((w/'source/MOSLegalizerInfo.baseline.cpp').read_text().splitlines(True),s.splitlines(True),fromfile='a/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp',tofile='b/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp')))
