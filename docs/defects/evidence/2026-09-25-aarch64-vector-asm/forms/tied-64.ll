define void @f(ptr %p) { %v = load <64 x i64>, ptr %p
%r = call <64 x i64> asm sideeffect "", "=r,0"(<64 x i64> %v)
store <64 x i64> %r, ptr %p
ret void }
