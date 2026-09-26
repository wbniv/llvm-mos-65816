define i16 @named_rc() {
; REJECT-NAMED-RC: error: could not allocate output register for constraint '{rc0}'
  %v = call i16 asm "", "={rc0}"()
  ret i16 %v
}

