define i16 @wide_a() {
; REJECT-A: LLVM ERROR: unable to translate instruction: call{{.*}}wide_a
  %v = call i16 asm "", "=a"()
  ret i16 %v
}

