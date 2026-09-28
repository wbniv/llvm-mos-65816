from pathlib import Path
import subprocess,re
w=Path(__file__).resolve().parent
b=(w/'source/MOSLegalizerInfo.baseline.cpp').read_text()
e=(w.parent/'farblit-payoff/source/MOSLegalizerInfo.cpp').read_text()
h=e[e.index('// A single-block counting loop'):e.index('// The pointer add disappears')].replace('farLoopMax','getFarLoopMax').replace('farOffsetMax','getFarOffsetMax')
s=b.replace('#include "llvm/Support/ErrorHandling.h"','#include "llvm/Support/CommandLine.h"\n#include "llvm/Support/ErrorHandling.h"')
s=s.replace('// The pointer add disappears','static cl::opt<bool> FarLoopRange(\n    "mos-far-loop-range", cl::Hidden, cl::init(true),\n    cl::desc("Use bounded loop ranges for runtime far byte indexing"));\n\n'+h+'// The pointer add disappears',1)
s=s.replace('  const APInt MaxOffAP = VT->getKnownBits(Off).getMaxValue();\n  if (MaxOffAP.ugt(Limit))\n    return false;\n  const uint64_t MaxOff = MaxOffAP.getZExtValue();','  const uint64_t MaxOff = FarLoopRange\n      ? getFarOffsetMax(Off, MRI, *VT, *MI.getParent())\n      : VT->getKnownBits(Off).getMaxValue().getLimitedValue();\n  if (MaxOff > Limit)\n    return false;')
s=s.replace('// Fold a runtime byte offset only when its known-bits maximum plus the last','// Fold a runtime byte offset only when its proven maximum plus the last')
a=s.index('  if (Term == Loop.end() ||\n      (Term->getOpcode()');end=s.index('  auto End = getIConstantVRegValWithLookThrough',a)
# The final source contains the same narrowed proof body.
final=(w/'source/MOSLegalizerInfo.cpp').read_text();begin=final.index('  if (Term == Loop.end() || Term->getOpcode() != MOS::G_BRCOND_IMM');stop=final.index('  auto End = getIConstantVRegValWithLookThrough',begin)
# Reproduce the pre-format line wrapping for the original build.
body=final[begin:stop].replace('      Def->getOperand(4).getReg() != Flag ||\n      Def->getOperand(5).getReg() != Next)', '      Def->getOperand(4).getReg() != Flag || Def->getOperand(5).getReg() != Next)').replace('  auto Carry =\n      getIConstantVRegValWithLookThrough','  auto Carry = getIConstantVRegValWithLookThrough')
s=s[:a]+body+s[end:]
s=s.replace('// every header value lies in [Start, End); the recurrence cannot wrap.','// every header value lies in [Start, End); the recurrence cannot wrap.\n// Match the byte comparison after branch legalization as an SBC zero flag.')
p=w/'source/MOSLegalizerInfo.candidate-reconstructed.cpp';p.write_text(s)
subprocess.run([str(w.parent/'farblit-payoff/build/bin/clang-format'),'-i','--lines=3126:3237',str(p)],check=True)
assert re.sub(r'\s+','',p.read_text())==re.sub(r'\s+','',final)
print('candidate reconstruction and production source differ only in whitespace')
