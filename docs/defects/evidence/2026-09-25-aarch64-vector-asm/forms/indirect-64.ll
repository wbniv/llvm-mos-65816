define void @f(ptr %p) { call void asm sideeffect "", "=*r"(ptr elementtype(<64 x i64>) %p)
ret void }
