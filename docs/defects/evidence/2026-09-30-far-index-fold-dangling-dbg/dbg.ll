@sink = external global i16

define void @walk(ptr addrspace(2) %base, i8 %n) !dbg !10 {
entry:
  call void @llvm.dbg.value(metadata ptr addrspace(2) %base, metadata !15, metadata !DIExpression()), !dbg !20
  br label %loop
loop:
  %i = phi i8 [ 0, %entry ], [ %next, %loop ]
  %acc = phi i16 [ 0, %entry ], [ %sum, %loop ]
  %off = zext i8 %i to i32
  %p = getelementptr i8, ptr addrspace(2) %base, i32 %off
  call void @llvm.dbg.value(metadata ptr addrspace(2) %p, metadata !16, metadata !DIExpression()), !dbg !20
  %w = load i16, ptr addrspace(2) %p, align 1, !dbg !20
  %sum = add i16 %acc, %w, !dbg !20
  %next = add i8 %i, 1
  %done = icmp eq i8 %next, 100
  br i1 %done, label %exit, label %loop
exit:
  store volatile i16 %sum, ptr @sink, !dbg !20
  ret void, !dbg !20
}

define i32 @mkfar(i16 %lo, i8 %bank) !dbg !30 {
  %l = zext i16 %lo to i32
  %b = zext i8 %bank to i32
  %h = shl i32 %b, 16
  %a = or i32 %l, %h
  %p = inttoptr i32 %a to ptr addrspace(2)
  call void @llvm.dbg.value(metadata ptr addrspace(2) %p, metadata !31, metadata !DIExpression()), !dbg !32
  %v = load volatile i8, ptr addrspace(2) %p, !dbg !32
  %r = zext i8 %v to i32
  ret i32 %r
}

declare void @llvm.dbg.value(metadata, metadata, metadata)

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}
!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "probe", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "dbg.c", directory: "/tmp")
!2 = !{i32 2, !"Dwarf Version", i32 4}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!10 = distinct !DISubprogram(name: "walk", scope: !1, file: !1, line: 1, type: !11, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!11 = !DISubroutineType(types: !12)
!12 = !{null}
!13 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_unsigned_char)
!14 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !13, size: 32)
!15 = !DILocalVariable(name: "base", arg: 1, scope: !10, file: !1, line: 1, type: !14)
!16 = !DILocalVariable(name: "p", scope: !10, file: !1, line: 2, type: !14)
!20 = !DILocation(line: 2, scope: !10)
!30 = distinct !DISubprogram(name: "mkfar", scope: !1, file: !1, line: 10, type: !11, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!31 = !DILocalVariable(name: "q", scope: !30, file: !1, line: 11, type: !14)
!32 = !DILocation(line: 11, scope: !30)
