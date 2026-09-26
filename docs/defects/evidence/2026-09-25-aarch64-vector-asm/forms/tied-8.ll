define void @f(ptr %p) { %v = load <8 x i64>, ptr %p
%r = call <8 x i64> asm sideeffect "", "=r,0"(<8 x i64> %v)
store <8 x i64> %r, ptr %p
ret void }
