define void @f(ptr %p) { %v = call <2 x i64> asm sideeffect "", "=r"()
store <2 x i64> %v, ptr %p
ret void }
