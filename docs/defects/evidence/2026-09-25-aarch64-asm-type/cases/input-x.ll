define void @input_x(ptr %p) {
  %v = load i4096, ptr %p
  call void asm sideeffect "", "x"(i4096 %v)
  ret void
}

