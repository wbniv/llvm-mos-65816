define void @f(ptr %p) { %v = call <64 x i64> asm sideeffect "", "=r"()
store <64 x i64> %v, ptr %p
ret void }
