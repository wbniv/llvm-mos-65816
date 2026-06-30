// snesgfx formal verification client — OOP Mandelbrot in Mode 7.
//
// Reproduces mandel-display.c's corpus_result == 0x204F (the canonical 64x56 fixed-point
// Mandelbrot CRC) using the snesgfx OOP interface instead of procedural snes_* calls.
// Proves: (1) Mode 7 as a Drawable, (2) zero bare REG_*/snes_* in main(), (3) dispatch is
// coarse-grained (one virtual call per Drawable per frame, NEVER in the mandel_cell loop).
//
// mos-a16-only — far pointers (fb at $7E2000) require the 16-bit-accumulator target.
//
// Gate: corpus_result == 0x204F on host == a16@bsnes-jg (+ MAME if SPC700 IPL present).
// See docs/plans/2026-06-30-snesgfx-mandel-oop-verification.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "mode7.h"
#include "../65816/mandel.h"
#include "sincos.h"

#define DW       64          // image width  (8 Mode 7 tiles)
#define DH       56          // image height (7 Mode 7 tiles)
#define DN       15          // max iterations (palette fits CGRAM)
#define TILES_W  (DW / 8)   // 8
#define TILES_H  (DH / 8)   // 7
#define ROW_BYTES 512        // one tile-row of chr data (8 tiles × 64 bytes)

// Canonical 64×56 far buffer in high WRAM ($7E2000) — same address as mandel-display.c.
// Far stores/loads exercise the #320 far-pointer path (sta [dp] / lda [dp]).
static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;

volatile uint16_t corpus_result;   // proof channel — gate asserts == 0x204F

// ---------------------------------------------------------------------------
// MandelLayer — Mode 7 Drawable

typedef struct {
  Drawable  base;               // MUST be first (upcast discipline)
  uint16_t  pal[DN + 1];        // base BGR555 palette cached for cycling
  uint16_t  pal_rot[(DN + 1)];  // rotated palette staging (enqueued each emit)
  uint8_t   pshift;             // current colour rotation offset (0..DN-1)
  uint8_t   pcount;             // frames since last pshift advance
  uint8_t   angle;              // spin angle (wraps 0..255)
  uint8_t   t;                  // zoom phase (wraps 0..255)
  uint8_t   chrbuf[ROW_BYTES];  // staging buffer for VRAM tile-row uploads (reserve only)
} MandelLayer;

// One zero byte for the fixed-source tilemap-clear DMA.
static const uint8_t m7_zero = 0;

// CRC16-CCITT over the 64×56 far buffer via FAR LOADS — same as mandel-display.c's crc_fb().
static uint16_t crc_fb_oop(void) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < (uint16_t)(DW * DH); k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);
    for (uint8_t b = 0; b < 8; b++)
      crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  }
  return crc;
}

// DMA one tile-row of chr data to Mode 7 VRAM (same as mandel-display.c's dma_chr_to).
// Only called in reserve() while force-blanked — direct DMA is safe.
static void dma_chr_row(uint16_t destword, const uint8_t *src, uint16_t nbytes) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;
  REG_DMAP0 = 0x00;
  REG_BBAD0 = 0x19;
  REG_A1T0L = (uint8_t)(uintptr_t)src; REG_A1T0H = (uint8_t)((uintptr_t)src >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)nbytes; REG_DAS0H = (uint8_t)(nbytes >> 8);
  REG_MDMAEN = 0x01;
}

// Fill ml->chrbuf with Mode 7 tiled chr data for tile-row `trow` from the far buffer.
static void build_chr_row(MandelLayer *ml, uint8_t trow) {
  for (uint8_t tcol = 0; tcol < TILES_W; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++)
        ml->chrbuf[(uint16_t)tcol * 64u + (uint16_t)r * 8u + c] =
          fb[(uint16_t)((trow * 8u + r)) * DW + (tcol * 8u + c)];
}

// Load the base palette (DN+1 colours) into ml->pal and write to CGRAM (force-blank only).
static void load_palette_cgram(MandelLayer *ml) {
  REG_CGADD = 0;
  for (uint8_t n = 0; n <= DN; n++) {
    uint8_t r5, g5, b5;
    mandel_palette(n, DN, &r5, &g5, &b5);
    uint16_t c = SNES_RGB(r5, g5, b5);
    ml->pal[n] = c;
    REG_CGDATA = (uint8_t)(c & 0xFF);
    REG_CGDATA = (uint8_t)(c >> 8);
  }
}

