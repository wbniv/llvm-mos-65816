define i65 @tied(i65 %v) {
  %r = call i65 asm sideeffect "", "=r,0"(i65 %v)
  ret i65 %r
}

