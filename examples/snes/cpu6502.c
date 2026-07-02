// 6502/65C02 CPU Disassembler + Simulator — SNES ROM. Demo #102. FULL-SCREEN layout.
//
// Simulates a pure 6502/65C02 (8-bit A/X/Y, 16-bit PC) running the 6502-assembly equivalent of
// hello.c, and draws it across the WHOLE 256×224 screen (was a centred 128×128 quarter-screen):
//   • Left rail: a 12-line disassembly listing in the Waldo 16×16 font (address + mnemonic), with
//     operands in font8 using proper 6502 syntax (#$42, $FF, $000E). Current line bright, context dim.
//   • Right rail: the 8 ALU gate symbols; the executed instruction's gate lights up.
//   • Top bar: title + PC.  Bottom bars: live A/X/Y/SP register strip + decoded current instruction.
//
// Renderer: a full-screen BG3 2bpp GLYPH TILEMAP (RAM-efficient — a 32×28 tilemap shadow of 1.8 KB +
// font/gate tiles uploaded once, vs a 14 KB full-screen bitmap that busts low WRAM). Per step only the
// tilemap entries change (which glyph/gate sits in each cell) + a palette bit selecting dim/bright.
// The simulator core (examples/65816/cpu6502.h) and the gate CRC are unchanged → gate stays green.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
#include "../65816/cpu6502.h"
#include "font16.h"
#include "font8.h"

// ── VRAM tile layout (BG3 2bpp, char base 0) ───────────────────────────────────
#define BG3_CHR   0x0000
#define BG3_MAP   0x4000
#define T_F16     0      // font16: glyph g → tiles T_F16 + g*4 + {0=TL,1=TR,2=BL,3=BR}  (256 tiles)
#define T_F8      256    // font8:  glyph g → tile  T_F8 + g                              (64 tiles)
#define T_GATE    320    // gate g: tiles T_GATE + g*6 (3 wide × 2 tall)                  (48 tiles)
#define T_BLANK   T_F8   // font8 space (0x20) is a blank tile

// ── palettes (BG3 sub-palettes; each 4 colours at CGRAM pal*4) ──────────────────
// A glyph tile has FACE in plane0 (colour 1), SHADOW in plane1 (colour 2). Same tiles render
// dim/bright by switching the tilemap palette bits — no duplicate tiles.
#define PAL_DIM    0   // context disasm / regs / title  (col1 = dim face)
#define PAL_BRIGHT 1   // current instruction            (col1 = bright face)
#define PAL_GOFF   2   // inactive gate                  (col1 = dim slate)
#define PAL_GON    3   // active gate                    (col1 = bright yellow)

static const uint16_t cgram[16] = {
  /* pal0 dim    */ SNES_RGB(2,2,5),  SNES_RGB(20,22,28), SNES_RGB(7,9,16),  0,
  /* pal1 bright */ SNES_RGB(2,2,5),  SNES_RGB(31,29,9),  SNES_RGB(7,9,16),  0,
  /* pal2 g-off  */ SNES_RGB(2,2,5),  SNES_RGB(16,20,30), 0,                 0,
  /* pal3 g-on   */ SNES_RGB(2,2,5),  SNES_RGB(31,29,9),  0,                 0,
};

// ── authored 8×8 tiles for '#' and '$' (font8 ships them blank) ────────────────
// 2bpp tile words = plane0 byte (face) | plane1(0). bit7 = leftmost.
static const uint16_t GLYPH_HASH[8]   = {0,0x24,0x7E,0x24,0x7E,0x24,0,0};
static const uint16_t GLYPH_DOLLAR[8] = {0x10,0x7C,0xD0,0x78,0x16,0x7C,0x10,0};

// ── gate shape tiles, rendered once into this WRAM buffer then uploaded ──────────
// 8 gates × 6 tiles (24×16 px) × 8 words. Face bits in plane0 (colour 1).
static uint16_t gate_chr[8 * 6 * 8];

