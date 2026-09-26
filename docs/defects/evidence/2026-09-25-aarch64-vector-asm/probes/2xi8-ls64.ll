define void @f(ptr %p) {
  %v = load <2 x i8>, ptr %p
  call void asm sideeffect "", "r"(<2 x i8> %v)
  ret void
}
