; Four far pointers: the fourth exceeds RL1..RL3.
define i8 @callee4(ptr addrspace(2) %a, ptr addrspace(2) %b, ptr addrspace(2) %c, ptr addrspace(2) %d) {
  %va = load volatile i8, ptr addrspace(2) %a
  %vd = load volatile i8, ptr addrspace(2) %d
  %s = add i8 %va, %vd
  ret i8 %s
}
define i8 @caller4(ptr addrspace(2) %a, ptr addrspace(2) %b, ptr addrspace(2) %c, ptr addrspace(2) %d) {
  %r = call i8 @callee4(ptr addrspace(2) %d, ptr addrspace(2) %c, ptr addrspace(2) %b, ptr addrspace(2) %a)
  ret i8 %r
}
