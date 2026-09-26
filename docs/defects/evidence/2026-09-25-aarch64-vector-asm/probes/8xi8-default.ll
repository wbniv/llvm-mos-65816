define void @f(ptr %p) {
  %v = load <8 x i8>, ptr %p
  call void asm sideeffect "", "r"(<8 x i8> %v)
  ret void
}
