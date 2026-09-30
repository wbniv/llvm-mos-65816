; A far pointer followed by an i8 argument: no register exhaustion.
define i8 @f(ptr addrspace(2) %a, i8 %b) {
  ret i8 %b
}
