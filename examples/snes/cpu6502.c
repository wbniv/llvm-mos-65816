// 6502/65C02 CPU Disassembler + Simulator — SNES ROM. Demo #102.
//
// Animates through a scrolling disassembly listing of the embedded "hello.c" 6502 program
// one instruction per 16 frames. Top half (canvas y=0..63): 4-line Waldo 16×16 disassembly.
// Bottom half (canvas y=64..127): 8 ALU gate symbols (AND/OR/XOR/ADD/SUB/SHL/SHR/CMP) in
// schematic style; the symbol for the currently-executing instruction lights yellow.
// HUD bars show PC, A, X, Y, SP, flags. No far pointers → 5-way bar (full corpus check).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256   // upload full 128×128 canvas in one v-blank (4 KB)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/cpu6502.h"
#include "font16.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define HOLD_FRAMES 16   // frames per instruction step

volatile uint16_t corpus_result;

// ── Palette ───────────────────────────────────────────────────────────────────
// The Waldo font renders FACE + a SE drop-shadow. For the shadow to read, its colour
// must be distinctly DARK (clearly separated from both the face and the background).
//   0 = background (near-black)
//   1 = SHADOW / inactive gates+wires — dark slate, visible over bg but clearly a shadow
//   2 = dim face (context disasm lines, register text)
//   3 = bright face (current instruction) + active gate
static const uint16_t bg3_pal[4] = {
    SNES_RGB(2,  2,  5),   // 0: background
    SNES_RGB(7,  9,  16),  // 1: drop-shadow / inactive
    SNES_RGB(20, 22, 28),  // 2: dim face / regs
    SNES_RGB(31, 29,  9),  // 3: bright face / active gate
};

// ── Hex helpers ───────────────────────────────────────────────────────────────
static inline char hex_nib(uint8_t v) {
    v &= 0x0Fu;
    return (char)(v < 10u ? (uint8_t)'0' + v : (uint8_t)'A' + v - 10u);
}
static inline void fmt_hex2(char *out, uint8_t v) {
    out[0] = hex_nib((uint8_t)(v >> 4u));
    out[1] = hex_nib(v);
    out[2] = '\0';
}
static inline void fmt_hex4(char *out, uint16_t v) {
    out[0] = hex_nib((uint8_t)((v >> 12u) & 0x0Fu));
    out[1] = hex_nib((uint8_t)((v >>  8u) & 0x0Fu));
    out[2] = hex_nib((uint8_t)((v >>  4u) & 0x0Fu));
    out[3] = hex_nib((uint8_t)( v         & 0x0Fu));
    out[4] = '\0';
}

// ── Direct pixel write (bypass canvas_plot — confirmed broken on 65816 build) ─
static inline void pix(BitmapCanvas *c, uint8_t x, uint8_t y, uint8_t color) {
    if (x >= CANVAS_W || y >= CANVAS_H) return;
    uint16_t tile = (uint16_t)((uint16_t)(y >> 3u) * CANVAS_TILES_W + (x >> 3u));
    uint8_t *t = &c->chr[tile * CANVAS_TILEBYTES + ((y & 7u) << 1u)];
    uint8_t mask = (uint8_t)(0x80u >> (x & 7u));
    if (color & 1u) t[0] |= mask;
    if (color & 2u) t[1] |= mask;
}
static void hline(BitmapCanvas *c, uint8_t x0, uint8_t x1, uint8_t y, uint8_t col) {
    uint8_t x; for (x = x0; x <= x1; x++) pix(c, x, y, col);
}
static void vline(BitmapCanvas *c, uint8_t x, uint8_t y0, uint8_t y1, uint8_t col) {
    uint8_t y; for (y = y0; y <= y1; y++) pix(c, x, y, col);
}

// ── Font8 rendering into canvas ───────────────────────────────────────────────
static void canvas_char8(BitmapCanvas *c, uint8_t px, uint8_t py, char ch, uint8_t color) {
    uint8_t code = (uint8_t)ch;
    if (code < 0x20u || code > 0x5Fu) return;
    const uint16_t *g = &FONT8[(uint16_t)(code - 0x20u) * 8u];
    uint8_t row;
    for (row = 0; row < 8u; row++) {
        uint8_t bits = (uint8_t)g[row];
        uint8_t col;
        for (col = 0; col < 8u; col++)
            if (bits & (uint8_t)(0x80u >> col))
                pix(c, (uint8_t)(px + col), (uint8_t)(py + row), color);
    }
}
static void canvas_str8(BitmapCanvas *c, uint8_t px, uint8_t py, const char *s, uint8_t color) {
    while (*s) { canvas_char8(c, px, py, *s++, color); px = (uint8_t)(px + 8u); }
}

