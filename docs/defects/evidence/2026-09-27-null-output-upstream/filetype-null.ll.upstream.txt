; RUN: llc -mtriple=mos -mcpu=mos6502 -debug-pass=Structure -filetype=null %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=PASS
; RUN: llc -mtriple=mos -mcpu=mos6502 -filetype=obj %s -o /dev/null

; Null emission must provide the MOS target streamer used during asm-printer
; initialization while discarding all emitted directives.
; PASS: Free MachineFunction

define void @f() {
  ret void
}
