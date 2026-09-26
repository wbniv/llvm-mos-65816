define void @bad_input(i128 %v) {
  call void asm sideeffect "", "{cc}"(i128 %v)
  ret void
}
