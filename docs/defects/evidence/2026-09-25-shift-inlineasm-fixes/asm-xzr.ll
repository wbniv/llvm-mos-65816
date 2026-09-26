define i128 @wide() {
  %v = call i128 asm sideeffect "", "={xzr}"()
  ret i128 %v
}