// ── Font16 (Waldo) rendering into canvas ─────────────────────────────────────
// FONT16: 64 glyphs × 32 words = [TL×8, TR×8, BL×8, BR×8]
// word = face_byte | (shadow_byte << 8); bit7 = leftmost pixel.
static void canvas_char16(BitmapCanvas *c, uint8_t px, uint8_t py,
                           char ch, uint8_t fc, uint8_t sc) {
    uint8_t code = (uint8_t)ch;
    if (code < 0x20u || code > 0x5Fu) return;
    uint16_t base = (uint16_t)(code - 0x20u) * 32u;
    uint8_t t, row, col;
    for (t = 0; t < 4u; t++) {
        uint8_t ox = (t == 1u || t == 3u) ? 8u : 0u;
        uint8_t oy = (t == 2u || t == 3u) ? 8u : 0u;
        for (row = 0; row < 8u; row++) {
            uint16_t w = FONT16[base + (uint16_t)t * 8u + row];
            if (!w) continue;                        // empty half-row — skip 8 checks
            uint8_t face = (uint8_t)(w & 0xFFu);
            uint8_t shad = (uint8_t)((w >> 8u) & 0xFFu);
            uint8_t cy = (uint8_t)(py + oy + row);
            for (col = 0; col < 8u; col++) {
                uint8_t bit = (uint8_t)(0x80u >> col);
                uint8_t cx = (uint8_t)(px + ox + col);
                if (face & bit) pix(c, cx, cy, fc);
                else if (sc && (shad & bit)) pix(c, cx, cy, sc);
            }
        }
    }
}
static void canvas_str16(BitmapCanvas *c, uint8_t px, uint8_t py,
                          const char *s, uint8_t fc, uint8_t sc) {
    while (*s) {
        canvas_char16(c, px, py, *s++, fc, sc);
        px = (uint8_t)(px + 16u);
    }
}

// ── Gate symbol drawing ───────────────────────────────────────────────────────
// Gate cell: 28px wide × 14px tall, drawn at (gx, gy) on canvas.
// Inactive: outline in color 1, label in color 1.
// Active: interior fill in color 3, outline in color 3, label in color 0 (inverted).
//
// Gate shapes drawn at pixel precision:
//   AND: flat left + top/bottom edges + D-curve on right
//   OR:  concave left + V-shape right to a point
//   XOR: OR body + extra arc on the left
//   Others: rectangle with symbol inside

// AND gate body (18×12, left-side flat, right-side D-curve approximated with plots)
static void draw_and_shape(BitmapCanvas *c, uint8_t x, uint8_t y, uint8_t col) {
    hline(c, x, (uint8_t)(x+10u), y, col);
    hline(c, x, (uint8_t)(x+10u), (uint8_t)(y+12u), col);
    vline(c, x, y, (uint8_t)(y+12u), col);
    pix(c,(uint8_t)(x+11u),(uint8_t)(y+1u),col);
    pix(c,(uint8_t)(x+13u),(uint8_t)(y+2u),col);
    pix(c,(uint8_t)(x+14u),(uint8_t)(y+3u),col);
    pix(c,(uint8_t)(x+15u),(uint8_t)(y+4u),col);
    pix(c,(uint8_t)(x+16u),(uint8_t)(y+5u),col);
    pix(c,(uint8_t)(x+16u),(uint8_t)(y+6u),col);
    pix(c,(uint8_t)(x+16u),(uint8_t)(y+7u),col);
    pix(c,(uint8_t)(x+15u),(uint8_t)(y+8u),col);
    pix(c,(uint8_t)(x+14u),(uint8_t)(y+9u),col);
    pix(c,(uint8_t)(x+13u),(uint8_t)(y+10u),col);
    pix(c,(uint8_t)(x+11u),(uint8_t)(y+11u),col);
}

