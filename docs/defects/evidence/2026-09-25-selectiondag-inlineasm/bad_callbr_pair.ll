define { i64, i128 } @bad_callbr_pair() {
entry:
  %r = callbr { i64, i128 } asm sideeffect "", "=r,={cc},!i"()
          to label %direct [label %indirect]
direct:
  ret { i64, i128 } %r
indirect:
  ret { i64, i128 } %r
}
