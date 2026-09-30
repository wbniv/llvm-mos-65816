; Control: a single far-pointer argument compiles.
define i8 @f(ptr addrspace(2) %a) {
  ret i8 0
}
