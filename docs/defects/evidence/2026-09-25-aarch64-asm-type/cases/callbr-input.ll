define i64 @branch_input(i65 %v) {
  %r = callbr i64 asm sideeffect "", "=r,r,!i"(i65 %v)
      to label %fallthrough [label %indirect]
fallthrough:
  ret i64 %r
indirect:
  ret i64 %r
}

