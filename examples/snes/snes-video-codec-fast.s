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
.global svx_decode_payload_wram_key_asm

/* Staged-keyframe specialization: PackBits, staged source bank pinned to $7F.

   The general kernel is bank-agnostic, so it re-tests svx_asm_source_bank at
   all three read sites (token, literal, run value) and flips M around each
   test. It also spills the cursors to __rc0/__rc4 and recomputes a remaining-
   byte count every token. On dithered content that overhead dominates: a
   representative keyframe carries 290 tokens for 4,480 output bytes (literal
   mean 21 B, run mean 10 B), so per-token cost, not per-byte cost, sets the
   time.

   This variant therefore:
     - pins the source bank, deleting every far-check and its sep/rep pair;
     - keeps X (staged source) and Y (output) live in registers across tokens;
     - terminates on `cpy` against the output end instead of maintaining a
       remaining-byte counter; and
     - fills runs with an overlapping MVN (store one byte, then block-move
       dest -> dest+1) at ~7 cycles/byte instead of a 15-cycle store loop.
   DBR is $00 on entry and every MVN here names $00 as its destination, so DBR
   is invariant and the per-token reload disappears too.

   The general path is left exactly as it was; this is a separate entry point. */
svx_decode_payload_wram_key_asm:
  php
  phb
  rep #$30
  phx
  phy
  sep #$20
  lda #0
  pha
  plb /* DBR := $00 for the whole kernel; MVN destinations keep it there. */
  rep #$20
  lda svx_asm_output
  tay
  clc
  adc #4480
  sta __rc6 /* Output end: the only loop bound. */
  lda svx_asm_source
  tax
.Lkey_token:
  sep #$20
  .byte $bf,$00,$00,$7f /* LDA $7F0000,X: PackBits control byte. */
  inx
  cmp #$80
  beq .Lkey_token /* $80 is a no-op token; output did not advance. */
  bcs .Lkey_run
  /* Literal run of A+1 bytes: a straight block copy from staged WRAM.
     Widen through XBA rather than AND #$00ff: this assembler sizes an
     immediate by the literal's magnitude and not by the M flag, so a 16-bit
     AND of a byte-sized constant silently assembles to the 8-bit form and
     swallows the next opcode as its high operand byte. */
  inc
  xba
  lda #0
  xba
  rep #$20
  dec
  mvn #$7f, #$00
  cpy __rc6
  bne .Lkey_token
  bra .Lkey_done
.Lkey_run:
  /* Run of 257-control bytes of one value. */
  sta __rc10
  .byte $bf,$00,$00,$7f /* LDA $7F0000,X: the run value. */
  inx
  .byte $99,$00,$00     /* STA $0000,Y: seed byte, through DBR=$00. */
  lda #1
  sec
  sbc __rc10 /* A = 257-control, taken mod 256; runs are always 2..128. */
  xba
  lda #0
  xba
  rep #$20
  dec
  dec
  /* Overlapping block move: source is the byte just written, destination the
     next one, so each copied byte re-reads the value and the run propagates. */
  phx
  tyx
  iny
  mvn #$00, #$00
  plx
  cpy __rc6
  bne .Lkey_token
.Lkey_done:
  rep #$30
  ply
  plx
  plb
  plp
  rts

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
  ldx __rc0
  inx
  ldy __rc4
  /* A PackBits literal run is exactly a block copy, so move it with MVN at
     ~7 cycles/byte instead of the former LDA-long/STA/INX/INY/DEC/BNE byte loop
     at ~24. MVN sets DBR to its destination bank ($00, the near framebuffer),
     which is what every following parser access already expects; the staged
     source bank is named explicitly, so the high-WRAM crossing stays unambiguous.
     A holds count-1, parked on the stack across the 8-bit bank test. */
  dec
  pha
  sep #$20
  lda __rc12
  beq .Lsvx_key_literal_bank0
  rep #$20
  pla
  mvn #$7f, #$00
  bra .Lsvx_key_literal_done
.Lsvx_key_literal_bank0:
  rep #$20
  pla
  mvn #$00, #$00
.Lsvx_key_literal_done:
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
