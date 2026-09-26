define i128 @bad_tied(i128 %v) {
  %r = call i128 asm sideeffect "", "={cc},0"(i128 %v)
  ret i128 %r
}
