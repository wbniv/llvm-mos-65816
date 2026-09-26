define i16 @named_rc() {
; REJECT-NAMED-RC: LLVM ERROR: unable to translate instruction: call{{.*}}named_rc
  %v = call i16 asm "", "={rc0}"()
  ret i16 %v
}

