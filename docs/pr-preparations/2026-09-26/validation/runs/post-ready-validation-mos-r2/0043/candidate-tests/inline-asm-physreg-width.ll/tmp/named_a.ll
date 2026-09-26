define i16 @named_a() {
; REJECT-NAMED-A: error: could not allocate output register for constraint '{a}'
  %v = call i16 asm "", "={a}"()
  ret i16 %v
}

