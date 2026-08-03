/* Deliberately invalid control.  __rc0/__rc1 are llvm-mos's software-stack
   pointer, not call-clobbered scratch registers. */
.text
.global abi_conforming_call
abi_conforming_call:
  inc __rc0
  rts
