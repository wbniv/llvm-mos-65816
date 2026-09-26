define i128 @bad_output() {
  %v = call i128 asm sideeffect "", "={cc}"()
  ret i128 %v
}