static void gpix(uint8_t g, uint8_t x, uint8_t y) {          // set face pixel (x:0..23,y:0..15)
  if (x >= 24u || y >= 16u) return;
  uint16_t tile = (uint16_t)(g * 6u + (uint16_t)(y >> 3u) * 3u + (x >> 3u));
  gate_chr[tile * 8u + (y & 7u)] |= (uint16_t)(0x80u >> (x & 7u));
}
static void ghline(uint8_t g, uint8_t x0, uint8_t x1, uint8_t y) { uint8_t x; for (x=x0;x<=x1;x++) gpix(g,x,y); }
static void gvline(uint8_t g, uint8_t x, uint8_t y0, uint8_t y1) { uint8_t y; for (y=y0;y<=y1;y++) gpix(g,x,y); }

// AND: flat left + D-curve right.  OR: concave left, pointed right.  XOR: OR + extra arc.
static void draw_gate_shapes(void) {
  uint16_t i;
  for (i = 0; i < (uint16_t)(8*6*8); i++) gate_chr[i] = 0;
  // 0 AND
  ghline(0,0,10,2); ghline(0,0,10,13); gvline(0,0,2,13);
  gpix(0,11,3);gpix(0,13,4);gpix(0,15,5);gpix(0,17,6);gpix(0,18,7);gpix(0,18,8);gpix(0,17,9);gpix(0,15,10);gpix(0,13,11);gpix(0,11,12);
  // 1 OR
  ghline(1,0,12,2); ghline(1,0,12,13);
  gpix(1,13,3);gpix(1,15,4);gpix(1,17,5);gpix(1,19,6);gpix(1,20,7);gpix(1,19,8);gpix(1,17,9);gpix(1,15,10);gpix(1,13,11);
  gpix(1,1,4);gpix(1,2,7);gpix(1,2,8);gpix(1,1,11);
  // 2 XOR  = OR shifted +2 with an extra left arc
  ghline(2,2,12,2); ghline(2,2,12,13);
  gpix(2,13,3);gpix(2,15,4);gpix(2,17,5);gpix(2,19,6);gpix(2,20,7);gpix(2,19,8);gpix(2,17,9);gpix(2,15,10);gpix(2,13,11);
  gpix(2,3,4);gpix(2,4,7);gpix(2,4,8);gpix(2,3,11);
  gpix(2,0,4);gpix(2,1,7);gpix(2,1,8);gpix(2,0,11);
  // 3..7 ADD/SUB/SHL/SHR/CMP  — a box (outline); the label goes beside it in the tilemap
  for (uint8_t k = 3; k < 8; k++) {
    ghline(k,0,17,2); ghline(k,0,17,13); gvline(k,0,2,13); gvline(k,17,2,13);
  }
  // symbols centred in the box (drawn as short strokes)
  ghline(3,6,11,7); gvline(3,8,5,10);                       // ADD  '+'
  ghline(4,6,11,7);                                          // SUB  '-'
  gpix(5,10,5);gpix(5,8,6);gpix(5,6,7);gpix(5,8,8);gpix(5,10,9);      // SHL '<'
  gpix(6,7,5);gpix(6,9,6);gpix(6,11,7);gpix(6,9,8);gpix(6,7,9);       // SHR '>'
  ghline(7,6,11,5); ghline(7,6,11,9);                        // CMP  '='
}

// ── the TextGrid drawable: full-screen 32×28 glyph tilemap ─────────────────────
#define G_COLS 32
#define G_ROWS 28
typedef struct {
  Drawable base;
  uint16_t map[G_COLS * G_ROWS];   // tilemap shadow (1792 bytes)
  uint8_t  dirty;
} TextGrid;

static void _tg_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  REG_BG3SC   = SNES_BGSC(BG3_MAP, 0);                 // 32×32 tilemap
  REG_BG34NBA = (uint8_t)((BG3_CHR >> 12) & 0x0F);     // BG3 char base
  // upload font16 tiles (256 tiles = 2048 words) at word 0
  snes_vram_addr((uint16_t)(T_F16 * 8));
  for (uint16_t i = 0; i < (uint16_t)(FONT16_N * 4 * 8); i++) REG_VMDATA = FONT16[i];
  // upload font8 tiles (64 tiles) at word T_F8*8
  snes_vram_addr((uint16_t)(T_F8 * 8));
  for (uint16_t i = 0; i < (uint16_t)(FONT8_N * 8); i++) REG_VMDATA = FONT8[i];
  // overwrite '#' (glyph 3) and '$' (glyph 4) blanks with authored bitmaps
  snes_vram_addr((uint16_t)((T_F8 + 3) * 8));
  for (uint8_t r = 0; r < 8; r++) REG_VMDATA = GLYPH_HASH[r];
  snes_vram_addr((uint16_t)((T_F8 + 4) * 8));
  for (uint8_t r = 0; r < 8; r++) REG_VMDATA = GLYPH_DOLLAR[r];
  // gate tiles
  draw_gate_shapes();
  snes_vram_addr((uint16_t)(T_GATE * 8));
  for (uint16_t i = 0; i < (uint16_t)(8*6*8); i++) REG_VMDATA = gate_chr[i];
  // palettes
  REG_CGADD = 0;
  for (uint8_t i = 0; i < 16; i++) { REG_CGDATA = (uint8_t)cgram[i]; REG_CGDATA = (uint8_t)(cgram[i] >> 8); }
}

