define i64 @bad_callbr_input(i128 %v) {
entry:
  %r = callbr i64 asm sideeffect "", "=r,{cc},!i"(i128 %v)
          to label %direct [label %indirect]
direct:
  ret i64 %r
indirect:
  ret i64 %r
}
