// Multi-Base Clock — #60 of the compiler stress-test demo battery.
// Renders the verified, portable multi-base odometer (examples/65816/multibase.h — the same header the
// host oracle tools/multibase-sim.c and the corpus slice run) as stacked numeric read-outs, so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// One climbing counter is shown in four bases at once — decimal, dozenal, hex and sexagesimal — each
// digit split with the libc div() returning a div_t (quotient+remainder) BY VALUE, plus a 64-bit
// odometer via lldiv() returning an lldiv_t. The corner: the div_t/lldiv_t AGGREGATE-RETURN ABI braided
// with the custom G_SDIVREM legalizer (MOSLegalizerInfo.cpp:229). A codegen path none of the first 59
// demos run (#39 used the `/`,`%` operators; #43 raw signed 64-bit divmod).
#include <snes.h>
#include "snesgfx/display.h"
#include "font8.h"
#include "snesgfx/title_layer.h"
#include "../65816/multibase.h"

#define FONT_BASE   256
#define MB_MAP      0x4000
#define MB_ROWS     22
#define MB_COLS     28
#define MB_ORIGIN_ROW 3         // first tilemap row the grid occupies

typedef struct {
  Drawable base;
  uint16_t map_word;
  uint16_t shadow[MB_ROWS * MB_COLS];
  uint32_t dirty;               // bit r -> row r needs re-DMA
} MbHud;

typedef struct {
  Display screen;
  MbHud   hud;
  uint16_t frame;
  uint16_t counter;             // < 32768 (div_t / 16-bit int safe)
  uint64_t odo;                 // 64-bit odometer (lldiv)
} App;

volatile uint16_t corpus_result;  // multi-base gate CRC (read from WRAM by the differential gate)

static void _mb_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  MbHud *l = (MbHud *)d;
  snes_vram_addr((uint16_t)(FONT_BASE * 8));
  for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8u; i++) REG_VMDATA = FONT8[i];
  REG_BG34NBA = 0x00u;                                 // BG3 chr base word 0 (glyphs at tile 256)
  REG_BG3SC = SNES_BGSC(l->map_word, 0);
  // Clear the WHOLE 32x32 BG3 tilemap to the space glyph (FONT_BASE), else uninitialised VRAM shows as
  // garbage stripes outside our text region (the demo-display-dirty-mask-width trap). Force-blank: OK.
  snes_vram_addr(l->map_word);
  for (uint16_t i = 0; i < 32u * 32u; i++) REG_VMDATA = FONT_BASE;
  for (uint16_t i = 0; i < MB_ROWS * MB_COLS; i++) l->shadow[i] = FONT_BASE;   // spaces
  l->base.tm_bits = TM_BG3;
  l->dirty = (uint32_t)((1uL << MB_ROWS) - 1uL);
}

static void _mb_emit(Drawable *d, UploadQueue *q) {
  MbHud *l = (MbHud *)d;
  for (uint8_t r = 0; r < MB_ROWS && q->n < UPQ_MAX_JOBS; r++) {
    if (!(l->dirty & (uint32_t)(1uL << r))) continue;
    upq_push_vram(q, (uint16_t)(l->map_word + (uint16_t)(MB_ORIGIN_ROW + r) * 32u + 2u),
                  &l->shadow[(uint16_t)r * MB_COLS], 0x00u, MB_COLS * 2u, VMAIN_INC_HIGH_1);
    l->dirty &= ~(uint32_t)(1uL << r);
  }
}

static const DrawableVT MB_VT = { _mb_reserve, _mb_emit };

// Write a string into hud row/col (glyph = FONT_BASE + (ch-0x20) for 0x20..0x5F, else space).
static void mb_puts(MbHud *l, uint8_t row, uint8_t col, const char *s) {
  uint16_t *r = &l->shadow[(uint16_t)row * MB_COLS];
  for (; *s && col < MB_COLS; s++, col++) {
    uint8_t ch = (uint8_t)*s;
    r[col] = (ch >= 0x20u && ch < (uint8_t)(0x20u + FONT8_N))
             ? (uint16_t)(FONT_BASE + (ch - 0x20u)) : FONT_BASE;
  }
  l->dirty |= (uint32_t)(1uL << row);
}

