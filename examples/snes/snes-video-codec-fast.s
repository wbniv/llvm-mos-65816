.text
.global video_bench_enter_fast
.extern video_bench_run
video_bench_enter_fast:
  .byte $5c /* JML $80:video_bench_run: execute the LoROM mirror at FastROM speed. */
  .word video_bench_run
  .byte $80

.global svc_copy_frame_asm
.global svx_asm_source
.global svx_asm_output
svc_copy_frame_asm:
  php
  phb
  rep #$30
  phx
  phy
  lda #4479
  ldx svx_asm_source
  ldy svx_asm_output
  .byte $54,$00,$00 /* MVN $00,$00. */
  ply
  plx
  plb
  plp
  rts

.global svx_decode_payload_asm
svx_decode_payload_asm:
  php
  phb
  rep #$30
  phx
  phy
  /* __rc0 is the llvm-mos software-stack pointer while the caller has a
     frame. Preserve it even though this decoder uses __rc0 as its cursor. */
  lda __rc0
  pha
  lda svx_asm_source
  sta __rc0
  lda svx_asm_previous
  sta __rc2
  lda svx_asm_output
  sta __rc4
  lda #4480
  sta __rc6
  stz __rc8 /* Count high byte stays zero; the 8-bit path writes only __rc8. */
  sep #$20
  lda svx_asm_keyframe
  bne .Lsvx_key_token
  rep #$20
  lda __rc4
  clc
  adc #4480
  sta __rc6
  sep #$20
  brl .Lsvx_delta_token
.Lsvx_key_token:
  .byte $a0,$00,$00 /* LDY #$0000 with 16-bit index. */
  lda (__rc0),y
  cmp #$80
  bne .Lsvx_key_not_nop
  brl .Lsvx_key_nop
.Lsvx_key_not_nop:
  bcs .Lsvx_key_run
  inc
  xba
  lda #0
  xba
  rep #$20
  sta __rc8
  dec
  ldx __rc0
  inx
  ldy __rc4
  .byte $54,$00,$00 /* MVN $00,$00; integrated assembler lacks spelling. */
  stx __rc0
  sty __rc4
  lda __rc6
  sec
  sbc __rc8
  sta __rc6
  sep #$20
  bne .Lsvx_key_literal_more
  brl .Lsvx_done
.Lsvx_key_literal_more:
  brl .Lsvx_key_token
.Lsvx_key_run:
  sta __rc10
  .byte $a0,$01,$00 /* LDY #$0001 with 16-bit index. */
  lda (__rc0),y
  sta __rc11
  lda #1
  sec
  sbc __rc10
  xba
  lda #0
  xba
  rep #$20
  sta __rc8
  .byte $a0,$00,$00 /* LDY #$0000 with 16-bit index. */
  sep #$20
  lda __rc11
.Lsvx_key_run_loop:
  sta (__rc4),y
  iny
  cpy __rc8
  bne .Lsvx_key_run_loop
  rep #$20
  inc __rc0
  inc __rc0
  lda __rc4
  clc
  adc __rc8
  sta __rc4
  lda __rc6
  sec
  sbc __rc8
  sta __rc6
  sep #$20
  bne .Lsvx_key_run_more
  brl .Lsvx_done
.Lsvx_key_run_more:
  brl .Lsvx_key_token
.Lsvx_key_nop:
  rep #$20
  inc __rc0
  sep #$20
  brl .Lsvx_key_token
.Lsvx_delta_token:
  .byte $a0,$00,$00 /* LDY #$0000 with 16-bit index. */
  lda (__rc0),y
  bmi .Lsvx_delta_copy
  inc
  .byte $85,$08 /* STA __rc8, direct page (DP is fixed at zero). */
  rep #$20
  .byte $a5,$08 /* LDA __rc8, direct page. */
  dec
  .byte $a6,$00 /* LDX __rc0, direct page. */
  inx
  .byte $a4,$04 /* LDY __rc4, direct page. */
  .byte $54,$00,$00 /* MVN $00,$00: absolute replacement span. */
  .byte $86,$00 /* STX __rc0, direct page. */
  .byte $84,$04 /* STY __rc4, direct page. */
  .byte $a5,$02 /* LDA __rc2, direct page. */
  clc
  .byte $65,$08 /* ADC __rc8, direct page. */
  .byte $85,$02 /* STA __rc2, direct page. */
  bra .Lsvx_delta_span_finish
.Lsvx_delta_copy:
  and #$7f
  inc
  .byte $85,$08 /* STA __rc8, direct page. */
  rep #$20
  .byte $a5,$08 /* LDA __rc8, direct page. */
  dec
  .byte $a6,$02 /* LDX __rc2, direct page. */
  .byte $a4,$04 /* LDY __rc4, direct page. */
  .byte $54,$00,$00 /* MVN $00,$00: previous-frame copy span. */
  .byte $86,$02 /* STX __rc2, direct page. */
  .byte $84,$04 /* STY __rc4, direct page. */
  .byte $e6,$00 /* INC __rc0, direct page, 16-bit M. */
.Lsvx_delta_span_finish:
  .byte $c4,$06 /* CPY __rc6, direct page. */
  sep #$20
  bne .Lsvx_delta_span_more
  brl .Lsvx_done
.Lsvx_delta_span_more:
  brl .Lsvx_delta_token

.Lsvx_done:
  rep #$30
  pla
  sta __rc0
  ply
  plx
  plb
  plp
  rts
