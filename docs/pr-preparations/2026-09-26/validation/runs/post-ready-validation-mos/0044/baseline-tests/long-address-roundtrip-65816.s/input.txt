# RUN: llvm-mc -triple mos -mcpu=mosw65816 -disassemble %s | FileCheck %s
# RUN: llvm-mc -triple mos -mcpu=mosw65816 -disassemble %s \
# RUN:   | llvm-mc -triple mos -mcpu=mosw65816 -show-encoding | FileCheck %s --check-prefix=RT

# A 24-bit address has to be printed with an explicit width, or the assembly
# does not survive being read back: a bare operand matches the narrowest
# candidate, so a far load collapses to a zero page or absolute one (losing its
# bank byte and becoming DBR-relative) and a $5C long jump collapses to a $4C
# bank-local one. $5C has no mnemonic of its own -- it is spelled "jmp", like
# $4C -- so the operand's modifier is what keeps the two apart.

# absolute long, bank 0: without mos24() this reads back as `lda <240` ($a5).
0xaf,0xf0,0x00,0x00
# CHECK: lda mos24(240)
# RT: encoding: [0xaf,0xf0,0x00,0x00]

0x8f,0xf0,0x00,0x00
# CHECK: sta mos24(240)
# RT: encoding: [0x8f,0xf0,0x00,0x00]

# absolute long,X in the 16-bit range: without mos24() this reads back as
# `lda $abcd,x` ($bd), three bytes instead of four.
0xbf,0xcd,0xab,0x00
# CHECK: lda mos24(43981),x
# RT: encoding: [0xbf,0xcd,0xab,0x00]

# the long jump: without mos24() this reads back as $4c, a jump inside the
# current program bank rather than to bank 0 -- a different destination.
0x5c,0xf0,0x00,0x00
# CHECK: jmp mos24(240)
# RT: encoding: [0x5c,0xf0,0x00,0x00]

# jsl has no narrower form to collapse into, but is marked for consistency.
0x22,0xf0,0x00,0x00
# CHECK: jsl mos24(240)
# RT: encoding: [0x22,0xf0,0x00,0x00]

# An address that cannot fit a 16-bit operand already states its own width, so
# it stays bare and ordinary disassembly does not grow a wrapper.
0xaf,0xea,0xea,0xea
# CHECK: lda 15395562
# CHECK-NOT: mos24
# RT: encoding: [0xaf,0xea,0xea,0xea]

0x5c,0xea,0xea,0xea
# CHECK: jmp 15395562
# RT: encoding: [0x5c,0xea,0xea,0xea]

# The modifier is idempotent: re-printing an operand that already carries one
# must not wrap it a second time.
# RT-NOT: mos24(mos24(
