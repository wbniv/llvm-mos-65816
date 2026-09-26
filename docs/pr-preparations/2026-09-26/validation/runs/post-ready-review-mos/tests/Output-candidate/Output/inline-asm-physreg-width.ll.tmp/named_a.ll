define i16 @named_a() {
; REJECT-NAMED-A: LLVM ERROR: unable to translate instruction: call{{.*}}named_a
  %v = call i16 asm "", "={a}"()
  ret i16 %v
}

