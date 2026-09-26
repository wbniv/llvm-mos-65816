; Unknown value types remain usable as memory operands, and named register
; clobbers do not require a value type. Supported r/x operands retain their types.
define i64 @gpr(i32 %a, i64 %b) {
  %r = call i64 asm sideeffect "", "=r,r,0,~{x0},~{v0},~{cc}"(i32 %a, i64 %b)
  ret i64 %r
}

define <2 x i64> @simd(<2 x i64> %v) {
  %r = call <2 x i64> asm sideeffect "", "=x,0"(<2 x i64> %v)
  ret <2 x i64> %r
}

define void @memory(ptr %p) {
  %v = load i4096, ptr %p
  call void asm sideeffect "", "m"(i4096 %v)
  call void asm sideeffect "", "=*m"(ptr elementtype(i4096) %p)
  ret void
}
