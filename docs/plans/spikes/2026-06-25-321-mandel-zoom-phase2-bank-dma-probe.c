// SPIKE — Phase 2 (multi-bank LoROM) feasibility probe for the Mandelbrot zoom pyramid (#321 M2).
// Plan: docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md. Recorded artifact (the measurement +
// verdict) per the project's spike-keep policy; NOT part of any build.
//
// QUESTION (the Phase 2 crux): can a SNES DMA source Mode 7 character data from a HIGH ROM BANK
// (not bank $00), addressed via a per-level far symbol whose 24-bit address is split into the DMA's
// A1B0 (bank) + A1T0L/H (addr16)? Phase 2 places each 128x128 level (16 KiB) in its own bank and
// DMAs the current level on a level-swap, so the whole pyramid depends on this working.
//
// VERDICT: ✅ PROVEN (2026-06-25, bsnes-jg). Built against the snes-far platform (banks $00+$01):
//   * The linker places `.far_rodata` PAT[] at VMA $018000 (bank $01) — `.map`: "18000 ... PAT".
//   * `(uint16_t)(uintptr_t)&PAT` resolves to $8000 (the low 16 bits of $018000) — the addr16 the
//     DMA needs; corpus_result == 0x8000 confirmed on bsnes-jg. (A 16-bit reloc on the far symbol;
//     no far-POINTER deref, so the addr-take itself is default-8bit-clean too.)
//   * Driving A1B0 = $01, A1T0 = $8000, the DMA copies bank-$01 bytes into VRAM high bytes: a VRAM
//     dump shows word N high byte == PAT[N] (0x10,0x11,0x12,…,0x1F,0x20,…) — i.e. the BANK-$01 data
//     arrived, not bank-$00 garbage. The SNES DMA A-bus reads any bank (this is how every game DMAs
//     gfx from ROM); A1B0 is just the source bank.
//
// CONSEQUENCE: Phase 2 is mechanical from here — extend the linker to N banks (mirror
// platforms/snes-far/link.ld), give each level its own bank-placed section, teach
// tools/snes-checksum.py the 256 KiB size byte (0x40000 -> 0x09), and on a level-swap DMA from
// (per-level bank : (uint16_t)&LEVEL_k). The level-data verification can stay default+a16-buildable
// by hashing the ROM file's level regions host-side (no on-console far reads), or go +mos-a16-only
// like mandel-mode7 by hashing the levels through a far-pointer table on-console.
//
// REPRODUCE (host-side; build/jgxcheck + the snes-far platform must be installed):
//   CLANG=build/llvm-mos-install/bin/mos-clang; CFG=build/install/bin/mos-snes-far.cfg
//   $CLANG --config $CFG -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
//     -Wl,-Map=/tmp/bp.map -o /tmp/bp.sfc THIS_FILE
//   python3 tools/snes-checksum.py /tmp/bp.sfc
//   JGX_VRAM=1 build/jgxcheck /tmp/bp.sfc vendor/bsnes-jg/Database \
//     0x$(awk '$NF=="corpus_result"{print $1}' /tmp/bp.map) 2 0x8000 60   # SMOKE got=0x8000; VRAM high bytes = PAT[]
#include <snes.h>

// A recognizable 512-byte pattern forced into BANK $01 (snes-far `.far_rodata` -> $01:8xxx).
__attribute__((section(".far_rodata"))) const uint8_t PAT[512] = {
#define R16(b) (uint8_t)(b),(uint8_t)((b)+1),(uint8_t)((b)+2),(uint8_t)((b)+3),(uint8_t)((b)+4),(uint8_t)((b)+5),(uint8_t)((b)+6),(uint8_t)((b)+7),(uint8_t)((b)+8),(uint8_t)((b)+9),(uint8_t)((b)+10),(uint8_t)((b)+11),(uint8_t)((b)+12),(uint8_t)((b)+13),(uint8_t)((b)+14),(uint8_t)((b)+15)
  R16(0x10),R16(0x20),R16(0x30),R16(0x40),R16(0x50),R16(0x60),R16(0x70),R16(0x80),
  R16(0x90),R16(0xA0),R16(0xB0),R16(0xC0),R16(0xD0),R16(0xE0),R16(0xF0),R16(0x00),
  R16(0x11),R16(0x21),R16(0x31),R16(0x41),R16(0x51),R16(0x61),R16(0x71),R16(0x81),
  R16(0x91),R16(0xA1),R16(0xB1),R16(0xC1),R16(0xD1),R16(0xE1),R16(0xF1),R16(0x01),
};

volatile uint16_t corpus_result;   // = (uint16_t)&PAT — the addr16 the linker assigned the far symbol

int main(void) {
  snes_ppu_reset_blank();
  corpus_result = (uint16_t)(uintptr_t)&PAT;            // prove the far symbol's addr16 (expect $8000)
  // DMA 512 bytes from bank $01:&PAT into VRAM high bytes (Mode 7 chr), from word 0.
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = 0;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x19;                   // A->B, inc src, pattern 0, dest $2119 (VMDATAH)
  REG_A1T0L = (uint8_t)(uintptr_t)&PAT;
  REG_A1T0H = (uint8_t)((uintptr_t)&PAT >> 8);
  REG_A1B0  = 0x01;                                     // <-- source BANK $01 (the whole point)
  REG_DAS0L = 0x00; REG_DAS0H = 0x02;                   // 0x200 = 512 bytes
  REG_MDMAEN = 0x01;
  for (;;) {}
}
