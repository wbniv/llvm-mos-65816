define i128 @wide() {
  %v = call i128 asm sideeffect "", "={x30}"()
  ret i128 %v
}
