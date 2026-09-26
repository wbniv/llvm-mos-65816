define i128 @wide() {
  %v = call i128 asm sideeffect "", "={x28}"()
  ret i128 %v
}
