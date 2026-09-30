@g = external addrspace(2) global [16 x i8]
define i8 @walk() !dbg !10 {
  %q = getelementptr i8, ptr addrspace(2) @g, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
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
!17 = !DILocalVariable(name: "q", scope: !10, file: !1, line: 3, type: !14)
!18 = !DIBasicType(name: "short", size: 16, encoding: DW_ATE_signed)
!19 = !DILocalVariable(name: "w", scope: !10, file: !1, line: 4, type: !18)
!20 = !DILocation(line: 2, scope: !10)
