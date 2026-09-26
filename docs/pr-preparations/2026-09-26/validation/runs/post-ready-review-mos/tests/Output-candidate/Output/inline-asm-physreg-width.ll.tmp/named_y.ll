define i16 @named_y() {
; REJECT-NAMED-Y: LLVM ERROR: unable to translate instruction: call{{.*}}named_y
  %v = call i16 asm "", "={y}"()
  ret i16 %v
}

