define void @f(ptr %p) {
  %v = load <1 x i8>, ptr %p
  call void asm sideeffect "", "r"(<1 x i8> %v)
  ret void
}
