define i32 @named_rs() {
; REJECT-NAMED-RS: error: could not allocate output register for constraint '{rs0}'
  %v = call i32 asm "", "={rs0}"()
  ret i32 %v
}