static void _tg_emit(Drawable *d, UploadQueue *q) {
  TextGrid *g = (TextGrid *)d;
  if (!g->dirty) return;
  // DMA the visible 28 rows (896 words). display_frame force-blanks the flush, so size is safe.
  upq_push_vram(q, BG3_MAP, g->map, 0x00, (uint16_t)(G_COLS * G_ROWS * 2), VMAIN_INC_HIGH_1);
  g->dirty = 0;
}

static const DrawableVT TG_VT = { _tg_reserve, _tg_emit };

static void tg_init(TextGrid *g) {
  g->base.vt = &TG_VT;
  g->base.tm_bits = TM_BG3;
  for (uint16_t i = 0; i < G_COLS * G_ROWS; i++) g->map[i] = (uint16_t)T_BLANK;
  g->dirty = 1;
}
static inline void tg_cell(TextGrid *g, uint8_t col, uint8_t row, uint16_t tile, uint8_t pal) {
  if (col >= G_COLS || row >= G_ROWS) return;
  g->map[(uint16_t)row * G_COLS + col] = (uint16_t)(tile | ((uint16_t)pal << 10));
}
static void tg_clear(TextGrid *g) {
  for (uint16_t i = 0; i < G_COLS * G_ROWS; i++) g->map[i] = (uint16_t)T_BLANK;
}
// font8 string at (col,row)
static void tg_str8(TextGrid *g, uint8_t col, uint8_t row, const char *s, uint8_t pal) {
  for (; *s; s++, col++) {
    uint8_t c = (uint8_t)*s;
    if (c < 0x20u || c > 0x5Fu) c = 0x20u;
    tg_cell(g, col, row, (uint16_t)(T_F8 + (c - 0x20u)), pal);
  }
}
// font16 (Waldo) string at (col,row) — each char = 2×2 cells
static void tg_str16(TextGrid *g, uint8_t col, uint8_t row, const char *s, uint8_t pal) {
  for (; *s; s++, col += 2) {
    uint8_t c = (uint8_t)*s;
    if (c < 0x20u || c > 0x5Fu) c = 0x20u;
    uint16_t b = (uint16_t)(T_F16 + (uint16_t)(c - 0x20u) * 4u);
    tg_cell(g, col,   row,   (uint16_t)(b + 0), pal);   // TL
    tg_cell(g, col+1, row,   (uint16_t)(b + 1), pal);   // TR
    tg_cell(g, col,   row+1, (uint16_t)(b + 2), pal);   // BL
    tg_cell(g, col+1, row+1, (uint16_t)(b + 3), pal);   // BR
  }
}
// place gate g's 3×2 tiles at (col,row) with palette
static void tg_gate(TextGrid *g, uint8_t col, uint8_t row, uint8_t gi, uint8_t pal) {
  uint16_t b = (uint16_t)(T_GATE + (uint16_t)gi * 6u);
  for (uint8_t ty = 0; ty < 2u; ty++)
    for (uint8_t tx = 0; tx < 3u; tx++)
      tg_cell(g, (uint8_t)(col+tx), (uint8_t)(row+ty), (uint16_t)(b + ty*3u + tx), pal);
}

// ── hex helpers ─────────────────────────────────────────────────────────────
static inline char hnib(uint8_t v){ v&=0x0Fu; return (char)(v<10u?'0'+v:'A'+v-10u); }
static void hx2(char*o,uint8_t v){ o[0]=hnib((uint8_t)(v>>4)); o[1]=hnib(v); o[2]=0; }
static void hx4(char*o,uint16_t v){ o[0]=hnib((uint8_t)(v>>12)); o[1]=hnib((uint8_t)(v>>8)); o[2]=hnib((uint8_t)(v>>4)); o[3]=hnib((uint8_t)v); o[4]=0; }

