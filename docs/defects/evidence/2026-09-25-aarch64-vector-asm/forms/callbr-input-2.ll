define i64 @f(ptr %p) { %v = load <2 x i64>, ptr %p
%r = callbr i64 asm sideeffect "", "=r,r,!i"(<2 x i64> %v) to label %fallthrough [label %indirect]
fallthrough: ret i64 %r
indirect: ret i64 %r }
