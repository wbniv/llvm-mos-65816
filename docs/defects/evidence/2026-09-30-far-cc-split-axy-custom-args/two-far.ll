; Two far pointers under the opt-in split (+mos-farcc-split) or A:X+Y
; (+mos-farcc-axy) far-pointer calling convention.
define i8 @f(ptr addrspace(2) %a, ptr addrspace(2) %b) {
  %x = load volatile i8, ptr addrspace(2) %a
  %y = load volatile i8, ptr addrspace(2) %b
  %s = add i8 %x, %y
  ret i8 %s
}
