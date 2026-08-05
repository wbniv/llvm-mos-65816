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
#include "snesgfx/m7title.h"
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
#define SCRATCH_N (32 * 28)

typedef enum {
  MANDEL_LOADING_COARSE,
  MANDEL_LOADING_MEDIUM,
  MANDEL_LOADING_FINE,
  MANDEL_LOADING_FINAL,
  MANDEL_READY
} MandelBuildPhase;

typedef struct {
  MandelBuildPhase phase;
  uint8_t row;
  uint8_t cw, ch, shx, shy;
  uint16_t cells_done;
  uint16_t cells_total;
} MandelBuild;

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
  uint8_t   first_emit_done;    // 1 after the first emit() — see _mandel_emit's first-frame note
  uint8_t   pshift;             // current colour rotation offset (0..DN-1)
  uint8_t   pcount;             // frames since last pshift advance
  uint8_t   angle;              // spin angle (wraps 0..255)
  uint8_t   t;                  // zoom phase (wraps 0..255)
  MandelBuild build;
  uint8_t   scratch[SCRATCH_N]; // largest coarse pass (32×28)
  uint8_t   chrbuf[ROW_BYTES];  // persistent staging for one queued tile-row
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

static void build_begin(MandelLayer *ml, MandelBuildPhase phase) {
  MandelBuild *b = &ml->build;
  b->phase = phase;
  b->row = 0;
  if (phase == MANDEL_LOADING_COARSE) {
    b->cw = 8; b->ch = 7; b->shx = 3; b->shy = 3;
  } else if (phase == MANDEL_LOADING_MEDIUM) {
    b->cw = 16; b->ch = 14; b->shx = 2; b->shy = 2;
  } else if (phase == MANDEL_LOADING_FINE) {
    b->cw = 32; b->ch = 28; b->shx = 1; b->shy = 1;
  } else {
    b->cw = DW; b->ch = DH; b->shx = 0; b->shy = 0;
  }
  b->cells_done = 0;
  b->cells_total = (uint16_t)b->cw * b->ch;
}

// Compute one source row, expand it into the canonical far framebuffer, and queue a completed
// eight-pixel tile row. This bounds application work between display frames and keeps the loading
// animation alive throughout all four refinement passes.
static void build_step(MandelLayer *ml, UploadQueue *q) {
  MandelBuild *b = &ml->build;
  if (b->phase == MANDEL_READY) return;

  int16_t dre = (int16_t)(MANDEL_REW / b->cw);
  int16_t dim = (int16_t)(MANDEL_IMW / b->ch);
  int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)b->row * dim);
  uint8_t *src = ml->scratch;

  for (uint8_t x = 0; x < b->cw; x++) {
    int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)x * dre);
    src[x] = mandel_cell(cr, ci, DN);
  }
  b->cells_done = (uint16_t)(b->cells_done + b->cw);

  for (uint8_t sy = 0; sy < (uint8_t)(1u << b->shy); sy++) {
    uint8_t y = (uint8_t)((b->row << b->shy) + sy);
    for (uint8_t x = 0; x < DW; x++)
      fb[(uint16_t)y * DW + x] = src[x >> b->shx];
  }

  b->row++;
  if (((uint8_t)(b->row << b->shy) & 7u) == 0u) {
    uint8_t trow = (uint8_t)(((uint8_t)(b->row << b->shy) >> 3) - 1u);
    build_chr_row(ml, trow);
    upq_push_vram(q, (uint16_t)trow * ROW_BYTES, ml->chrbuf, 0x00, ROW_BYTES,
                  VMAIN_INC_HIGH_1);
  }

  if (b->row == b->ch) {
    if (b->phase == MANDEL_LOADING_FINAL) {
      corpus_result = crc_fb_oop();
      b->phase = MANDEL_READY;
    } else {
      build_begin(ml, (MandelBuildPhase)(b->phase + 1));
    }
  }
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
// Sets up Mode 7 registers and a tiny loading field. Expensive application work belongs in emit()
// so the first display_frame() can release force-blank immediately after the title.
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

  // A high-contrast checker is visible and moving on the first post-title frame.
  //
  // Generated straight into the tiled chr staging buffer. The old form painted the checker across
  // the 64×56 far framebuffer and then read every byte back through build_chr_row() — ~3,584 far
  // stores plus ~3,584 far loads, all under force-blank, which is precisely the 24-frame black
  // window measured between title exit and the loading field (plan #121 startup gate 11, f 239–262).
  // Part 4 of that plan requires reserve() to "install a small deterministic loading texture" and
  // forbids it from computing the full 64×56 grid or uploading all seven final tile rows from it;
  // the round-trip was the violation.
  //
  // The pattern is unchanged. `1u + (((x >> 3) ^ (y >> 3)) & 7u)` is constant over an 8×8 tile
  // (x >> 3 == tcol, y >> 3 == trow), so each tile is one solid colour and the whole texture is
  // 8 tiles × 64 identical bytes per tile-row.
  //
  // Nothing else needs the prefill: every fb byte is written by build_step() before it is read.
  // build_chr_row() only ever runs on a tile-row whose eight source rows have just been written,
  // and even the first (COARSE) pass expands to all 56 rows, so crc_fb_oop() still CRCs a fully
  // written buffer and the 0x204F oracle is untouched. The far buffer keeps being exercised on
  // every build_step().
  for (uint8_t trow = 0; trow < TILES_H; trow++) {
    for (uint8_t tcol = 0; tcol < TILES_W; tcol++) {
      uint8_t v = (uint8_t)(1u + (((uint8_t)(tcol ^ trow)) & 7u));
      __builtin_memset(&ml->chrbuf[(uint16_t)tcol * 64u], v, 64u);
    }
    dma_chr_row((uint16_t)trow * ROW_BYTES, ml->chrbuf, ROW_BYTES);
  }

  // Load palette into CGRAM (direct write, force-blanked).
  load_palette_cgram(ml);
  build_begin(ml, MANDEL_LOADING_COARSE);
}

