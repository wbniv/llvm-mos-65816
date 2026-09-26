define i16 @wide_R() {
; REJECT-R: error: could not allocate output register for constraint 'R'
  %v = call i16 asm "", "=R"()
  ret i16 %v
}

