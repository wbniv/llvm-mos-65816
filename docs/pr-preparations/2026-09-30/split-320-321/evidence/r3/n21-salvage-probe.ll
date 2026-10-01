target triple = "mos"
declare void @sink(ptr addrspace(2))
define void @f(ptr addrspace(2) %p) !dbg !5 {
  %q = getelementptr i8, ptr addrspace(2) %p, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %p, metadata !9, metadata !DIExpression(DW_OP_plus_uconst, 1)), !dbg !11
  call void @sink(ptr addrspace(2) %p), !dbg !11
  call void @llvm.dbg.value(metadata ptr addrspace(2) %p, metadata !9, metadata !DIExpression(DW_OP_plus_uconst, 1)), !dbg !11
  ret void, !dbg !11
}
declare void @llvm.dbg.value(metadata, metadata, metadata)
!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4}
!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "t", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "s.c", directory: "/")
!3 = !{i32 2, !"Dwarf Version", i32 5}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = distinct !DISubprogram(name: "f", scope: !1, file: !1, line: 1, type: !6, unit: !0, spFlags: DISPFlagDefinition | DISPFlagOptimized, retainedNodes: !8)
!6 = !DISubroutineType(types: !7)
!7 = !{null}
!8 = !{!9}
!9 = !DILocalVariable(name: "q", scope: !5, file: !1, line: 1, type: !10)
!10 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: null, size: 32, dwarfAddressSpace: 2)
!11 = !DILocation(line: 1, scope: !5)
