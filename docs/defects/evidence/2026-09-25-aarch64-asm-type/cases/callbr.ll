define i65 @branch() {
  %r = callbr i65 asm sideeffect "", "=r,!i"()
      to label %fallthrough [label %indirect]
fallthrough:
  ret i65 %r
indirect:
  ret i65 %r
}

