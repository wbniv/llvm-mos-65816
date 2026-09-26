define void @f(ptr %p) {
  %v = load <4 x i32>, ptr %p
  call void asm sideeffect "", "r"(<4 x i32> %v)
  ret void
}
