#!/usr/bin/env python3
import sys
out=sys.argv[1]
n=int(sys.argv[2]) if len(sys.argv)>2 else 131100
with open(out,"w") as f:
 f.write('.section .far_rodata,"a",@progbits\n.global bankwalk_table\nbankwalk_table:\n')
 for base in range(0,n,32):
  vals=[(i^(i>>8)^((i>>16)*0x5b))&255 for i in range(base,min(base+32,n))]
  f.write('  .byte '+','.join('0x%02x'%v for v in vals)+'\n')
