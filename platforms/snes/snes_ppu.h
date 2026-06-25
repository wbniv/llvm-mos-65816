#ifndef _SNES_PPU_H_
#define _SNES_PPU_H_

/* SNES PPU (picture processing unit) register map — $2100..$213F.
 *
 * The PPU has no linear framebuffer: you upload character (tile) data, a tilemap
 * and a palette into its private memories (VRAM, CGRAM, OAM) and it composites
 * them every scanline. VRAM/CGRAM/OAM are writable ONLY during force-blank
 * (INIDISP bit 7) or v-blank — writes during active display are dropped. Bring
 * the machine up force-blanked, configure everything, then release the blank
 * last (see snes_ppu_reset_blank()).
 *
 * Bit-field facts: nocash "fullsnes", SNESdev wiki, anomie's PPU docs
 * (docs/refs/snes-hardware/SOURCES.md). */

#include "snes_mmio.h"

/* ---- Display control ---- */

/* @reg INIDISP $2100 W  Display control 1 — force-blank + master brightness.
 * @bit  7     FBLANK   force blank (1 = screen off; VRAM/CGRAM/OAM writable)
 * @bits 3-0   BRIGHT   master brightness 0..15 ((N+1)/16 intensity)
 */
#define REG_INIDISP  _SNES_REG8(0x2100)

/* @reg OBSEL $2101 W  Object (sprite) size + tile-base select.
 * @bits 7-5   SIZE     sprite size pair (0..7 select e.g. 8x8/16x16 .. 32x32/64x64)
 * @bits 4-3   NAMESEL  2nd OBJ tile page offset ((N+1) * 4K-word gap after BASE)
 * @bits 2-0   NAMEBASE OBJ tile data base address (8K-word / 16 KB units)
 */
#define REG_OBSEL    _SNES_REG8(0x2101)

/* ---- OAM (sprite attribute) access ---- */

/* @reg OAMADDL $2102 W  OAM word address, low byte (0..255). */
#define REG_OAMADDL  _SNES_REG8(0x2102)
/* @reg OAMADDH $2103 W  OAM address high + priority rotation.
 * @bit  7     PRIO     OBJ priority rotation (1 = sprite at OAMADD has top prio)
 * @bit  0     ADDRHI   OAM address bit 8 (high table at $0100..$011F)
 */
#define REG_OAMADDH  _SNES_REG8(0x2103)
/* @reg OAMDATA $2104 W  OAM data write (auto-increments OAMADD; write low then high). */
#define REG_OAMDATA  _SNES_REG8(0x2104)

/* ---- Backgrounds: mode, mosaic, tilemap + char bases ---- */

/* @reg BGMODE $2105 W  BG mode + per-layer tile size.
 * @bit  7     SZ4      BG4 tile size (0 = 8x8, 1 = 16x16)
 * @bit  6     SZ3      BG3 tile size
 * @bit  5     SZ2      BG2 tile size
 * @bit  4     SZ1      BG1 tile size
 * @bit  3     BG3PRIO  BG3 high priority (mode 1 only)
 * @bits 2-0   MODE     BG mode 0..7
 */
#define REG_BGMODE   _SNES_REG8(0x2105)

/* @reg MOSAIC $2106 W  Mosaic block size + per-BG enable.
 * @bits 7-4   SIZE     mosaic block size minus 1 (0 = 1px .. 15 = 16px)
 * @bit  3     BG4      mosaic enable BG4
 * @bit  2     BG3      mosaic enable BG3
 * @bit  1     BG2      mosaic enable BG2
 * @bit  0     BG1      mosaic enable BG1
 */
#define REG_MOSAIC   _SNES_REG8(0x2106)

/* @reg BG1SC $2107 W  BG1 tilemap base + map size.
 * @bits 7-2   BASE     tilemap base address ($400-word / 2 KB units)
 * @bits 1-0   SIZE     map size (0 = 32x32, 1 = 64x32, 2 = 32x64, 3 = 64x64)
 */
#define REG_BG1SC    _SNES_REG8(0x2107)
/* @reg BG2SC $2108 W  BG2 tilemap base + size (see BG1SC). */
#define REG_BG2SC    _SNES_REG8(0x2108)
/* @reg BG3SC $2109 W  BG3 tilemap base + size (see BG1SC). */
#define REG_BG3SC    _SNES_REG8(0x2109)
/* @reg BG4SC $210A W  BG4 tilemap base + size (see BG1SC). */
#define REG_BG4SC    _SNES_REG8(0x210A)

