.text
.global video_reel_enter_fast
.extern video_reel_run
video_reel_enter_fast:
  .byte $5c
  .word video_reel_run
  .byte $80

.global nmi
.extern video_reel_vblanks
nmi:
  php
  rep #$20
  pha
  lda video_reel_vblanks
  inc
  sta video_reel_vblanks
  pla
  plp
  rti
