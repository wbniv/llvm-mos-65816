define i16 @wide_a() {
; REJECT-A: error: could not allocate output register for constraint 'a'
  %v = call i16 asm "", "=a"()
  ret i16 %v
}