/* @reg BG12NBA $210B W  BG1/BG2 character (tile) data base.
 * @bits 7-4   BG2      BG2 char base ($1000-word / 8 KB units)
 * @bits 3-0   BG1      BG1 char base ($1000-word / 8 KB units)
 */
#define REG_BG12NBA  _SNES_REG8(0x210B)
/* @reg BG34NBA $210C W  BG3/BG4 character data base.
 * @bits 7-4   BG4      BG4 char base ($1000-word units)
 * @bits 3-0   BG3      BG3 char base ($1000-word units)
 */
#define REG_BG34NBA  _SNES_REG8(0x210C)

/* ---- Background scroll (each: write twice — low byte, then high bits) ---- */

/* @reg BG1HOFS $210D W  BG1 horizontal scroll (write twice; 10-bit, +Mode7 share). */
#define REG_BG1HOFS  _SNES_REG8(0x210D)
/* @reg BG1VOFS $210E W  BG1 vertical scroll (write twice; 10-bit). */
#define REG_BG1VOFS  _SNES_REG8(0x210E)
/* @reg BG2HOFS $210F W  BG2 horizontal scroll (write twice). */
#define REG_BG2HOFS  _SNES_REG8(0x210F)
/* @reg BG2VOFS $2110 W  BG2 vertical scroll (write twice). */
#define REG_BG2VOFS  _SNES_REG8(0x2110)
/* @reg BG3HOFS $2111 W  BG3 horizontal scroll (write twice). */
#define REG_BG3HOFS  _SNES_REG8(0x2111)
/* @reg BG3VOFS $2112 W  BG3 vertical scroll (write twice). */
#define REG_BG3VOFS  _SNES_REG8(0x2112)
/* @reg BG4HOFS $2113 W  BG4 horizontal scroll (write twice). */
#define REG_BG4HOFS  _SNES_REG8(0x2113)
/* @reg BG4VOFS $2114 W  BG4 vertical scroll (write twice). */
#define REG_BG4VOFS  _SNES_REG8(0x2114)

/* ---- VRAM access ---- */

/* @reg VMAIN $2115 W  VRAM address increment control.
 * @bit  7     INCHIGH  increment after VMDATAH ($2119) write (1) or VMDATAL (0)
 * @bits 3-2   REMAP    address remap (0 = none; 1/2/3 = 8/9/10-bit tile rotate)
 * @bits 1-0   STEP     increment step in words (0 = +1, 1 = +32, 2/3 = +128)
 */
#define REG_VMAIN    _SNES_REG8(0x2115)
/* @reg VMADDL $2116 W  VRAM word address, low byte. */
#define REG_VMADDL   _SNES_REG8(0x2116)
/* @reg VMADDH $2117 W  VRAM word address, high byte. */
#define REG_VMADDH   _SNES_REG8(0x2117)
/* @reg VMDATAL $2118 W  VRAM data, low byte (increments per VMAIN if INCHIGH=0). */
#define REG_VMDATAL  _SNES_REG8(0x2118)
/* @reg VMDATAH $2119 W  VRAM data, high byte (increments per VMAIN if INCHIGH=1). */
#define REG_VMDATAH  _SNES_REG8(0x2119)
/* @reg16 VMADD  $2116 W  VRAM word address, 16-bit access alias over VMADDL/H. */
#define REG_VMADD    _SNES_REG16(0x2116)
/* @reg16 VMDATA $2118 W  VRAM data, 16-bit access alias over VMDATAL/H (low then high). */
#define REG_VMDATA   _SNES_REG16(0x2118)

/* ---- Mode 7 (affine layer) — matrix elements write twice; A/B feed the hw multiply ---- */

/* @reg M7SEL $211A W  Mode 7 screen settings.
 * @bits 7-6   OVER     outside-map fill (0 = wrap, 2 = transparent, 3 = tile 0)
 * @bit  1     VFLIP    vertical screen flip
 * @bit  0     HFLIP    horizontal screen flip
 */