// reserve(): called once by display_add() while force-blanked.
// Sets up Mode 7 registers, computes the 64×56 grid, sets corpus_result, uploads to VRAM.
// NOTE: we set BGMODE_7 here (overriding display_init's BGMODE_1) and avoid touching REG_TM
// (Display manages it via its shadow using base.tm_bits = TM_BG1).
static void _mandel_reserve(Drawable *d, VramAlloc *va) {
  MandelLayer *ml = (MandelLayer *)d;
  (void)va;                         // Mode 7 has no allocatable VRAM regions

  // Mode 7 setup (force-blank, screen invisible — direct PPU writes OK, same as sprite_set.h)
  REG_BGMODE = BGMODE_7;
  REG_M7SEL  = 0x00;               // wrap tile 0 outside map
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES_W, TILES_H);
  m7_set_matrix(0x0040, 0x0000, 0x0000, 0x0040);  // 4× framing: 64x56 fills 256x224
  m7_set_center(DW / 2, DH / 2);
  m7_set_scroll((uint16_t)(int16_t)(-(128 - DW / 2)), (uint16_t)(int16_t)(-(112 - DH / 2)));

  // Compute the 64×56 Mandelbrot grid via FAR STORES into $7E2000.
  {
    int16_t dre = (int16_t)(MANDEL_REW / DW);
    int16_t dim = (int16_t)(MANDEL_IMW / DH);
    for (uint8_t j = 0; j < DH; j++) {
      int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)j * dim);
      for (uint8_t i = 0; i < DW; i++) {
        int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)i * dre);
        fb[(uint16_t)j * DW + i] = mandel_cell(cr, ci, DN);  // FAR STORE
      }
    }
  }

  // CRC the full far buffer — should equal 0x204F on host and target.
  corpus_result = crc_fb_oop();

  // Upload full 64×56 grid to Mode 7 VRAM in tiled order (7 tile-rows × 512 bytes).
  for (uint8_t trow = 0; trow < TILES_H; trow++) {
    build_chr_row(ml, trow);
    dma_chr_row((uint16_t)trow * ROW_BYTES, ml->chrbuf, ROW_BYTES);
  }

  // Load palette into CGRAM (direct write, force-blanked).
  load_palette_cgram(ml);
}

// emit(): called every frame by scene_emit() — the single virtual dispatch per drawable.
// Enqueues the colour-cycle CGRAM upload and Mode 7 matrix spin+zoom via UPQ_REG pokes.
static void _mandel_emit(Drawable *d, UploadQueue *q) {
  MandelLayer *ml = (MandelLayer *)d;

  // Advance colour cycle: rotate by 1 every 6 frames (same cadence as mandel-display.c).
  if (++ml->pcount >= 6) {
    ml->pcount = 0;
    if (++ml->pshift >= DN) ml->pshift = 0;
  }

  // Build rotated palette in ml->pal_rot (must persist until upq_flush in v-blank).
  for (uint8_t n = 0; n < DN; n++) {
    uint8_t j = (uint8_t)(n + ml->pshift);
    if (j >= DN) j = (uint8_t)(j - DN);
    ml->pal_rot[n] = ml->pal[j];
  }
  ml->pal_rot[DN] = ml->pal[DN];                // interior stays black

  // Queue CGRAM upload — flushed in v-blank by Display.
  upq_push_cgram(q, 0, ml->pal_rot, 0x00, (uint16_t)((DN + 1) * sizeof(uint16_t)));

  // Advance spin+zoom animation (same formula as mandel-display.c's steady-state loop).
  int16_t zoom = (int16_t)(0x0030 +
    (((int32_t)SINCOS[(uint8_t)(ml->t >> 1)] * 0x0010) >> 8));
  int16_t cs = SINCOS[(uint8_t)(ml->angle + 64)];
  int16_t sn = SINCOS[ml->angle];
  int16_t a  = (int16_t)(((int32_t)cs  *  zoom) >> 8);
  int16_t b  = (int16_t)(((int32_t)(-sn) * zoom) >> 8);
  int16_t cc = (int16_t)(((int32_t)sn  *  zoom) >> 8);
  ml->angle = (uint8_t)(ml->angle + 1);
  ml->t     = (uint8_t)(ml->t     + 1);

  // Queue Mode 7 matrix updates via write-twice UPQ_REG pokes (same mechanism as scroll latches).
  upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_M7A, (uint16_t)a);
  upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_M7B, (uint16_t)b);
  upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_M7C, (uint16_t)cc);
  upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_M7D, (uint16_t)a);
}

static const DrawableVT MANDEL_OOP_VT = { _mandel_reserve, _mandel_emit };

static void mandel_layer_init(MandelLayer *ml) {
  ml->base.vt      = &MANDEL_OOP_VT;
  ml->base.tm_bits = TM_BG1;    // Display sets REG_TM via its shadow — never touch TM directly
  ml->pshift = 0; ml->pcount = 0;
  ml->angle  = 0; ml->t      = 0;
}

// ---------------------------------------------------------------------------
// Main — OOP discipline: zero bare REG_*/snes_* calls; only Display API.

int main(void) {
  static Display    screen;
  static MandelLayer layer;

  display_init(&screen);         // boot bracket: snes_ppu_reset_blank() + NMI + BGMODE_1
  mandel_layer_init(&layer);
  display_add(&screen, (Drawable *)&layer);
  // reserve() ran above: BGMODE_7 set, grid computed, corpus_result=0x204F, VRAM loaded.

  // Steady-state display: first display_frame() releases force-blank.
  for (;;)
    display_frame(&screen);    // scene_emit → _mandel_emit (1 virtual call/frame) → upq_flush
}
