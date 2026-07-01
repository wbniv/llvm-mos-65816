// Signed 64-bit Odometer — #43 of the compiler stress-test demo battery.
// A vast SIGNED odometer ticks through zero (negative -> positive), each value decomposed into decimal
// digits by the v%10 / v/=10 loop (examples/65816/sodo.h — the same odo_digits the host oracle
// tools/sodo-sim.c and the corpus slice run). On a negative operand that loop exercises the
// SIGN-CORRECTED 64-bit divide+modulo libcall. No far pointers -> builds default-8-bit AND +mos-a16
// AND +mos-xy16, so it earns the full 5-way differential bar.
//
// Codegen under test: signed 64-bit divide + modulo. clang merges the adjacent v/10 and v%10 into the
// combined SIGNED libcall __divmoddi4 (distinct from #22's unsigned __udivdi3). A scrolling tape of the
// odometer's values rolls upward through zero.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
#include "snesgfx/title_layer.h"
#include "font8.h"
#include "../65816/sodo.h"

#define ODO_CHR    0x0000u
#define ODO_MAP    0x4000u
#define FONT_BASE  256u
#define ODO_NROWS  28u
#define TAPE_TOP   3u             // first tape row
#define TAPE_BOT   24u            // last (newest) tape row
#define TAPE_ROWS  (TAPE_BOT - TAPE_TOP + 1u)   // 22
#define TICK_FRAMES 3u            // frames between odometer ticks

// BG3 2bpp palettes: 0 = dim green tape, 2 = bright cyan (newest value).
static const uint16_t pal_tape[4] = { SNES_RGB(1,2,3), SNES_RGB(8,20,10), 0, 0 };
static const uint16_t pal_hi[4]   = { SNES_RGB(1,2,3), SNES_RGB(20,31,28), 0, 0 };

// ---------------------------------------------------------------------------
// OdoTape drawable — full-screen 32x28 tilemap; a scrolling tape of signed values.
// ---------------------------------------------------------------------------
typedef struct {
  Drawable base;
  uint16_t map_word;
  uint16_t shadow[ODO_NROWS * 32u];
  uint32_t dirty_rows;            // bit i set -> row i needs re-DMA
} OdoTape;

static void _odo_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  OdoTape *t = (OdoTape *)d;
  snes_vram_addr((uint16_t)(FONT_BASE * 8u));
  for (uint16_t i = 0u; i < (uint16_t)FONT8_N * 8u; i++) REG_VMDATA = FONT8[i];
  REG_BG34NBA = (uint8_t)((ODO_CHR >> 12) & 0x0Fu);
  REG_BG3SC   = SNES_BGSC(t->map_word, 0);
  snes_vram_addr(t->map_word);
  for (uint16_t i = 0u; i < 32u * 32u; i++) REG_VMDATA = (uint16_t)FONT_BASE;
  t->base.tm_bits = TM_BG3;
  t->dirty_rows   = 0u;
}

static void _odo_emit(Drawable *d, UploadQueue *q) {
  OdoTape *t = (OdoTape *)d;
  for (uint8_t r = 0u; r < (uint8_t)ODO_NROWS && q->n < UPQ_MAX_JOBS; r++) {
    if (!(t->dirty_rows & ((uint32_t)1u << r))) continue;      // (uint32_t)1u — width-trap guard
    upq_push_vram(q, (uint16_t)(t->map_word + (uint16_t)r * 32u),
                  &t->shadow[(uint16_t)r * 32u], 0x00u, 32u * 2u, VMAIN_INC_HIGH_1);
    t->dirty_rows &= ~((uint32_t)1u << r);
  }
}

static const DrawableVT ODO_VT = { _odo_reserve, _odo_emit };

// ASCII char -> BG3 tilemap entry (palette `pal`: 0 tape, 2 highlight).
static inline uint16_t _tile(char c, uint8_t pal) {
  uint8_t ch = (uint8_t)c;
  uint16_t base = (ch >= (uint8_t)FONT8_FIRST && ch < (uint8_t)((uint16_t)FONT8_FIRST + FONT8_N))
                    ? (uint16_t)(FONT_BASE + (uint8_t)(ch - (uint8_t)FONT8_FIRST))
                    : (uint16_t)FONT_BASE;
  return (uint16_t)(base | (uint16_t)((uint16_t)pal << 10));
}

