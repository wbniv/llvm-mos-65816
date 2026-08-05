// #3 Blossom — the interactive on-screen Hopalong attractor on the SNES (Stages 2-4).
//
//   D-pad ....... pan        L / R ...... zoom out / in       A / Y ...... next / prev attractor
//   Select ...... colour mode             Start ...... reset view + attractor
//
// The attractor is accumulated into a 128x128 hit-count grid in high WRAM ($7E2000) via the far
// read-modify-write path (Stage 1) and displayed via Mode 7: the hit count IS the 8bpp pixel (a CGRAM
// index), revealed one tile-row per frame (build_band far-loads a band of the grid into a NEAR buffer
// in tiled order, dma_chr_to DMAs it to VRAM char bytes — one far pointer live per helper, the
// grid_hash idiom that sidesteps the +mos-a16 far-pointer pressure that a far->far whole-image build
// hits). The orbit state persists across frames so the cloud BLOOMS progressively; the 256-entry CGRAM
// palette is rotated every frame for the "wallpaper for the mind" shimmer.
//
// Two differential channels (both built default + +mos-a16, host == target):
//   * grid:  a DETERMINISTIC boot accumulation of K_GATE classic points -> corpus_result == the host
//            oracle (examples/65816/k_blossom_far.c -DHOST -DK_GATE=K_GATE). +mos-a16-only (far grid).
//   * state: the per-frame controller state machine (examples/snes/blossom.h) folded to blossom_crc
//            over a logged pad sequence; dev/jgxcheck.cpp -DJGX_BLOSSOM replays it. NEAR math, so this
//            builds BOTH default and +mos-a16.
//
// Capture / drive: dev/run.sh blossom.  Live play: task blossom-mame (key map in dev/mame-snes-input.cfg).
// Plan: docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md.
#define HOP_GRID 128                              // Rung A: 16 KiB grid in $7E2000 (1:1 with display)
#define HOP_NOINLINE __attribute__((noinline))    // bound +mos-a16 pressure on the far-RMW path
#include <snes.h>
#include "mode7.h"
#include "snesgfx/m7title.h"
#include "../65816/hopalong.h"
#include "blossom.h"
#include "hud.h"

#ifndef K_GATE
#define K_GATE 8000        // deterministic boot accumulation = the grid differential anchor (classic).
                          // The orbit math is ~1 __mulsi3/point (no hw multiplier yet — the plan's
                          // optional perf path), so the live plot runs ~1200 pts/s; 8000 blooms in
                          // ~6-7 s and still resolves the attractor. Multiple of P_FRAME.
#endif
#define P_FRAME   400      // points accumulated per animation-loop pass (bloom granularity)
#define TILES     16       // 128/8 — Mode 7 tiles per axis
#define ROW_BYTES 1024     // one Mode 7 tile-row of character data (16 tiles * 64 bytes)
#define PADLOG_N  64       // bounded, fully-logged verifiable window (frames)

// Mode 7 scroll bias that CENTRES the attractor in the plot box. The pivot (m7_set_center) is the grid
// centre 64,64 = the attractor's geometric centre (orbit starts at 0,0 -> hop_map -> 64,64; the cloud
// spans grid ~18..110). To land grid 64 at the screen centre (128, 112) the Mode 7 scroll must be
// pivot - screen_centre. Pan (cx,cy) adds to this; zoom then magnifies around the centred attractor.
#define PLOT_HBIAS ((int16_t)-64)   // 64 - 128
#define PLOT_VBIAS ((int16_t)-48)   // 64 - 112  (HUD bars are symmetric, so plot-box centre = screen centre)

#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 16 KiB hit grid (the 8bpp source)

HOP_DEFINE_CLEAR(grid_clear, FAR)
HOP_DEFINE_PLOT (grid_plot,  FAR)
HOP_DEFINE_HASH (grid_hash,  FAR)

static const uint8_t m7_zero = 0;                 // fixed-source byte for the tilemap-clear DMA
static uint8_t chrbuf[ROW_BYTES];                 // near: one tile-row staged for DMA
static uint16_t pal[256];                         // near: base CGRAM palette for the current colour mode
static uint16_t cgbuf[256];                       // near: this frame's rotated CGRAM image, staged for DMA
static hop_pt orbit;                              // persistent orbit point (accumulates across frames)

// WRAM proof channels (near .bss; volatile so the per-frame writes survive optimisation).
volatile uint16_t corpus_result;                  // deterministic boot grid hash == host oracle
volatile uint16_t blossom_crc;                    // rolling CRC of per-frame controller state
volatile uint8_t  nframes;                        // frames folded into blossom_crc (<= PADLOG_N)
volatile uint16_t pad_log[PADLOG_N];              // ground-truth pad reads for the host replay