#define REG_M7SEL    _SNES_REG8(0x211A)
/* @reg M7A $211B W  Mode 7 matrix A (signed 8.8; write low,high). Also hw-multiply factor A. */
#define REG_M7A      _SNES_REG8(0x211B)
/* @reg M7B $211C W  Mode 7 matrix B (signed 8.8; write low,high). Also hw-multiply factor B (8-bit). */
#define REG_M7B      _SNES_REG8(0x211C)
/* @reg M7C $211D W  Mode 7 matrix C (signed 8.8; write low,high). */
#define REG_M7C      _SNES_REG8(0x211D)
/* @reg M7D $211E W  Mode 7 matrix D (signed 8.8; write low,high). */
#define REG_M7D      _SNES_REG8(0x211E)
/* @reg M7X $211F W  Mode 7 center X (signed 13-bit; write twice). */
#define REG_M7X      _SNES_REG8(0x211F)
/* @reg M7Y $2120 W  Mode 7 center Y (signed 13-bit; write twice). */
#define REG_M7Y      _SNES_REG8(0x2120)

/* ---- CGRAM (palette) access ---- */

/* @reg CGADD $2121 W  CGRAM (palette) entry address (0..255). */
#define REG_CGADD    _SNES_REG8(0x2121)
/* @reg CGDATA $2122 W  CGRAM data port — BGR555, write low byte then high byte. */
#define REG_CGDATA   _SNES_REG8(0x2122)

/* ---- Window masks ---- */

/* @reg W12SEL $2123 W  Window mask settings for BG1/BG2 (2 bits per window/layer).
 * @bits 1-0   BG1W1    BG1 window 1 (bit0 invert/out, bit1 enable)
 * @bits 3-2   BG1W2    BG1 window 2
 * @bits 5-4   BG2W1    BG2 window 1
 * @bits 7-6   BG2W2    BG2 window 2
 */
#define REG_W12SEL   _SNES_REG8(0x2123)
/* @reg W34SEL $2124 W  Window mask settings for BG3/BG4.
 * @bits 1-0   BG3W1    BG3 window 1 (bit0 invert, bit1 enable)
 * @bits 3-2   BG3W2    BG3 window 2
 * @bits 5-4   BG4W1    BG4 window 1
 * @bits 7-6   BG4W2    BG4 window 2
 */
#define REG_W34SEL   _SNES_REG8(0x2124)
/* @reg WOBJSEL $2125 W  Window mask settings for OBJ + color-math.
 * @bits 1-0   OBJW1    OBJ window 1 (bit0 invert, bit1 enable)
 * @bits 3-2   OBJW2    OBJ window 2
 * @bits 5-4   MATHW1   color-math window 1
 * @bits 7-6   MATHW2   color-math window 2
 */
#define REG_WOBJSEL  _SNES_REG8(0x2125)
/* @reg WH0 $2126 W  Window 1 left position (pixel 0..255). */
#define REG_WH0      _SNES_REG8(0x2126)
/* @reg WH1 $2127 W  Window 1 right position. */
#define REG_WH1      _SNES_REG8(0x2127)
/* @reg WH2 $2128 W  Window 2 left position. */
#define REG_WH2      _SNES_REG8(0x2128)
/* @reg WH3 $2129 W  Window 2 right position. */
#define REG_WH3      _SNES_REG8(0x2129)
/* @reg WBGLOG $212A W  Window-1/2 combine logic per BG (00 OR, 01 AND, 10 XOR, 11 XNOR).
 * @bits 1-0   BG1      BG1 window logic
 * @bits 3-2   BG2      BG2 window logic
 * @bits 5-4   BG3      BG3 window logic
 * @bits 7-6   BG4      BG4 window logic
 */
#define REG_WBGLOG   _SNES_REG8(0x212A)
/* @reg WOBJLOG $212B W  Window combine logic for OBJ + color-math.
 * @bits 1-0   OBJ      OBJ window logic
 * @bits 3-2   MATH     color-math window logic
 */
#define REG_WOBJLOG  _SNES_REG8(0x212B)

/* ---- Layer enable + color math ---- */

/* @reg TM $212C W  Main-screen layer enable.
 * @bit  4     OBJ      enable OBJ on main screen
 * @bit  3     BG4
 * @bit  2     BG3
 * @bit  1     BG2
 * @bit  0     BG1
 */
