define void @f(ptr %p) {
  %v = load <2 x i64>, ptr %p
  call void asm sideeffect "", "r"(<2 x i64> %v)
  ret void
}
