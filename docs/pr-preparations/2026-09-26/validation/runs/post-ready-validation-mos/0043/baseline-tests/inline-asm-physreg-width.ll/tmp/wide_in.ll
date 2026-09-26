; The input direction is rejected for the same reason as the output direction.
define void @wide_in(i16 %x) {
; REJECT-IN: LLVM ERROR: unable to translate instruction: call{{.*}}wide_in
  call void asm "", "a"(i16 %x)
  ret void
}

