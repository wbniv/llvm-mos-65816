define i16 @named_x() {
; REJECT-NAMED-X: LLVM ERROR: unable to translate instruction: call{{.*}}named_x
  %v = call i16 asm "", "={x}"()
  ret i16 %v
}

