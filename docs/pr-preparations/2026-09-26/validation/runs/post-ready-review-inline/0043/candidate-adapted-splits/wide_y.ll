define i16 @wide_y() {
; REJECT-Y: error: could not allocate output register for constraint 'y'
  %v = call i16 asm "", "=y"()
  ret i16 %v
}