// Format v (base<=16) into buf as up-to ndig glyph chars, MSD first, zero-padded. Uses div_t.
static void fmt_base(uint16_t v, uint8_t base, char *buf, uint8_t ndig) {
  uint8_t digs[8];
  (void)mb_to_base(v, base, digs, ndig);           // div_t per digit (the corner)
  for (uint8_t i = 0; i < ndig; i++) {
    uint8_t dd = digs[ndig - 1u - i];
    buf[i] = (char)((dd < 10u) ? ('0' + dd) : ('A' + dd - 10u));
  }
  buf[ndig] = '\0';
}

// Format v as sexagesimal groups "AA BB CC" (each 0..59 -> two decimal chars). Uses div_t (base 60).
static void fmt_sex(uint16_t v, char *buf) {
  uint8_t digs[4];
  (void)mb_to_base(v, 60u, digs, 3u);
  uint8_t p = 0;
  for (uint8_t i = 0; i < 3u; i++) {
    uint8_t d = digs[2u - i];
    buf[p++] = (char)('0' + d / 10u);
    buf[p++] = (char)('0' + d % 10u);
    if (i < 2u) buf[p++] = ' ';
  }
  buf[p] = '\0';
}

// Format a 64-bit odometer as decimal, up to 15 digits, MSD first. Uses lldiv_t.
static void fmt_odo(uint64_t v, char *buf) {
  uint8_t digs[16];
  uint8_t n = mb_to_base64(v, 10u, digs, 15u);     // lldiv per digit (the corner)
  for (uint8_t i = 0; i < n; i++) buf[i] = (char)('0' + digs[n - 1u - i]);
  buf[n] = '\0';
}

static void redraw(App *a) {
  char buf[20];
  fmt_base(a->counter, 10u, buf, 5u); mb_puts(&a->hud, 4, 8, buf);   // DECIMAL
  fmt_base(a->counter, 12u, buf, 5u); mb_puts(&a->hud, 6, 8, buf);   // DOZENAL
  fmt_base(a->counter, 16u, buf, 4u); mb_puts(&a->hud, 8, 8, buf);   // HEX
  fmt_sex (a->counter, buf);          mb_puts(&a->hud, 10, 8, buf);  // SEXAGESIMAL
  fmt_odo (a->odo, buf);              mb_puts(&a->hud, 14, 6, buf);  // 64-BIT ODOMETER (lldiv)
}

static void app_init(App *a) {
  display_init(&a->screen);
  a->hud.base.vt = &MB_VT;
  a->hud.map_word = MB_MAP;
  display_add(&a->screen, (Drawable *)&a->hud);
  a->frame = 0u;
  a->counter = 0u;
  a->odo = 1u;
  mb_puts(&a->hud, 1, 4, "MULTI-BASE CLOCK");
  mb_puts(&a->hud, 4, 0, "DEC 10");
  mb_puts(&a->hud, 6, 0, "DOZ 12");
  mb_puts(&a->hud, 8, 0, "HEX 16");
  mb_puts(&a->hud, 10, 0, "SEX 60");
  mb_puts(&a->hud, 13, 0, "ODOMETER (lldiv)");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "MULTI-BASE", "div_t / lldiv_t");
  corpus_result = multibase_gate_crc();         // self-verify the div_t/lldiv_t math == host 0xF43F
  title_end(&a.screen, &title, 110);
  redraw(&a);                                    // draw the initial read-out before the loop
  for (;;) {
    a.frame++;
    if ((a.frame & 7u) == 0u) {                 // tick every 8th frame
      a.counter = (uint16_t)((a.counter + 1u) & 0x7FFFu);
      a.odo = a.odo * 3u + 7u;
      if (a.odo >= 1000000000000000000ULL) a.odo = 1u;
      redraw(&a);
    }
    display_frame(&a.screen);
  }
}
