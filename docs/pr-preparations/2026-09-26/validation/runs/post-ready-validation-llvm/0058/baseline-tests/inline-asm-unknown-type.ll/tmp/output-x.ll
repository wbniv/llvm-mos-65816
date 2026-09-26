define void @output_x(ptr %p) {
  %v = call i4096 asm sideeffect "", "=x"()
  store i4096 %v, ptr %p
  ret void
}

