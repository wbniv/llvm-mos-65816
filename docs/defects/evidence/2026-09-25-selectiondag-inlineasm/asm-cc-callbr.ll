define i128 @bad_callbr() {
entry:
  %r = callbr i128 asm sideeffect "", "={cc},!i"()
          to label %direct [label %indirect]
direct:
  ret i128 %r
indirect:
  ret i128 %r
}
