define i32 @named_rs() {
; REJECT-NAMED-RS: LLVM ERROR: unable to translate instruction: call{{.*}}named_rs
  %v = call i32 asm "", "={rs0}"()
  ret i32 %v
}

