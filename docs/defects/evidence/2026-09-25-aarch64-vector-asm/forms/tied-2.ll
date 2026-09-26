define void @f(ptr %p) { %v = load <2 x i64>, ptr %p
%r = call <2 x i64> asm sideeffect "", "=r,0"(<2 x i64> %v)
store <2 x i64> %r, ptr %p
ret void }
