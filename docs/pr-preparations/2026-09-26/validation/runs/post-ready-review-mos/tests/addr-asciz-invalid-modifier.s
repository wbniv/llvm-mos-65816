; RUN: not llvm-mc -triple mos -filetype=obj %s -o /dev/null 2>&1 | FileCheck %s

; Decimal ASCII encoding needs a character count and belongs to the directive.
; It cannot occupy a binary instruction operand through a modifier spelling.
lda addrasciz(symbol)
; CHECK: error: unknown modifier 'addrasciz'