static void draw_or_shape(BitmapCanvas *c, uint8_t x, uint8_t y, uint8_t col) {
    hline(c, x, (uint8_t)(x+12u), y, col);
    // top slope to point: draw each step by hand (6 steps for 6px rise over 6px run)
    pix(c,(uint8_t)(x+13u),(uint8_t)(y+1u),col); pix(c,(uint8_t)(x+14u),(uint8_t)(y+2u),col);
    pix(c,(uint8_t)(x+15u),(uint8_t)(y+3u),col); pix(c,(uint8_t)(x+16u),(uint8_t)(y+4u),col);
    pix(c,(uint8_t)(x+17u),(uint8_t)(y+5u),col); pix(c,(uint8_t)(x+18u),(uint8_t)(y+6u),col);
    hline(c, x, (uint8_t)(x+12u), (uint8_t)(y+12u), col);
    // bottom slope to point
    pix(c,(uint8_t)(x+13u),(uint8_t)(y+11u),col); pix(c,(uint8_t)(x+14u),(uint8_t)(y+10u),col);
    pix(c,(uint8_t)(x+15u),(uint8_t)(y+9u),col);  pix(c,(uint8_t)(x+16u),(uint8_t)(y+8u),col);
    pix(c,(uint8_t)(x+17u),(uint8_t)(y+7u),col);
    // concave left
    pix(c,(uint8_t)(x+1u),(uint8_t)(y+3u),col);
    pix(c,(uint8_t)(x+2u),(uint8_t)(y+6u),col);
    pix(c,(uint8_t)(x+1u),(uint8_t)(y+9u),col);
}

static void draw_xor_shape(BitmapCanvas *c, uint8_t x, uint8_t y, uint8_t col) {
    draw_or_shape(c, (uint8_t)(x+3u), y, col);
    pix(c,(uint8_t)(x+0u),(uint8_t)(y+0u),col); pix(c,(uint8_t)(x+0u),(uint8_t)(y+12u),col);
    pix(c,(uint8_t)(x+1u),(uint8_t)(y+3u),col);
    pix(c,(uint8_t)(x+2u),(uint8_t)(y+6u),col);
    pix(c,(uint8_t)(x+1u),(uint8_t)(y+9u),col);
}

static void draw_rect_gate(BitmapCanvas *c, uint8_t x, uint8_t y, uint8_t col) {
    hline(c, x, (uint8_t)(x+19u), y, col);
    hline(c, x, (uint8_t)(x+19u), (uint8_t)(y+12u), col);
    vline(c, x, y, (uint8_t)(y+12u), col);
    vline(c, (uint8_t)(x+19u), y, (uint8_t)(y+12u), col);
}

// Gate positions: 4×2 grid, cells 28px wide × 28px tall (14 gate + 14 for label+spacing)
// y=66 for row 0, y=95 for row 1
static const uint8_t GATE_GX[8] = {0, 32, 64, 96, 0, 32, 64, 96};
static const uint8_t GATE_GY[8] = {66, 66, 66, 66, 95, 95, 95, 95};
static const char GATE_LABEL[8][4] = {"AND","OR ","XOR","ADD","SUB","SHL","SHR","CMP"};
static const GateType GATE_TYPE[8] = {
    GATE_AND, GATE_OR, GATE_XOR, GATE_ADD,
    GATE_SUB, GATE_SHL, GATE_SHR, GATE_CMP
};
// Symbol to render inside rect gates (ADD/SUB/SHL/SHR/CMP)
static const char GATE_SYM[8][4] = {"","","","+","-","<<",">>","<="};

// ── Disassembly rendering ─────────────────────────────────────────────────────
// Build operand string for an instruction at mem[pc].
static void fmt_operand(char *out, uint8_t op, const uint8_t *mem, uint8_t pc) {
    const OpcodeInfo *info = &CPU6502_OPS[op];
    uint8_t arg0 = mem[(uint8_t)(pc + 1u)];
    uint8_t arg1 = mem[(uint8_t)(pc + 2u)];
    char h2[3], h4[5];
    switch (info->am) {
    case AM_IMM:
        fmt_hex2(h2, arg0); out[0]='I'; out[1]='M'; out[2]=' ';
        out[3]=h2[0]; out[4]=h2[1]; out[5]='\0'; break;
    case AM_ZP:
        fmt_hex2(h2, arg0); out[0]=h2[0]; out[1]=h2[1]; out[2]='\0'; break;
    case AM_ZPX:
        fmt_hex2(h2, arg0); out[0]=h2[0]; out[1]=h2[1]; out[2]=' '; out[3]='X'; out[4]='\0'; break;
    case AM_ABS:
        fmt_hex4(h4,(uint16_t)((uint16_t)arg1<<8u)|(uint16_t)arg0);
        out[0]=h4[0];out[1]=h4[1];out[2]=h4[2];out[3]=h4[3];out[4]='\0'; break;
    case AM_REL: {
        uint16_t tgt = (uint16_t)((uint16_t)pc + 2u + (uint16_t)(int8_t)arg0);
        fmt_hex4(h4, tgt);
        out[0]=h4[0];out[1]=h4[1];out[2]=h4[2];out[3]=h4[3];out[4]='\0'; break;
    }
    case AM_IZX:
        fmt_hex2(h2,arg0); out[0]='['; out[1]=h2[0]; out[2]=h2[1]; out[3]='X'; out[4]=']'; out[5]='\0'; break;
    case AM_IZY:
        fmt_hex2(h2,arg0); out[0]='['; out[1]=h2[0]; out[2]=h2[1]; out[3]=']'; out[4]='Y'; out[5]='\0'; break;
    default: out[0]='\0'; break;
    }
}

