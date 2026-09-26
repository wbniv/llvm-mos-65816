@farword = external addrspace(2) global i16
@nearword = external global i16

define void @runtime_far_to_near(ptr addrspace(2) %src) {
  %v = load i16, ptr addrspace(2) %src, align 1
  store i16 %v, ptr @nearword, align 1
  ret void
}

define void @runtime_far_to_far(ptr addrspace(2) %src, ptr addrspace(2) %dst) {
  %v = load i16, ptr addrspace(2) %src, align 1
  store i16 %v, ptr addrspace(2) %dst, align 1
  ret void
}

define void @global_far_to_runtime(ptr addrspace(2) %dst) {
  %v = load i16, ptr addrspace(2) @farword, align 1
  store i16 %v, ptr addrspace(2) %dst, align 1
  ret void
}

define void @runtime_far_copy_order(ptr addrspace(2) %src, ptr addrspace(2) %dst) {
  %v = load i16, ptr addrspace(2) %src, align 1
  store volatile i16 4242, ptr addrspace(2) @farword, align 1
  store i16 %v, ptr addrspace(2) %dst, align 1
  ret void
}
