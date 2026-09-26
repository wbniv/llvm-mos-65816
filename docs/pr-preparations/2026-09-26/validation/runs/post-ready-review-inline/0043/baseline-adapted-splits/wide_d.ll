define i16 @wide_d() {
; REJECT-D: error: could not allocate output register for constraint 'd'
  %v = call i16 asm "", "=d"()
  ret i16 %v
}

