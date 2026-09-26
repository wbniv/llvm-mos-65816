define i16 @named_cc() {
; REJECT-NAMED-CC: error: could not allocate output register for constraint '{cc}'
  %v = call i16 asm "", "={cc}"()
  ret i16 %v
}
