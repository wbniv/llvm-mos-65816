define void @output_r(ptr %p) {
  %v = call i4096 asm sideeffect "", "=r"()
  store i4096 %v, ptr %p
  ret void
}

