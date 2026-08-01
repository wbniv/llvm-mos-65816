.text
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
  mvn #$00, #$00
  ply
  plx
  plb
  plp
  rts

.global svx_decode_payload_asm
.global svx_decode_payload_wram_asm
/* Staged-delta specialization. Long-indexed token reads avoid switching DBR
   back to $7F after every MVN; MVN's encoded operands are destination,source. */
svx_decode_payload_wram_asm:
  php
  phb
  rep #$30
  phx
  phy
  lda __rc0
  pha
  lda svx_asm_source
  sta __rc0
  lda svx_asm_previous
  sta __rc2
  lda svx_asm_output
  sta __rc4
  clc
  adc #4480
  sta __rc6
  stz __rc8
.Lsvx_wram_delta_token:
  ldx __rc0
.Lsvx_wram_delta_token_x:
  sep #$20
  .byte $bf,$00,$00,$7f /* LDA $7F0000,X. */
  bmi .Lsvx_wram_delta_copy
  inc
  sta __rc8
  rep #$20
  lda __rc8
  dec
  inx
  ldy __rc4
  mvn #$7f, #$00
  sty __rc4
  lda __rc2
  clc
  adc __rc8
  sta __rc2
  cpy __rc6
  bne .Lsvx_wram_delta_token_x
  bra .Lsvx_wram_done
.Lsvx_wram_delta_copy:
  and #$7f
  inc
  sta __rc8
  rep #$20
  /* The video reel deliberately decodes in place. A previous-copy span is
     then already present at the destination; advancing the two equal cursors
     is sufficient and avoids an MVN of bytes onto themselves. Keep the
     original path for callers that provide distinct previous/output buffers. */
  lda __rc2
  cmp __rc4
  beq .Lsvx_wram_delta_copy_inplace
  lda __rc8
  dec
  inx
  stx __rc0 /* Save the staged cursor before X becomes the previous-frame cursor. */
  ldx __rc2
  ldy __rc4
  mvn #$00, #$00
  stx __rc2
  sty __rc4
  cpy __rc6
  bne .Lsvx_wram_delta_token
  bra .Lsvx_wram_done
.Lsvx_wram_delta_copy_inplace:
  inx
  stx __rc0
  lda __rc4
  clc
  adc __rc8
  sta __rc2
  sta __rc4
  cmp __rc6
  beq .Lsvx_wram_done
  brl .Lsvx_wram_delta_token
.Lsvx_wram_done:
  pla
  sta __rc0
  ply
  plx
  plb
  plp
  rts

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
  stz __rc12 /* Source bank is kept as a 16-bit branchable value. */
  sep #$20
  lda svx_asm_keyframe
  pha
  lda svx_asm_source_bank
  sta __rc12
  pha
  plb /* Token reads use the staged source bank through (__rc0),Y. */
  pla
  bne .Lsvx_key_token
  rep #$20
  lda __rc4
  clc
  adc #4480
  sta __rc6
  sep #$20
  brl .Lsvx_delta_token
.Lsvx_key_token:
  /* Keyframe output and parser state are in bank $00. Keep DBR there and use
     a long load only when the staged source is in bank $7F. */
  lda #0
  pha
  plb
  rep #$10
  ldx __rc0
  sep #$20
  lda __rc12
  beq .Lsvx_key_token_bank0
  .byte $bf,$00,$00,$7f /* LDA $7F0000,X. */
  bra .Lsvx_key_token_read
.Lsvx_key_token_bank0:
  .byte $bd,$00,$00     /* LDA $0000,X through DBR=$00. */
.Lsvx_key_token_read:
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
  sta __rc10
  ldx __rc0
  inx
  ldy __rc4
  /* Keep keyframe literals explicit. Token/payload reads may be in high WRAM,
     while the near framebuffer is bank $00; long reads plus bank-$00 stores
     make that crossing unambiguous and avoid MVN changing DBR mid-parser. */
  sep #$20
  lda #0
  pha
  plb
  lda __rc12
  beq .Lsvx_key_literal_loop_bank0
  /* Staged keyframe literals have a fixed high-WRAM source and bank-$00
     destination. MVN copies the whole literal span and leaves DBR at the
     destination bank, exactly what the parser needs. */
  rep #$20
  lda __rc8
  dec
  mvn #$7f, #$00
  stx __rc0
  sty __rc4
  bra .Lsvx_key_literal_remaining
.Lsvx_key_literal_loop_bank0:
  .byte $bd,$00,$00     /* LDA $0000,X through DBR=$00. */
  .byte $99,$00,$00     /* STA $0000,Y through DBR=$00. */
  inx
  iny
  dec __rc10
  bne .Lsvx_key_literal_loop_bank0
.Lsvx_key_literal_done:
  rep #$20
  stx __rc0
  sty __rc4
.Lsvx_key_literal_remaining:
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
  rep #$10
  ldx __rc0
  inx
  sep #$20
  lda __rc12
  beq .Lsvx_key_run_value_bank0
  .byte $bf,$00,$00,$7f /* LDA $7F0000,X. */
  bra .Lsvx_key_run_value_read
.Lsvx_key_run_value_bank0:
  .byte $bd,$00,$00     /* LDA $0000,X through DBR=$00. */
.Lsvx_key_run_value_read:
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
  /* Token reads use DBR=$7F, but the near framebuffer is in bank $00.
     Run stores are ordinary (dp),Y accesses rather than MVN, so select the
     destination bank explicitly and restore the staged-source bank after. */
  lda #0
  pha
  plb
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
  pha
  lda __rc12
  beq .Lsvx_delta_replace_bank0
  pla
  mvn #$7f, #$00
  bra .Lsvx_delta_replace_moved
.Lsvx_delta_replace_bank0:
  pla
  mvn #$00, #$00
.Lsvx_delta_replace_moved:
  .byte $86,$00 /* STX __rc0, direct page. */
  .byte $84,$04 /* STY __rc4, direct page. */
  .byte $a5,$02 /* LDA __rc2, direct page. */
  clc
  .byte $65,$08 /* ADC __rc8, direct page. */
  .byte $85,$02 /* STA __rc2, direct page. */
  sep #$20
  lda __rc12
  pha
  plb
  rep #$20
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
  mvn #$00, #$00
  .byte $86,$02 /* STX __rc2, direct page. */
  .byte $84,$04 /* STY __rc4, direct page. */
  .byte $e6,$00 /* INC __rc0, direct page, 16-bit M. */
  sep #$20
  lda __rc12
  pha
  plb
  rep #$20
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
