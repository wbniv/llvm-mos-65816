; LS64 provides a register class for a 512-bit vector value.
define void @ls64(ptr %p) {
  %v = load <8 x i64>, ptr %p
  %r = call <8 x i64> asm sideeffect "", "=r,0"(<8 x i64> %v)
  store <8 x i64> %r, ptr %p
  ret void
}
