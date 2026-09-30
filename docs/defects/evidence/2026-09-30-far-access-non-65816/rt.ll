define i8 @ld_rt(ptr addrspace(2) %p) {
  %v = load i8, ptr addrspace(2) %p
  ret i8 %v
}
