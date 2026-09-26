define void @many_virtual(ptr %p) {
  %v = load i4096, ptr %p
  call void asm sideeffect "", "r"(i4096 %v)
  ret void
}