typedef struct {
  Display   screen;
  OdoTape   tape;
  int64_t   odo;                  // the live signed odometer value
  uint8_t   phase;                // frame counter for TICK_FRAMES pacing
} App;

volatile uint16_t corpus_result;  // signed-64 divmod fold (read from WRAM by the gate)

// Write a NUL-terminated string into shadow row `row`, centred, using palette `pal`.
static void row_puts(OdoTape *t, uint8_t row, const char *s, uint8_t n, uint8_t pal) {
  uint16_t *sh = &t->shadow[(uint16_t)row * 32u];
  for (uint8_t c = 0u; c < 32u; c++) sh[c] = _tile(' ', pal);
  uint8_t start = (uint8_t)((32u - n) / 2u);
  for (uint8_t i = 0u; i < n; i++) sh[start + i] = _tile(s[i], pal);
  t->dirty_rows |= ((uint32_t)1u << row);
}

// Format the signed odometer value into buf (sign + digits, no leading zeros). Returns length.
// Uses odo_digits -> the SAME sign-corrected __divmoddi4 path the gate asserts.
static uint8_t fmt_odo(int64_t v, char *buf) {
  uint8_t dig[ODO_DIGITS];
  int8_t sign;
  odo_digits(v, dig, &sign);
  uint8_t hi = ODO_DIGITS - 1u;
  while (hi > 0u && dig[hi] == 0u) hi--;          // strip leading zeros
  uint8_t p = 0u;
  buf[p++] = (char)((sign < 0) ? '-' : '+');
  for (int8_t k = (int8_t)hi; k >= 0; k--) buf[p++] = (char)('0' + dig[(uint8_t)k]);
  buf[p] = 0;
  return p;
}

// Tick the odometer one step and scroll it onto the tape.
static void odo_tick(App *a) {
  OdoTape *t = &a->tape;
  // scroll tape up one row: row i <- row i+1
  for (uint8_t r = TAPE_TOP; r < TAPE_BOT; r++) {
    for (uint8_t c = 0u; c < 32u; c++)
      t->shadow[(uint16_t)r * 32u + c] = t->shadow[(uint16_t)(r + 1u) * 32u + c];
    t->dirty_rows |= ((uint32_t)1u << r);
  }
  a->odo += ODO_STEP;
  char buf[24];
  uint8_t n = fmt_odo(a->odo, buf);
  row_puts(t, TAPE_BOT, buf, n, 2u);              // newest value, cyan
}

static void app_init(App *a) {
  display_init(&a->screen);
  a->tape.base.vt = &ODO_VT;
  a->tape.base.tm_bits = 0u;
  a->tape.map_word = ODO_MAP;
  for (uint16_t i = 0u; i < ODO_NROWS * 32u; i++) a->tape.shadow[i] = _tile(' ', 0u);
  a->tape.dirty_rows = 0u;
  display_add(&a->screen, (Drawable *)&a->tape);
  upq_push_cgram(&a->screen.q, 0u, pal_tape, 0x00u, (uint8_t)sizeof pal_tape);
  upq_push_cgram(&a->screen.q, 8u, pal_hi,   0x00u, (uint8_t)sizeof pal_hi);
  a->odo = ODO_BASE;
  a->phase = 0u;
  row_puts(&a->tape, 0u, "SIGNED ODOMETER", 15u, 2u);
  row_puts(&a->tape, 1u, "TICKING THROUGH ZERO", 20u, 0u);
  row_puts(&a->tape, 26u, "INT64  V/10 V%10  __DIVMODDI4", 28u, 0u);
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "SIGNED ODOMETER", "64-BIT DIV+MOD");
  corpus_result = sodo_gate_crc();              // self-verify the signed 64-bit divmod == host 0xD2A2
  title_end(&a.screen, &title, 110);
  for (;;) {
    if (++a.phase >= TICK_FRAMES) { a.phase = 0u; odo_tick(&a); }
    display_frame(&a.screen);
  }
}
