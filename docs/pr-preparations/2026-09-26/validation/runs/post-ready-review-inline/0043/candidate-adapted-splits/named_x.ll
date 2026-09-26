define i16 @named_x() {
; REJECT-NAMED-X: error: could not allocate output register for constraint '{x}'
  %v = call i16 asm "", "={x}"()
  ret i16 %v
}

