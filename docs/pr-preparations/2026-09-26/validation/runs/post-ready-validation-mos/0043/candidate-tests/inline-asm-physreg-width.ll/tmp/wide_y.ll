define i16 @wide_y() {
; REJECT-Y: LLVM ERROR: unable to translate instruction: call{{.*}}wide_y
  %v = call i16 asm "", "=y"()
  ret i16 %v
}

