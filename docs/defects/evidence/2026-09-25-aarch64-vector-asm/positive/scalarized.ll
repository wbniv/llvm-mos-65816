; With NEON disabled the integer vector breakdown uses matching scalar parts.
define void @scalarized(ptr %p) {
  %v = load <4 x i32>, ptr %p
  %r = call <4 x i32> asm sideeffect "", "=r,0"(<4 x i32> %v)
  store <4 x i32> %r, ptr %p
  ret void
}

