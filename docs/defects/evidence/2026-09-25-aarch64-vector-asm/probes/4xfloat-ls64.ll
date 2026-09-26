define void @f(ptr %p) {
  %v = load <4 x float>, ptr %p
  call void asm sideeffect "", "r"(<4 x float> %v)
  ret void
}