// operand string in 6502 syntax (#$imm, $zp/$abs, $target)
static void fmt_oper(char *out, uint8_t op, const uint8_t *mem, uint8_t pc) {
  const OpcodeInfo *in = &CPU6502_OPS[op];
  uint8_t a0 = mem[(uint8_t)(pc+1)], a1 = mem[(uint8_t)(pc+2)];
  char h[5];
  switch (in->am) {
    case AM_IMM: out[0]='#'; out[1]='$'; hx2(h,a0); out[2]=h[0]; out[3]=h[1]; out[4]=0; break;
    case AM_ZP:  out[0]='$'; hx2(h,a0); out[1]=h[0]; out[2]=h[1]; out[3]=0; break;
    case AM_ZPX: out[0]='$'; hx2(h,a0); out[1]=h[0]; out[2]=h[1]; out[3]=','; out[4]='X'; out[5]=0; break;
    case AM_ABS: out[0]='$'; hx4(h,(uint16_t)((uint16_t)a1<<8)|a0); out[1]=h[0];out[2]=h[1];out[3]=h[2];out[4]=h[3];out[5]=0; break;
    case AM_REL: { uint16_t t=(uint16_t)((uint16_t)pc+2u+(uint16_t)(int8_t)a0); out[0]='$'; hx4(h,t); out[1]=h[0];out[2]=h[1];out[3]=h[2];out[4]=h[3];out[5]=0; break; }
    default: out[0]=0; break;
  }
}

// ── App ─────────────────────────────────────────────────────────────────────
#define HOLD_FRAMES 16
volatile uint16_t corpus_result;

static const char GATE_LABEL[8][4] = {"AND","OR ","XOR","ADD","SUB","SHL","SHR","CMP"};
static const GateType GATE_TYPE[8] = {GATE_AND,GATE_OR,GATE_XOR,GATE_ADD,GATE_SUB,GATE_SHL,GATE_SHR,GATE_CMP};

typedef struct {
  Display  screen;
  TextGrid grid;
  CPU6502  cpu;
  GateType last_gate;
  uint8_t  hold;
  uint16_t hist[6];   // last 6 executed PCs (for the scrolling window)
  uint8_t  hh;
} App;

