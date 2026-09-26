define void @bad_indirect(ptr %p) {
  call void asm sideeffect "", "=*{cc}"(ptr elementtype(i128) %p)
  ret void
}