// emit(): called every frame by scene_emit() — the single virtual dispatch per drawable.
// Enqueues the colour-cycle CGRAM upload and Mode 7 matrix spin+zoom via UPQ_REG pokes.
static void _mandel_emit(Drawable *d, UploadQueue *q) {
  MandelLayer *ml = (MandelLayer *)d;

  // The FIRST emit does no compute. display_frame() releases the boot force-blank at its END,
  // after scene_emit(), so whatever this function does on call 1 runs with the screen still OFF.
  // build_step() is expensive here — 8 escape-time cells, a 512-far-store row expansion, and
  // build_chr_row()'s 512 far loads — and it held the post-title window at 11 black frames when
  // only 4 of those are the splash handoff (docs/plans/2026-08-05-display-first-frame-forceblank.md).
  // Skipping it once costs nothing visible: _mandel_reserve() already painted the loading checker
  // AND loaded CGRAM directly, so frame 1 is a complete picture; refinement simply starts on frame 2,
  // now with the screen ON. 11 -> 5 black frames.
  //
  // Deliberately demo-local. The same skip inside display_frame() would fix every Display demo at
  // once, but 119 of the 122 deliver their palette via upq_push_cgram() from the FIRST emit (the
  // `if (!pal_sent)` idiom), so a release-only first frame renders them with power-on CGRAM — six
  // demos were measured going nondeterministic that way. See the plan's §3 rejected alternatives.
  if (!ml->first_emit_done) {
    ml->first_emit_done = 1;
    return;
  }

  build_step(ml, q);

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
  ml->angle = (uint8_t)(ml->angle + (ml->build.phase == MANDEL_READY ? 1u : 2u));
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
  ml->first_emit_done = 0;
}

// ---------------------------------------------------------------------------
// Main — OOP discipline: zero bare REG_*/snes_* calls; only Display API.

int main(void) {
  static Display    screen;
  static MandelLayer layer;

  m7splash("OOP DRAWABLE", "MANDELBROT", 90);
  display_init(&screen);         // boot bracket: snes_ppu_reset_blank() + NMI + BGMODE_1
  mandel_layer_init(&layer);
  display_add(&screen, (Drawable *)&layer);
  // reserve() painted the animated loading field; refinement begins on the first visible frame.
  for (;;)
    display_frame(&screen);    // scene_emit → _mandel_emit (1 virtual call/frame) → upq_flush
}
