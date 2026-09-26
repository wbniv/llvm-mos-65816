define i16 @named_cc() {
; REJECT-NAMED-CC: LLVM ERROR: unable to translate instruction: call{{.*}}named_cc
  %v = call i16 asm "", "={cc}"()
  ret i16 %v
}