#define REG_TM       _SNES_REG8(0x212C)
/* @reg TS $212D W  Sub-screen layer enable (bits as TM). */
#define REG_TS       _SNES_REG8(0x212D)
/* @reg TMW $212E W  Main-screen window-mask enable per layer (bits as TM). */
#define REG_TMW      _SNES_REG8(0x212E)
/* @reg TSW $212F W  Sub-screen window-mask enable per layer (bits as TM). */
#define REG_TSW      _SNES_REG8(0x212F)
/* @reg CGWSEL $2130 W  Color-math control window + source.
 * @bits 7-6   MAINMASK force main screen to black region (0 never..3 always)
 * @bits 5-4   MATHMASK prevent color-math region (0 never..3 always)
 * @bit  1     SUBSRC   color-math source (0 = fixed color COLDATA, 1 = sub screen)
 * @bit  0     DIRECT   direct-color mode (256-color BG in modes 3/4/7)
 */
#define REG_CGWSEL   _SNES_REG8(0x2130)
/* @reg CGADSUB $2131 W  Color-math operation + per-layer enable.
 * @bit  7     SUB      operation (0 = add, 1 = subtract)
 * @bit  6     HALF     halve the result
 * @bit  5     BACKDROP apply math to the backdrop
 * @bit  4     OBJ      apply math to OBJ
 * @bit  3     BG4
 * @bit  2     BG3
 * @bit  1     BG2
 * @bit  0     BG1
 */
#define REG_CGADSUB  _SNES_REG8(0x2131)
/* @reg COLDATA $2132 W  Fixed color for color math (write once per channel).
 * @bit  7     B        apply INTENSITY to the blue channel
 * @bit  6     G        apply to green
 * @bit  5     R        apply to red
 * @bits 4-0   INTENSITY channel value 0..31
 */
#define REG_COLDATA  _SNES_REG8(0x2132)
/* @reg SETINI $2133 W  Display mode / interlace settings.
 * @bit  7     EXTSYNC  external sync (genlock; normally 0)
 * @bit  6     EXTBG    Mode 7 EXTBG (enable BG2 priority split in mode 7)
 * @bit  3     HIRES    pseudo-hi-res (512 horizontal)
 * @bit  2     OVERSCAN 239-line overscan
 * @bit  1     OBJILACE OBJ interlace
 * @bit  0     ILACE    screen interlace
 */
#define REG_SETINI   _SNES_REG8(0x2133)

/* ---- PPU read ports ($2134..$213F) ---- */

/* @reg MPYL $2134 R  Mode 7 / hw multiply result, low byte (M7A signed16 x M7B signed8 = signed24). */
#define REG_MPYL     _SNES_REG8(0x2134)
/* @reg MPYM $2135 R  multiply result, middle byte. */
#define REG_MPYM     _SNES_REG8(0x2135)
/* @reg MPYH $2136 R  multiply result, high byte. */
#define REG_MPYH     _SNES_REG8(0x2136)
/* @reg SLHV $2137 R  software latch: a dummy read latches the H/V counters into OPHCT/OPVCT. */
#define REG_SLHV     _SNES_REG8(0x2137)
/* @reg OAMDATAREAD $2138 R  OAM data read (auto-increments OAMADD). */
#define REG_OAMDATAREAD _SNES_REG8(0x2138)
/* @reg VMDATALREAD $2139 R  VRAM data read, low byte (increments per VMAIN). */
#define REG_VMDATALREAD _SNES_REG8(0x2139)
/* @reg VMDATAHREAD $213A R  VRAM data read, high byte. */
#define REG_VMDATAHREAD _SNES_REG8(0x213A)
/* @reg CGDATAREAD $213B R  CGRAM data read (low then high). */
#define REG_CGDATAREAD  _SNES_REG8(0x213B)
/* @reg OPHCT $213C R  horizontal counter latch (read twice: low then high bit 8; 0..339). */
#define REG_OPHCT    _SNES_REG8(0x213C)
/* @reg OPVCT $213D R  vertical counter latch (read twice; 0..261 NTSC). */
#define REG_OPVCT    _SNES_REG8(0x213D)
/* @reg STAT77 $213E R  PPU1 (5C77) status.
 * @bit  7     TIMEOVER more than 34 OBJ tiles on a scanline
 * @bit  6     RANGEOVER more than 32 OBJ on a scanline
 * @bit  5     MASTER   PPU1 master/slave pin
 * @bits 3-0   VERSION  5C77 chip version
 */
