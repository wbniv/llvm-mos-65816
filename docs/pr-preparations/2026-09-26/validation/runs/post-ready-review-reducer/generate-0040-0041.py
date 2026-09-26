#!/usr/bin/env python3
"""Render reviewed current-base package candidates on stdout, without writes."""
from pathlib import Path
import difflib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PKG = 'docs/pr-preparations/2026-09-26/'
result = {}

def diff(name, old, new):
    head = f'diff --git a/{name} b/{name}\n'
    if not old:
        head += 'new file mode 100644\n'
    return head + ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                         fromfile='a/' + name if old else '/dev/null', tofile='b/' + name))

def replace(text, old, new):
    assert text.count(old) == 1, (text.count(old), old)
    return text.replace(old, new)

name = 'llvm/lib/CodeGen/InlineSpiller.cpp'
old = (ROOT / 'build/post-ready-2026-09-26-isolated-src' / name).read_text()
new = replace(old, '''  // We have a stack access. Is it the right register and slot?
  if (InstrReg != Reg || FI != StackSlot)
    return false;
''', '''  // We have a stack access. Is it the right register and slot?
  if (InstrReg != Reg || FI != StackSlot)
    return false;

  // Extra virtual defs can already have allocator assignments. Their defining
  // instruction must remain present while those assignments refer to its slot
  // index. Keep the access and let spillAroundUses rewrite the spilled value.
  for (const MachineOperand &MO : MI->all_defs())
    if (MO.getReg().isVirtual() && MO.getReg() != Reg)
      return false;
''')
mir = (ROOT / 'build/post-ready-review-reducer/review-0040-0041/0040-pre-greedy.mir').read_text()
mir = re.sub(r'^  ; ModuleID = .*\n', '', mir, flags=re.M)
mir = re.sub(r'^  source_filename = .*\n', '  source_filename = "scratch-vreg-coalesce"\n', mir, flags=re.M)
mir = ''.join(line.rstrip() + '\n' for line in mir.splitlines())
mir = '''# RUN: llc -mtriple=mos -mcpu=mos65c02 -O2 -run-pass=greedy -disable-spill-hoist -verify-machineinstrs %s -o /dev/null
# RUN: llc -mtriple=mos -mcpu=mos65c02 -O2 -start-before=greedy -disable-spill-hoist -verify-machineinstrs %s -o - | FileCheck %s
#
# Reloads can define an early-clobber scratch pointer in addition to the loaded
# value. A scratch register's allocator assignment requires its defining
# instruction to remain present when the loaded value is spilled again.
# Keep the jump-table register-pressure shape fixed at the greedy boundary.
# Spill hoisting is disabled to isolate stack-access coalescing.
# CHECK-LABEL: constant_shift:

''' + mir
result[PKG + '0040-llvm-mos.patch'] = diff(name, old, new) + diff(
    'llvm/test/CodeGen/MOS/inline-spiller-coalesce-scratch-vreg.mir', '', mir)
result['build/post-ready-review-reducer/0040-packet.mir'] = mir

patch = (ROOT / 'docs/pr-preparations/2026-09-24/0041-llvm-project.patch').read_text()
sections = patch.split('diff --git ')[1:]
source = sections[0]
hunks = re.split(r'^@@.*@@.*\n', source, flags=re.M)[1:]
oldparts = [''.join(l[1:] for l in h.splitlines(True) if l[:1] in [' ', '-']) for h in hunks]
newparts = [''.join(l[1:] for l in h.splitlines(True) if l[:1] in [' ', '+']) for h in hunks]
name = 'llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp'
old = (ROOT / 'build/post-ready-2026-09-26-llvm-src' / name).read_text()
new = old
for i, (a, b) in enumerate(zip(oldparts, newparts)):
    if i == 1:
        a = re.sub(r'        unsigned NumOpRegs =.*?                                 "not supported in GlobalISel inline asm"\);\n',
                   '        assert(getNumOpRegs(*Inst, InstFlagIdx) == 1 && "Wrong flag");\n', a, flags=re.S)
    if i == len(hunks) - 1:
        tail = '''      } else if (ResTy.isScalar() && ResTy.getSizeInBits() > SrcSize) {
         Register Tmp = SrcReg;
         if (!MRI->getType(SrcReg).isValid())
'''
        assert a.endswith(tail) and b.endswith(tail)
        a = a[:-len(tail)]
        b = b[:-len(tail)]
    new = replace(new, a, b)

# LLVM's single-register output contract does not include MOS's ANYEXT path.
new = replace(new, '''        MIRBuilder.buildTrunc(ResRegs[i], Tmp);
      } else if (ResTy.getSizeInBits() == SrcSize) {''', '''        MIRBuilder.buildTrunc(ResRegs[i], Tmp);
      } else if (OpInfo.Regs.size() > 1 && ResTy.isScalar() &&
                 ResTy.getSizeInBits() > SrcSize) {
        // The constraint can provide fewer bits than the scalar result type.
        // Only the merged pieces are defined; the remaining high bits are undef.
        MIRBuilder.buildAnyExt(ResRegs[i], SrcReg);
      } else if (ResTy.getSizeInBits() == SrcSize) {''')
new = new.replace('and that path has no coverage here.', 'and require a different piece order.')
new = new.replace('instead; it costs nothing after legalization.', 'instead.')
contents = diff(name, old, new)
for section in sections[1:]:
    name = section.splitlines()[0].split(' b/')[1]
    if '--- /dev/null\n' in section:
        oldtest = ''
        newtest = ''.join(l[1:] + '\n' for l in section.splitlines() if l.startswith('+') and not l.startswith('+++'))
        newtest = newtest.replace('-O0 ', '-O0 -verify-machineinstrs ')
        newtest = newtest.replace('\n\n; AArch64 selects', '\n; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O2 -verify-machineinstrs -stop-after=irtranslator < %s | FileCheck %s\n; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O2 -verify-machineinstrs < %s -o /dev/null\n\n; AArch64 selects')
        newtest = newtest.replace('; CHECK: %{{[0-9]+}}:_(i64) = G_MERGE_VALUES [[L0]](i32), [[L1]](i32)',
                                  '; CHECK: [[MERGED:%[0-9]+]]:_(i64) = G_MERGE_VALUES [[L0]](i32), [[L1]](i32)\n; CHECK: %{{[0-9]+}}:_(i128) = G_ANYEXT [[MERGED]](i64)')
        result['build/post-ready-review-reducer/0041-packet.ll'] = newtest
    else:
        oldtest = (ROOT / 'build/post-ready-2026-09-26-llvm-src' / name).read_text()
        newtest = oldtest
        for h in re.split(r'^@@.*@@.*\n', section, flags=re.M)[1:]:
            a = ''.join(l[1:] for l in h.splitlines(True) if l[:1] in [' ', '-'])
            b = ''.join(l[1:] for l in h.splitlines(True) if l[:1] in [' ', '+'])
            newtest = replace(newtest, a, b)
        if name.endswith('/build-pair-isel.ll'):
            newtest = replace(oldtest, '; RUN: llc -mtriple=aarch64 -o - -O0 %s | FileCheck %s\n',
                              '; RUN: llc -mtriple=aarch64 -o - -O0 -global-isel=0 %s | FileCheck %s\n; RUN: llc -mtriple=aarch64 -O0 -global-isel=1 -global-isel-abort=1 -verify-machineinstrs %s -o /dev/null\n')
    contents += diff(name, oldtest, newtest)
result[PKG + '0041-llvm-project.patch'] = contents
print(json.dumps(result))
