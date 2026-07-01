// GF(2^8) Galois Field — #55 of the compiler stress-test demo battery.
// Renders the verified, portable finite-field arithmetic (examples/65816/gf256.h — the same header the
// host oracle tools/gf256-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each cell's colour is a GF(2^8) combination gf_mul(A, α^x) ^ gf_mul(B, α^y), where A and B rotate
// through the α-powers each frame — a morphing "finite-field plaid". The field multiply is a CARRYLESS
// multiply: two log-table lookups + an add + an antilog-table lookup (no carry chain), the arithmetic
// under Reed-Solomon / QR codes. The HUD tracks a live RS syndrome of a message that is periodically
// corrupted (non-zero syndrome = error detected). A codegen corner none of the first 54 demos run.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/gf256.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4

// BG3 2bpp palette (CGRAM 0..3): deep violet -> teal -> gold -> white (a "Galois" ramp).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(6, 2, 14), SNES_RGB(4, 24, 22), SNES_RGB(31, 24, 6), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint8_t      colv[NCELL];   // α^x column field elements
  uint8_t      rowv[NCELL];   // α^y row field elements
  uint8_t      synd_shown;    // last syndrome written to the HUD
} App;

volatile uint16_t corpus_result;  // GF(2^8) gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute the whole GF texture. A,B are α-powers that rotate with the frame. noinline caps pressure.
__attribute__((noinline))
static void field_step(App *a) {
  uint8_t A = gf_pow_alpha((uint8_t)(a->frame & 0xFFu));
  uint8_t B = gf_pow_alpha((uint8_t)((a->frame >> 1) & 0xFFu));
  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint8_t e = (uint8_t)(gf_mul(A, a->colv[cx]) ^ gf_mul(B, a->rowv[cy]));  // GF plaid
      uint8_t col = (uint8_t)(((e >> 6) ^ (e >> 1)) & 3u);
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

// Update the HUD RS syndrome: encode a 16-symbol message, corrupt one symbol on a cycle, show S_1.
static void hud_syndrome(App *a) {
  uint8_t msg[16];
  for (uint8_t k = 0; k < 16; k++)
    msg[k] = (uint8_t)((k << 4) ^ (uint8_t)(k << 1) ^ (uint8_t)(a->frame >> 4));
  // corrupt one symbol every other 128-frame window -> syndrome becomes non-zero
  if (a->frame & 0x80u) msg[(a->frame >> 2) & 0x0Fu] ^= 0x5Au;
  uint8_t s1 = rs_syndrome(msg, 16u, 1u);
  if (s1 == a->synd_shown) return;
  a->synd_shown = s1;
  char line[21];
  const char *hex = "0123456789ABCDEF";
  // "RS SYNDROME S1=XX  [OK|ERR]"
  static const char pfx[] = "RS SYNDROME S1=";
  uint8_t i = 0;
  for (; pfx[i]; i++) line[i] = pfx[i];
  line[i++] = hex[(s1 >> 4) & 0xF];
  line[i++] = hex[s1 & 0xF];
  line[i++] = ' ';
  const char *tag = (s1 == 0u) ? "OK " : "ERR";
  line[i++] = tag[0]; line[i++] = tag[1]; line[i++] = tag[2];
  while (i < 20u) line[i++] = ' ';
  line[20] = '\0';
  text_puts(&a->text, 1, 0, line);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  gf_init();
  for (uint8_t k = 0; k < NCELL; k++) { a->colv[k] = gf_pow_alpha((uint8_t)(k + 1u));
                                        a->rowv[k] = gf_pow_alpha((uint8_t)(k + 17u)); }
  a->frame = 0u;
  a->synd_shown = 0xFFu;
  text_puts(&a->text, 0, 1, "GF(2^8) A=2 POLY=11D");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "GALOIS FIELD", "REED-SOLOMON GF256");
  corpus_result = gf256_gate_crc();             // self-verify the field math == host 0xC028
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    hud_syndrome(&a);
    field_step(&a);
    display_frame(&a.screen);
  }
}
