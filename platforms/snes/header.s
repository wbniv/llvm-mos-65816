; SNES LoROM cartridge header, placed by link.ld at $FFB0-$FFDF.
; Layout per the Super Famicom internal ROM header (LoROM, $FFC0 title base).
; The checksum/complement fields are placeholders patched post-link by
; snes-checksum.py.

.section .snes_header,"a",@progbits
.global __snes_header
__snes_header:
  ; $FFB0 extended header (maker/game codes etc.) — zeros for homebrew.
  .byte 0x00, 0x00              ; maker code
  .byte 0x00, 0x00, 0x00, 0x00  ; game code
  .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ; fixed (0x00)
  .byte 0x00                    ; expansion flash size
  .byte 0x00                    ; expansion RAM size
  .byte 0x00                    ; special version
  .byte 0x00                    ; cartridge sub-type

  ; $FFC0 title — 21 bytes, ASCII, space-padded.
  .ascii "LLVM-MOS SNES"
  .space 8, 0x20                ; pad to 21 bytes

  ; $FFD5 onward.
  .byte 0x20  ; map mode: LoROM, slow (2.68 MHz)
  .byte 0x00  ; cartridge type: ROM only
  .byte 0x05  ; ROM size: log2(32 KiB)
  .byte 0x00  ; RAM size: none
  .byte 0x01  ; destination: North America (NTSC)
  .byte 0x00  ; developer id
  .byte 0x00  ; ROM version
  .byte 0xFF, 0xFF  ; $FFDC checksum complement (patched post-link)
  .byte 0x00, 0x00  ; $FFDE checksum            (patched post-link)
