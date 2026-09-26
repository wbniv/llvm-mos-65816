define i16 @wide_x() {
; REJECT-X: error: could not allocate output register for constraint 'x'
  %v = call i16 asm "", "=x"()
  ret i16 %v
}

