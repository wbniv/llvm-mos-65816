define void @f(ptr %p) { call void asm sideeffect "", "=*r"(ptr elementtype(<2 x i64>) %p)
ret void }
