define i16 @wide_d() {
; REJECT-D: LLVM ERROR: unable to translate instruction: call{{.*}}wide_d
  %v = call i16 asm "", "=d"()
  ret i16 %v
}

