; The input direction is rejected for the same reason as the output direction.
define void @wide_in(i16 %x) {
; REJECT-IN: error: could not allocate input reg for constraint 'a'
  call void asm "", "a"(i16 %x)
  ret void
}

