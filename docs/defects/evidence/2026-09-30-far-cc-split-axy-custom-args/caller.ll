; Caller side: pass a far pointer and an i8 to a callee.
declare i8 @g(ptr addrspace(2), i8)
define i8 @f(ptr addrspace(2) %a) {
  %r = call i8 @g(ptr addrspace(2) %a, i8 7)
  ret i8 %r
}
