.text
.global video_reel_enter_fast
.extern video_reel_run
video_reel_enter_fast:
  .byte $5c
  .word video_reel_run
  /* Banks $C0-$FF are FastROM-visible in both HiROM and ExHiROM.  Bank $80
     mirrors the near window in HiROM, but selects ExHiROM region A instead
     of the boot/code window in region B. */
  .byte $c0

.global nmi
.extern video_reel_vblanks
nmi:
  php
  rep #$20
  pha
  lda video_reel_vblanks
  inc
  sta video_reel_vblanks
  bne .Lnmi_done
  lda video_reel_vblanks+2
  inc
  sta video_reel_vblanks+2
.Lnmi_done:
  pla
  plp
  rti