// Build the near base palette for colour `mode` (index 0 = black backdrop). Indices 1..255 are a full
// HUE WHEEL (6 segments, full brightness) so that rotating it (the per-frame cyc shift in
// stage_palette) flows colour through the whole attractor — the "wallpaper for the mind" shimmer. The
// hit count IS the index, so denser regions sit at a different wheel position than sparse edges; the
// mode offsets the starting hue. Rebuilt only on a colour-mode change (the divides are fine off the
// hot path).
static void build_palette(uint8_t mode) {
  pal[0] = 0;                                       // backdrop / no hits = black
  for (uint16_t i = 1; i < 256; i++) {
    uint16_t h = (uint16_t)((i + (uint16_t)mode * 64u) & 0xFFu);   // hue position 0..255, mode-shifted
    uint8_t seg = (uint8_t)(h / 43);                // 0..5
    uint8_t f = (uint8_t)((h % 43) * 31u / 43u);    // 0..31 ramp within the segment
    uint8_t r, g, b;
    switch (seg) {
      case 0:  r = 31;          g = f;           b = 0;            break;   // red -> yellow
      case 1:  r = (uint8_t)(31 - f); g = 31;    b = 0;            break;   // yellow -> green
      case 2:  r = 0;           g = 31;          b = f;            break;   // green -> cyan
      case 3:  r = 0;           g = (uint8_t)(31 - f); b = 31;     break;   // cyan -> blue
      case 4:  r = f;           g = 0;           b = 31;           break;   // blue -> magenta
      default: r = 31;          g = 0;           b = (uint8_t)(31 - f); break; // magenta -> red
    }
    pal[i] = SNES_RGB(r, g, b);
  }
}

// Stage this frame's CGRAM image into near cgbuf (active display): index 0 = black backdrop; indices
// 1..255 are the base palette ROTATED by `cyc` (the shimmer). Done OUT of vblank so the vblank only
// has to fire the DMA.
static void stage_palette(uint8_t cyc) {
  cgbuf[0] = 0;                                    // index 0 = black backdrop
  cgbuf[1] = 0x7FE0;                               // index 1 = CYAN — RESERVED for the HUD (hud.h);
                                                   // kept off the attractor cycle (build_band skips 1)
  for (uint16_t i = 2; i < 256; i++) {
    uint16_t src = i + cyc; while (src > 255) src -= 254;   // rotate within 2..255
    cgbuf[i] = pal[src];
  }
}

