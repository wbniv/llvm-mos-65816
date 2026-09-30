; Constant 70000-byte fill: 70000 = 0x11170 exceeds the 16-bit runtime length.
define void @big_const(ptr addrspace(2) %d) {
  call void @llvm.memset.p2.i32(ptr addrspace(2) %d, i8 0, i32 70000, i1 false)
  ret void
}
; Runtime i32 length with no proven bound.
define void @big_var(ptr addrspace(2) %d, ptr addrspace(2) %s, i32 %n) {
  call void @llvm.memcpy.p2.p2.i32(ptr addrspace(2) %d, ptr addrspace(2) %s, i32 %n, i1 false)
  ret void
}
; Exactly 65536 truncates to zero.
define void @len64k(ptr addrspace(2) %d, ptr %s) {
  call void @llvm.memmove.p2.p0.i32(ptr addrspace(2) %d, ptr %s, i32 65536, i1 false)
  ret void
}
declare void @llvm.memset.p2.i32(ptr addrspace(2), i8, i32, i1 immarg)
declare void @llvm.memcpy.p2.p2.i32(ptr addrspace(2), ptr addrspace(2), i32, i1 immarg)
declare void @llvm.memmove.p2.p0.i32(ptr addrspace(2), ptr, i32, i1 immarg)
