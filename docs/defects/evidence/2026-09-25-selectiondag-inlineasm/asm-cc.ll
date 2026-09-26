define i128 @wide() {
  %v = call i128 asm sideeffect "", "={cc}"()
  ret i128 %v
}