// ── App struct ────────────────────────────────────────────────────────────────
typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    CPU6502      cpu;
    GateType     last_gate;
    uint8_t      hold;       // counts 0..HOLD_FRAMES-1
    // ring buffer: last 3 PCs before current (for disasm context above current line)
    uint16_t     pc_ring[3];
    uint8_t      ring_head;
} App;

// ── Canvas draw: full redraw each instruction step ────────────────────────────
static void draw_all(App *a) {
    uint16_t i;
    for (i = 0; i < (uint16_t)(CANVAS_NTILES * CANVAS_TILEBYTES); i++)
        a->canvas.chr[i] = 0;

    BitmapCanvas *cv = &a->canvas;

    // ── Divider line ─────────────────────────────────────────────────────────
    { uint8_t x; for (x=0; x<128u; x++) pix(cv,x,63u,1u); }

    // ── Gate panel ───────────────────────────────────────────────────────────
    {
        uint8_t g;
        static const uint8_t GX[8] = {0,32,64,96, 0,32,64,96};
        static const uint8_t GY[8] = {66,66,66,66, 95,95,95,95};
        for (g = 0; g < 8u; g++) {
            uint8_t gx=GX[g], gy=GY[g];
            uint8_t active = (GATE_TYPE[g] == a->last_gate);
            uint8_t col = active ? 3u : 1u;
            // fill if active
            if (active) {
                uint8_t fy;
                for (fy=(uint8_t)(gy+1u); fy<(uint8_t)(gy+12u); fy++) {
                    uint8_t fx;
                    for (fx=(uint8_t)(gx+1u); fx<(uint8_t)(gx+19u); fx++)
                        pix(cv,fx,fy,3u);
                }
            }
            // draw gate shape
            switch (GATE_TYPE[g]) {
            case GATE_AND: draw_and_shape(cv,gx,gy,col); break;
            case GATE_OR:  draw_or_shape(cv,gx,gy,col);  break;
            case GATE_XOR: draw_xor_shape(cv,gx,gy,col); break;
            default:       draw_rect_gate(cv,gx,gy,col);
                           canvas_str8(cv,(uint8_t)(gx+4u),(uint8_t)(gy+3u),
                                       GATE_SYM[g],active?3u:1u);
                           break;
            }
            // wires
            if (gx >= 4u) {
                uint8_t wx;
                for (wx=(uint8_t)(gx-4u);wx<gx;wx++){pix(cv,wx,(uint8_t)(gy+3u),col);pix(cv,wx,(uint8_t)(gy+9u),col);}
            }
            { uint8_t wx;for(wx=(uint8_t)(gx+20u);wx<(uint8_t)(gx+24u);wx++) pix(cv,wx,(uint8_t)(gy+6u),col); }
            canvas_str8(cv,(uint8_t)(gx+1u),(uint8_t)(gy+14u),GATE_LABEL[g],active?3u:1u);
        }
    }

    // ── Disasm panel ─────────────────────────────────────────────────────────
    // Row 2 (highlighted) = the instruction JUST executed — its gate is the one lit.
    // Rows 0,1 = the two before it; row 3 = the next instruction to execute (cpu.pc).
    {
        uint16_t pcs[4];
        pcs[0] = a->pc_ring[(uint8_t)(a->ring_head % 3u)];            // 3 executed ago
        pcs[1] = a->pc_ring[(uint8_t)((a->ring_head + 1u) % 3u)];     // 2 ago
        pcs[2] = a->pc_ring[(uint8_t)((a->ring_head + 2u) % 3u)];     // just executed (lit gate)
        pcs[3] = a->cpu.pc;                                           // next to execute

        uint8_t row;
        for (row = 0; row < 4u; row++) {
            uint16_t pc = pcs[row];
            uint8_t op = a->cpu.mem[(uint8_t)pc];
            uint8_t py = (uint8_t)(row * 16u);
            uint8_t is_cur = (row == 2u);
            // Every line gets the Waldo drop-shadow (colour 1, dark). The current line's
            // FACE is bright (colour 3); context lines are dim (colour 2). No highlight
            // bar — the dark shadow reads against the near-black background, and the
            // brightness of the face is what marks the current instruction.
            uint8_t fc = is_cur ? 3u : 2u;
            uint8_t sc = 1u;
            char abuf[5];
            fmt_hex4(abuf, pc);
            canvas_str16(cv, 0u, py, abuf, fc, sc);
            char mbuf[4];
            mbuf[0]=CPU6502_OPS[op].mnem[0];
            mbuf[1]=CPU6502_OPS[op].mnem[1];
            mbuf[2]=CPU6502_OPS[op].mnem[2];
            mbuf[3]='\0';
            canvas_str16(cv, 68u, py, mbuf, fc, sc);
        }
    }

    // ── Register strip ────────────────────────────────────────────────────────
    {
        char buf[12]; uint8_t p=a->cpu.p;
        buf[0]='A'; fmt_hex2(&buf[1],a->cpu.a); buf[3]=' ';
        buf[4]='X'; fmt_hex2(&buf[5],a->cpu.x); buf[7]=' ';
        buf[8]='Y'; fmt_hex2(&buf[9],a->cpu.y); buf[11]='\0';
        canvas_str8(cv,0u,120u,buf,2u);
        char fb[8];
        fb[0]=(p&FLAG_N)?'N':'n'; fb[1]=(p&FLAG_V)?'V':'v'; fb[2]='-';
        fb[3]=(p&FLAG_D)?'D':'d'; fb[4]=(p&FLAG_I)?'I':'i';
        fb[5]=(p&FLAG_Z)?'Z':'z'; fb[6]=(p&FLAG_C)?'C':'c'; fb[7]='\0';
        canvas_str8(cv,64u,120u,fb,2u);
    }

    a->canvas.lo = 0;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

// ── HUD update ────────────────────────────────────────────────────────────────
static void update_hud(App *a) {
    char buf[33];
    char tmp[5];

    // Top bar: "6502 SIM  #102    PC:XXXX"
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, "6502 SIM  #102    PC:");
    fmt_hex4(tmp, a->cpu.pc);
    text_puts(&a->text, 0, 21, tmp);

    // Bottom bar: the instruction that was JUST executed (matches the highlighted row + lit gate)
    text_clear_bar(&a->text, 1);
    uint16_t exec_pc = a->pc_ring[(uint8_t)((a->ring_head + 2u) % 3u)];
    uint8_t op = a->cpu.mem[(uint8_t)exec_pc];
    const OpcodeInfo *info = &CPU6502_OPS[op];
    buf[0]='S'; buf[1]='P'; buf[2]=':';
    fmt_hex2(&buf[3], a->cpu.sp); buf[5]=' ';
    buf[6]='\0';
    text_puts(&a->text, 1, 0, buf);
    // operand string
    char opbuf[8]; opbuf[0]='\0';
    fmt_operand(opbuf, op, a->cpu.mem, (uint8_t)exec_pc);
    char ibuf[16];
    uint8_t j=0;
    ibuf[j++]=info->mnem[0]; ibuf[j++]=info->mnem[1]; ibuf[j++]=info->mnem[2];
    ibuf[j++]=' '; ibuf[j++]=' ';
    uint8_t k=0;
    while (opbuf[k]) ibuf[j++]=opbuf[k++];
    ibuf[j]='\0';
    text_puts(&a->text, 1, 7, ibuf);
}

// ── App init ──────────────────────────────────────────────────────────────────
static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof(bg3_pal));

    cpu6502_init(&a->cpu);
    a->last_gate = GATE_NONE;
    a->hold = 0;
    a->ring_head = 0;
    a->pc_ring[0] = 0; a->pc_ring[1] = 0; a->pc_ring[2] = 0;
}

// ── Main ──────────────────────────────────────────────────────────────────────
int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin16(&a.screen, &title, "6502 SIM", "CPU");
    corpus_result = cpu6502_gate_crc();
    title_end(&a.screen, &title, 80);

    // Initial draw
    draw_all(&a);
    update_hud(&a);

    for (;;) {
        if (a.hold == 0u) {
            // Store current PC in ring before stepping (ring_head is 0-2 via % 3)
            a.pc_ring[(uint8_t)(a.ring_head % 3u)] = a.cpu.pc;
            a.ring_head = (uint8_t)((a.ring_head + 1u) % 3u);
            // Execute one instruction
            a.last_gate = cpu6502_step(&a.cpu);
            draw_all(&a);
            update_hud(&a);
        }
        a.hold = (uint8_t)((a.hold + 1u) % (uint8_t)HOLD_FRAMES);
        display_frame(&a.screen);
    }
}