// DMA the staged CGRAM image cgbuf -> CGRAM (512 bytes in vblank — far faster + glitch-free vs 512
// hand writes, which spill past vblank into active display and shear the palette across scanlines).
static void dma_cgram(void) {
  REG_CGADD = 0;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x22;              // A->B inc, pattern 0, dest $2122 (CGDATA)
  REG_A1T0L = (uint8_t)(uintptr_t)cgbuf; REG_A1T0H = (uint8_t)((uintptr_t)cgbuf >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x02;              // 512 bytes (256 BGR555 entries)
  REG_MDMAEN = 0x01;
}

// Far-load tile-row `trow` (8 image rows) of the grid into near chrbuf, Mode 7 tiled order (one far
// pointer live -> near writes, the grid_hash idiom). noinline to bound +mos-a16 pressure (handoff §4).
__attribute__((noinline)) static void build_band(uint8_t trow) {
  for (uint8_t tcol = 0; tcol < TILES; tcol++)
    for (uint8_t r = 0; r < 8; r++)
      for (uint8_t c = 0; c < 8; c++) {
        uint8_t x = (uint8_t)(tcol * 8 + c), y = (uint8_t)(trow * 8 + r);
        uint8_t cnt = grid[(uint16_t)((uint16_t)y * HOP_GRID + x)];   // raw hit count (grid is gated)
        // Display index skips CGRAM 1 (reserved for the HUD): 0 stays backdrop, 1..255 -> 2..255.
        chrbuf[(uint16_t)tcol * 64 + (uint16_t)r * 8 + c] = cnt ? (uint8_t)(cnt < 255 ? cnt + 1 : 255) : 0;
      }
}

// DMA ROW_BYTES of character data from near chrbuf into Mode 7 VRAM HIGH bytes at word `destword`.
static void dma_chr_to(uint16_t destword) {
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = destword;
  REG_DMAP0 = 0x00; REG_BBAD0 = 0x19;
  REG_A1T0L = (uint8_t)(uintptr_t)chrbuf; REG_A1T0H = (uint8_t)((uintptr_t)chrbuf >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = (uint8_t)ROW_BYTES; REG_DAS0H = (uint8_t)(ROW_BYTES >> 8);
  REG_MDMAEN = 0x01;
}

// Live HUD value bar: assemble the field strings from the view state (in active display), then
// hud_text them in vblank when something changed. Row 0 = preset name + a/b/c; row 1 = palette + zoom.
// Padded to fixed widths so a shorter value clears the previous one. The bottom legend is static.
static const char *const PRESET_NAME[BLOSSOM_NPRESET] = { "CLASSIC", "DENSE", "BLOOM" };
static char hud_row0[28];   // "<name pad 8>A.. B.. C.."  (padded to 27)
static char hud_row1[20];   // "PALn  ZOOM z.zX"          (padded to 16)

static void hud_build(const blossom_t *v) {
  char *p = hud_row0;
  uint8_t k = 0;
  for (const char *nm = PRESET_NAME[v->preset]; *nm; nm++) { *p++ = *nm; k++; }
  while (k++ < 8) *p++ = ' ';                                  // pad name to 8 cols (a/b/c aligned)
  *p++ = 'A'; p += hud_fmt_q88(BLOSSOM_PA[v->preset], p); *p++ = ' ';
  *p++ = 'B'; p += hud_fmt_q88(BLOSSOM_PB[v->preset], p); *p++ = ' ';
  *p++ = 'C'; p += hud_fmt_q88(BLOSSOM_PC[v->preset], p);
  while (p < hud_row0 + 27) *p++ = ' ';                        // pad to clear any previous longer value
  *p = '\0';

  char *q = hud_row1;
  *q++ = 'P'; *q++ = 'A'; *q++ = 'L'; *q++ = (char)('0' + v->pal);
  *q++ = ' '; *q++ = ' '; *q++ = 'Z'; *q++ = 'O'; *q++ = 'O'; *q++ = 'M'; *q++ = ' ';
  q += hud_fmt_zoom(v->zoom, q);
  while (q < hud_row1 + 16) *q++ = ' ';
  *q = '\0';
}

// Clear all 64 KB of VRAM to 0 (force-blank only). bsnes RANDOMISES power-on VRAM, so the BG layers
// flash garbage the instant the display is enabled. The Mode 7 character rows are only filled one
// band/frame by the render loop, so without a boot clear the plot area shows random tiles for the first
// ~16 frames; clear everything (and preload CGRAM, below) BEFORE m7_show so the first visible frame is
// clean. Two fixed-source DMAs (low byte then high byte of every word) from the zero const.
static void vram_clear_all(void) {
  REG_VMAIN = VMAIN_INC_LOW_1; REG_VMADD = 0;                  // pass 1: every VRAM low byte
  REG_DMAP0 = 0x08; REG_BBAD0 = 0x18;                          // A->B, FIXED source, pattern 0 -> $2118
  REG_A1T0L = (uint8_t)(uintptr_t)&m7_zero; REG_A1T0H = (uint8_t)((uintptr_t)&m7_zero >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x80;                          // 0x8000 bytes = 32768 words
  REG_MDMAEN = 0x01;
  REG_VMAIN = VMAIN_INC_HIGH_1; REG_VMADD = 0;                 // pass 2: every VRAM high byte
  REG_DMAP0 = 0x08; REG_BBAD0 = 0x19;                          // -> $2119
  REG_A1T0L = (uint8_t)(uintptr_t)&m7_zero; REG_A1T0H = (uint8_t)((uintptr_t)&m7_zero >> 8); REG_A1B0 = 0x00;
  REG_DAS0L = 0x00; REG_DAS0H = 0x80;
  REG_MDMAEN = 0x01;
}

int main(void) {
  snes_ppu_reset_blank();
  // Title splash (Mode 7 has no spare BG -> temporary BGMODE_1 BG3 text): ~1.5 s, then restores
  // force-blank + self-clears its VRAM. The grid-hash corpus_result is deterministic (timing-
  // independent), and the controller differential asserts the ROM's CRC against a replay of the
  // ROM's OWN pad log, so the splash's frame shift doesn't change the asserted result.
  blossom_t v;
  m7splash_begin("HOPALONG ATTR", "BLOSSOM");

  // WRAM-only boot work runs behind the live title (snesgfx/m7title.h's handoff contract): the
  // 128x128 grid clear plus the palette build used to sit in the post-title force-blank window.
  // No PPU port is touched here, so it is legal while the splash owns the screen.
  blossom_reset(&v);
  grid_clear(grid);
  orbit.x = 0; orbit.y = 0;
  build_palette(v.pal);                   // fills pal[] in WRAM; stage_palette/dma_cgram below transfer

  m7splash_end(90);                       // hold + 360 spin-out; returns force-blanked

  // From here to m7_show() it is PPU registers and DMA only — the whole force-blank window.
  vram_clear_all();                       // wipe random power-on VRAM before anything can be displayed
  m7_begin();
  m7_tilemap_clear(0x00, (uint16_t)(uintptr_t)&m7_zero, M7_TILEMAP_WORDS);
  m7_tilemap_identity(TILES, TILES);
  m7_set_center(64, 64);                  // pivot the Mode 7 transform around the image centre
  m7_set_matrix(v.zoom, 0x0000, 0x0000, v.zoom);
  m7_set_scroll((uint16_t)PLOT_HBIAS, (uint16_t)PLOT_VBIAS);   // centre the attractor in the plot box
  hud_begin();                            // BG3 text bars + HDMA screen-split (Mode 7 plot box)
  hud_text(HUD_BOT_ROW, 1, "LR ZOOM AY ATTR SEL COL ST RST");   // static control legend
  stage_palette(0); dma_cgram();          // load CGRAM before display (no garbage-colour first frame)
  m7_show();                              // release force-blank; the attractor BLOOMS in live below
  REG_NMITIMEN = NMITIMEN_NMI | NMITIMEN_AUTOJOY; // VBlank pacing + automatic pad latch

  // Accumulation is CAPPED at K_GATE points per attractor: the orbit visits a fixed support, so a
  // capped bloom keeps the background dark (an uncapped accumulate eventually fills every cell). The
  // bloom is progressive (P_FRAME/frame, K_GATE/P_FRAME frames); after it, the grid is static and the
  // cheap 60 fps motion is pure CGRAM palette-cycling. A preset change resets the cap -> re-bloom.
  uint16_t crc = 0xFFFF, done = 0;
  uint8_t  nf = 0, trow = 0, gated = 0;
  uint8_t  hud_p = 0xFF, hud_pal = 0xFF, hud_need = 0; int16_t hud_z = 0;   // HUD value-bar shadow
  for (;;) {
    uint16_t pad = snes_read_pad1_auto();
    blossom_step(&v, pad);
    short a = BLOSSOM_PA[v.preset], b = BLOSSOM_PB[v.preset], c = BLOSSOM_PC[v.preset];
    if (v.preset != hud_p || v.pal != hud_pal || v.zoom != hud_z) {  // value bar changed -> rebuild
      hud_p = v.preset; hud_pal = v.pal; hud_z = v.zoom; hud_build(&v); hud_need = 1;
    }
    if (v.dirty) {                         // preset/reset changed -> clear + re-bloom from scratch
      grid_clear(grid);
      orbit.x = 0; orbit.y = 0;
      build_palette(v.pal);
      done = 0; gated = 0;
    }
    uint16_t chunk = 0;                    // points to plot this frame (0 once fully bloomed)
    if (done < K_GATE) { chunk = (uint16_t)(K_GATE - done); if (chunk > P_FRAME) chunk = P_FRAME; }
    if (chunk) { grid_plot(grid, &orbit, a, b, c, chunk); done = (uint16_t)(done + chunk); }
    build_band(trow);                      // reveal one band (re-uploads the static grid once bloomed)
    stage_palette(v.cyc);                  // build this frame's rotated CGRAM image (active display)

    snes_wait_vblank();                    // --- vblank: DMAs + a few register writes only ---
    dma_chr_to((uint16_t)trow * ROW_BYTES);
    dma_cgram();
    m7_set_matrix(v.zoom, 0x0000, 0x0000, v.zoom);
    m7_set_scroll((uint16_t)(v.cx + PLOT_HBIAS), (uint16_t)(v.cy + PLOT_VBIAS));   // centred + pan
    if (hud_need) {                        // push the rebuilt value bar (vblank: VRAM writable)
      hud_text(HUD_TOP_ROW, 1, hud_row0);
      hud_text((uint8_t)(HUD_TOP_ROW + 1), 1, hud_row1);
      hud_need = 0;
    }
    trow = (uint8_t)((trow + 1) & (TILES - 1));

    // Boot grid gate: once the CLASSIC attractor is fully + deterministically bloomed, hash it ==
    // the host oracle (the differential anchor; preset != 0 blooms aren't the gate).
    if (!gated && done == K_GATE && v.preset == 0) { corpus_result = grid_hash(grid); gated = 1; }

    if (nf < PADLOG_N) {                   // the verifiable controller-math window
      pad_log[nf] = pad;
      crc = blossom_fold(crc, &v);
      nf++;
      blossom_crc = crc;
      nframes = nf;
    }
  }
}
