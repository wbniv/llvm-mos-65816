#!/usr/bin/env python3
"""Generate far-fold-debug.ll for one stage of the #320 series (B8 regressions).

usage: gen-far-fold-debug.py STAGE > far-fold-debug.ll
  STAGE  320-2 (absolute long), 320-4 (+ displacement window), fw-5
         (+ absolute indexed)
Each section is a -g function whose far access is folded into an addressing
mode that erases the G_PTR_ADD a DBG_VALUE refers to. Every section compiles
verifier-clean in +mos-a16 and +mos-a16,+mos-xy16 (and plain mosw65816 unless
it needs a zero-extended runtime offset) at O0 and O2. At O0, after the
legalizer, a dead address that is a live base plus a constant is salvaged to
that base with DW_OP_plus_uconst (320-4 on, where the base stays live), and
every other dead address's DBG_VALUE is $noreg.
"""
import sys

if len(sys.argv) != 2 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip()); sys.exit(0)
stage = sys.argv[1]

META = '''
declare void @llvm.dbg.value(metadata, metadata, metadata)

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}
!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "test", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "far.c", directory: "/tmp")
!2 = !{i32 2, !"Dwarf Version", i32 4}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!10 = distinct !DISubprogram(name: "walk", scope: !1, file: !1, line: 1, type: !11, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!11 = !DISubroutineType(types: !12)
!12 = !{null}
!13 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_unsigned_char)
!14 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !13, size: 32)
!17 = !DILocalVariable(name: "q", scope: !10, file: !1, line: 3, type: !14)
!20 = !DILocation(line: 2, scope: !10)
'''

SECTIONS = [
    ('320-2', 'global-field', 'a far global plus a constant, folded into absolute-long addressing', '''@g = external addrspace(2) global [16 x i8]

define i8 @walk() !dbg !10 {
  %q = getelementptr i8, ptr addrspace(2) @g, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
}
'''),
    ('320-4', 'field', 'a runtime far pointer plus 1, folded into the [dp],Y displacement window', '''define i8 @walk(ptr addrspace(2) %base) !dbg !10 {
  %q = getelementptr i8, ptr addrspace(2) %base, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
}
'''),
    ('320-4', 'store-field', 'a store through a runtime far pointer plus 3 (displacement window)', '''define void @walk(ptr addrspace(2) %base, i8 %v) !dbg !10 {
  %q = getelementptr i8, ptr addrspace(2) %base, i32 3
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  store i8 %v, ptr addrspace(2) %q, !dbg !20
  ret void, !dbg !20
}
'''),
    ('320-4', 'offset-field', 'a runtime offset plus 1 from a runtime far pointer; the window keeps the runtime add live, so the location is salvaged off it', '''define i8 @walk(ptr addrspace(2) %base, i8 %n) !dbg !10 {
  %off = zext i8 %n to i32
  %p = getelementptr i8, ptr addrspace(2) %base, i32 %off
  %q = getelementptr i8, ptr addrspace(2) %p, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
}
'''),
    ('fw-5', 'global-index', 'a far global indexed by a zero-extended byte, folded into absolute-long indexed addressing', '''@g = external addrspace(2) global [16 x i8]

define i8 @walk(i8 %i) !dbg !10 {
  %off = zext i8 %i to i32
  %q = getelementptr i8, ptr addrspace(2) @g, i32 %off
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
}
'''),
]
order = ['320-2', '320-4', 'fw-5']
active = [s for s in SECTIONS if order.index(s[0]) <= order.index(stage)]

out = ['; RUN: split-file %s %t']
# A zero-extended runtime offset needs +mos-a16 lanes (plain mosw65816 cannot
# legalize the s32 merge), so those sections skip the plain runs.
NATIVE_ONLY = {'offset-field', 'global-index'}
# Sections whose address is a live runtime base plus a constant are salvaged:
# field and store-field off the incoming pointer; offset-field off the live
# runtime add (base + offset) that the displacement window keeps.
SALVAGE = {'field': 1, 'store-field': 3, 'offset-field': 1}
for name, *_ in [(s[1],) for s in active]:
    prefix = f'SALV{SALVAGE[name]}' if name in SALVAGE else 'DROP'
    out.append(f'; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O0 -verify-machineinstrs -stop-after=legalizer %t/{name}.ll -o - | FileCheck %s --check-prefix={prefix}')
    for attrs in (('',) if name not in NATIVE_ONLY else ()) + (' -mattr=+mos-a16', ' -mattr=+mos-a16,+mos-xy16'):
        for opt in ('O0', 'O2'):
            out.append(f'; RUN: llc -mtriple=mos -mcpu=mosw65816{attrs} -{opt} -verify-machineinstrs %t/{name}.ll -o /dev/null')
out.append('''
; A far addressing-mode fold replaces an access's pointer with a base and an
; offset the new instruction encodes, so the G_PTR_ADDs that computed the
; pointer die. salvageDebugInfo cannot express a G_PTR_ADD, so the fold
; rewrites each remaining DBG_VALUE of those adds instead of leaving it on an
; erased register, which the verifier rejects under -g: to the live base plus
; the constant offset where there is one (SALV), otherwise to $noreg (DROP,
; for a folded global base or an address with a runtime offset).
; Sections:''')
for _, name, desc, _ in active:
    out.append(f';   {name}: {desc}.')
out.append('''
; DROP-LABEL: name: walk
; DROP: DBG_VALUE $noreg, $noreg, !{{[0-9]+}}, !DIExpression()
; DROP-NOT: G_PTR_ADD''')
for off in sorted({v for k, v in SALVAGE.items() if k in [s[1] for s in active]}):
    out.append(f'''
; SALV{off}-LABEL: name: walk
; SALV{off}: DBG_VALUE %{{{{[0-9]+}}}}(p2), $noreg, !{{{{[0-9]+}}}}, !DIExpression(DW_OP_plus_uconst, {off}, DW_OP_stack_value)
; SALV{off}-NOT: G_PTR_ADD''')
for _, name, _, ir in active:
    out.append(f'\n;--- {name}.ll')
    out.append(ir.rstrip('\n') + '\n' + META.rstrip('\n'))
sys.stdout.write('\n'.join(out) + '\n')
