; Apollo daylight reel: FastROM entry trampoline and the VBlank counter.
; Shape follows snes-video-reel-fast.s; symbols are distinct so both ROMs can
; be built and symbol-dumped in the same session.
.text
.global apollo_reel_enter_fast
.extern apollo_reel_run
apollo_reel_enter_fast:
  .byte $5c
  .word apollo_reel_run
  .byte $80

.global nmi
.extern apollo_reel_vblanks
nmi:
  php
  rep #$20
  pha
  lda apollo_reel_vblanks
  inc
  sta apollo_reel_vblanks
  bne .Lnmi_done
  lda apollo_reel_vblanks+2
  inc
  sta apollo_reel_vblanks+2
.Lnmi_done:
  pla
  plp
  rti
