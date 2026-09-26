define void @indirect(ptr %p) {
  call void asm sideeffect "", "=*r"(ptr elementtype(i65) %p)
  ret void
}