#define REG_STAT77   _SNES_REG8(0x213E)
/* @reg STAT78 $213F R  PPU2 (5C78) status.
 * @bit  7     FIELD    interlace field (toggles each frame)
 * @bit  6     LATCH    external latch flag (counters latched)
 * @bit  4     PAL      region (0 = NTSC, 1 = PAL)
 * @bits 3-0   VERSION  5C78 chip version
 */
#define REG_STAT78   _SNES_REG8(0x213F)

/* ============================ constants & helpers ============================ */

/* INIDISP: force-blank + brightness 0 — safe state to hold the PPU in during init. */
#define INIDISP_FORCE_BLANK 0x8F
/* INIDISP: screen on, full brightness. */
#define INIDISP_ON          0x0F

/* VMAIN: increment the VRAM word address by 1 after each VMDATAH ($2119) write —
 * the usual setting for sequential word writes via the 16-bit VMDATA port. */
#define VMAIN_INC_HIGH_1    0x80
/* VMAIN: increment after a write to $2118 (VMDATAL) instead — for streaming only the LOW byte
 * of each VRAM word (e.g. a Mode 7 tilemap, whose high byte is the character data). */
#define VMAIN_INC_LOW_1     0x00

/* Main/sub-screen layer-enable bits (REG_TM / REG_TS). */
#define TM_BG1 0x01
#define TM_BG2 0x02
#define TM_BG3 0x04
#define TM_BG4 0x08
#define TM_OBJ 0x10

/* BG mode values (REG_BGMODE low 3 bits = mode 0..7). */
#define BGMODE_1 0x01   /* BG1/BG2 4bpp (16 colour), BG3 2bpp */
#define BGMODE_3 0x03   /* BG1 8bpp (256 colour), BG2 4bpp    */
#define BGMODE_7 0x07   /* single 8bpp rotation/scale layer   */

/* Write a 16-bit Mode 7 matrix element (8.8 fixed point): low byte then high byte to
 * the same port. 0x0100 = 1.0 (identity); 0x0080 = 0.5 (source sampled at half-step,
 * i.e. the image shown at 2x zoom). */
#define SNES_M7(reg, val) do { (reg) = (uint8_t)(val); (reg) = (uint8_t)((val) >> 8); } while (0)

/* Build a BG?SC value: tilemap base in $400-word units (bits 7-2) + map size
 * (bits 1-0; 0 = 32x32). REG_BG?SC = SNES_BGSC(word_base, 0). */
#define SNES_BGSC(word_base, size) ((uint8_t)(((((word_base) >> 10) & 0x3F) << 2) | ((size) & 3)))

/* Pack an RGB555 (5-5-5, stored BGR) colour for CGRAM. */
#define SNES_RGB(r, g, b) ((uint16_t)(((b) & 0x1F) << 10 | ((g) & 0x1F) << 5 | ((r) & 0x1F)))

/* Point the VRAM data port at word address `wa` for subsequent REG_VMDATA writes. */
static inline void snes_vram_addr(uint16_t wa) { REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = wa; }

/* Force-blank the screen and reset the PPU CONTROL registers to a known-zero state
 * (BG mode, mosaic, BG/char bases, scrolls, mode-7, windows, main/sub layer-enables,
 * colour math). SNES power-on leaves these indeterminate — bsnes-jg randomises them —
 * so a program that configures only the registers it "uses" renders nondeterministically
 * (a random mosaic, window mask, or colour-math enable corrupts the picture differently
 * each boot). Call once at startup, before configuring the display. The VRAM/CGRAM/OAM
 * address+data ports ($2104/$2116-$2119/$2121/$2122) are skipped — writing them has side
 * effects (they'd poke video memory at the current pointer). */
static inline void snes_ppu_reset_blank(void) {
  REG_INIDISP = INIDISP_FORCE_BLANK;
  for (uint16_t a = 0x2101; a <= 0x2133; a++) {
    if (a == 0x2104 || a == 0x2116 || a == 0x2117 || a == 0x2118 ||
        a == 0x2119 || a == 0x2121 || a == 0x2122) continue;       /* data/addr ports */
    *(volatile uint8_t *)(uintptr_t)a = 0;
  }
}

#endif /* _SNES_PPU_H_ */