static void draw_all(App *a) {
  TextGrid *g = &a->grid;
  tg_clear(g);
  char buf[16], h[5];

  // ── title bar (row 0) ──
  tg_str8(g, 0, 0, "6502/65C02 CPU SIM", PAL_DIM);
  hx4(h, a->cpu.pc); buf[0]='P';buf[1]='C';buf[2]=' ';buf[3]='$';buf[4]=h[0];buf[5]=h[1];buf[6]=h[2];buf[7]=h[3];buf[8]=0;
  tg_str8(g, 23, 0, buf, PAL_DIM);

  // ── disassembly window (rows 2..25, 12 Waldo lines) ──
  // Line 5 (highlighted) = the instruction JUST executed — its gate is the one lit.
  // Lines 0..4 = the five before it (executed history); lines 6..11 = decoded ahead
  // from the next PC (following an unconditional JMP so the loop body shows, not BRK filler).
  uint16_t win[12]; uint8_t i;
  for (i = 0; i < 6u; i++) win[i] = a->hist[(uint8_t)((a->hh + i) % 6u)];  // oldest..just-executed
  uint16_t pc = a->cpu.pc;
  for (i = 6; i < 12u; i++) {
    win[i] = pc;
    uint8_t nop = a->cpu.mem[(uint8_t)pc];
    pc = (nop == 0x4Cu)                                   // JMP abs → follow the target
       ? (uint16_t)((uint16_t)a->cpu.mem[(uint8_t)(pc+2u)] << 8 | a->cpu.mem[(uint8_t)(pc+1u)])
       : (uint16_t)(pc + CPU6502_OPS[nop].len);
  }
  // line 5 == the just-executed instruction (matches last_gate)
  for (i = 0; i < 12u; i++) {
    uint16_t apc = win[i];
    uint8_t op = a->cpu.mem[(uint8_t)apc];
    uint8_t row = (uint8_t)(2u + i * 2u);
    uint8_t cur = (i == 5u);
    uint8_t pal = cur ? PAL_BRIGHT : PAL_DIM;
    char m[4]; m[0]=CPU6502_OPS[op].mnem[0]; m[1]=CPU6502_OPS[op].mnem[1]; m[2]=CPU6502_OPS[op].mnem[2]; m[3]=0;
    hx4(h, apc);
    tg_str16(g, 0, row, h, pal);        // address (Waldo, cols 0-7)
    tg_str16(g, 9, row, m, pal);        // mnemonic (Waldo, cols 9-14)
    char ob[8]; fmt_oper(ob, op, a->cpu.mem, (uint8_t)apc);
    if (ob[0]) tg_str8(g, 16, row, ob, cur ? PAL_BRIGHT : PAL_DIM);   // operand (font8)
  }

  // ── gate rail (right, cols 24-31, rows 2..25 — 8 gates × 3 rows) ──
  for (i = 0; i < 8u; i++) {
    uint8_t row = (uint8_t)(2u + i * 3u);
    uint8_t on = (GATE_TYPE[i] == a->last_gate);
    tg_gate(g, 24, row, i, on ? PAL_GON : PAL_GOFF);
    tg_str8(g, 28, row, GATE_LABEL[i], on ? PAL_GON : PAL_GOFF);
  }

  // ── register strip (row 26) ──
  buf[0]='A';buf[1]=':';hx2(h,a->cpu.a);buf[2]=h[0];buf[3]=h[1];buf[4]=' ';
  buf[5]='X';buf[6]=':';hx2(h,a->cpu.x);buf[7]=h[0];buf[8]=h[1];buf[9]=' ';
  buf[10]='Y';buf[11]=':';hx2(h,a->cpu.y);buf[12]=h[0];buf[13]=h[1];buf[14]=0;
  tg_str8(g, 0, 26, buf, PAL_DIM);
  { uint8_t p=a->cpu.p; char f[9];
    f[0]=(p&FLAG_N)?'N':'.';f[1]=(p&FLAG_V)?'V':'.';f[2]='-';f[3]=(p&FLAG_D)?'D':'.';
    f[4]=(p&FLAG_I)?'I':'.';f[5]=(p&FLAG_Z)?'Z':'.';f[6]=(p&FLAG_C)?'C':'.';f[7]=0;
    tg_str8(g, 16, 26, "P", PAL_DIM); tg_str8(g, 18, 26, f, PAL_DIM); }

  // ── status bar (row 27): the just-executed instruction (matches the highlighted line) ──
  {
    uint16_t xpc = a->hist[(uint8_t)((a->hh + 5u) % 6u)];
    uint8_t op = a->cpu.mem[(uint8_t)xpc];
    char line[24], ob[8]; uint8_t j=0;
    line[j++]=CPU6502_OPS[op].mnem[0];line[j++]=CPU6502_OPS[op].mnem[1];line[j++]=CPU6502_OPS[op].mnem[2];line[j++]=' ';
    fmt_oper(ob, op, a->cpu.mem, (uint8_t)xpc);
    uint8_t k=0; while (ob[k]) line[j++]=ob[k++];
    line[j]=0;
    tg_str8(g, 0, 27, line, PAL_BRIGHT);
  }

  g->dirty = 1;
}

int main(void) {
  static App a;
  display_init(&a.screen);
  tg_init(&a.grid);
  display_add(&a.screen, (Drawable *)&a.grid);

  cpu6502_init(&a.cpu);
  a.last_gate = GATE_NONE;
  a.hold = 0;
  a.hh = 0;
  for (uint8_t i = 0; i < 6u; i++) a.hist[i] = a.cpu.pc;

  corpus_result = cpu6502_gate_crc();

  draw_all(&a);
  for (;;) {
    if (a.hold == 0u) {
      a.hist[a.hh % 6u] = a.cpu.pc;
      a.hh = (uint8_t)((a.hh + 1u) % 6u);
      a.last_gate = cpu6502_step(&a.cpu);
      draw_all(&a);
    }
    a.hold = (uint8_t)((a.hold + 1u) % (uint8_t)HOLD_FRAMES);
    display_frame(&a.screen);
  }
}
