define i16 @wide_R() {
; REJECT-R: LLVM ERROR: unable to translate instruction: call{{.*}}wide_R
  %v = call i16 asm "", "=R"()
  ret i16 %v
}

