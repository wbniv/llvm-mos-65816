define void @f(ptr %p) {
  %v = load <64 x i64>, ptr %p
  call void asm sideeffect "", "r"(<64 x i64> %v)
  ret void
}
