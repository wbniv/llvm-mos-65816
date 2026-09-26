define void @f(ptr %p) {
  %v = load <8 x i64>, ptr %p
  call void asm sideeffect "", "r"(<8 x i64> %v)
  ret void
}
