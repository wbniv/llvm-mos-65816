define void @f(ptr %p) { %r = callbr <64 x i64> asm sideeffect "", "=r,!i"() to label %fallthrough [label %indirect]
fallthrough: store <64 x i64> %r, ptr %p
ret void
indirect: store <64 x i64> %r, ptr %p
ret void }
