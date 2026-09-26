define i16 @wide_x() {
; REJECT-X: LLVM ERROR: unable to translate instruction: call{{.*}}wide_x
  %v = call i16 asm "", "=x"()
  ret i16 %v
}

