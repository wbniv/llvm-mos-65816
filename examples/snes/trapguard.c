// Unreachable Sentinel — #150 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster B. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/trapguard_sim.c.
//
// Codegen corner: G_TRAP .custom() (MOSLegalizerInfo.cpp:448; legalizeTrap emits an
// RTLIB::ABORT libcall, so it lands as `jsr abort`). __builtin_trap / __builtin_unreachable
// are used ZERO times across demos #1-#141.
//
// HONEST FRAMING, not softened: a trap terminates, so it can never be TAKEN in a gate run.
// This is a PRESENCE-AND-INERTNESS probe — weaker than #142-#145. What is asserted is that
// the trap is formed and reaches the ROM, and that its presence leaves the surrounding
// dispatch's codegen and flag liveness alone (the reachable trace is bit-identical in all
// three modes and matches the host).
//
// Visual: the six states around a ring. Legal transitions are drawn as bright edges and light
// up as the machine takes them; the four guarded-impossible transitions are drawn once, dim,
// and never light — they are the arms behind the trap.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/trapguard.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   5u
#define HOLD_FRAMES 120u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(9, 9, 11),           // 1: a guarded-impossible edge — behind the trap, never lit
    SNES_RGB(6, 18, 28),          // 2: a legal edge
    SNES_RGB(31, 27, 10),         // 3: the transition just taken / the current state
};

/* State ring positions, fixed so the picture is stable frame to frame. */
static const int8_t tg_x[TG_NS] = { 64, 106, 106,  64,  22,  22 };
static const int8_t tg_y[TG_NS] = { 14,  38,  86, 110,  86,  38 };

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t tv_i;
static uint16_t tv_hold;
static uint8_t  tv_state;

static const char hexd[17] = "0123456789ABCDEF";

static void node(BitmapCanvas *cv, uint8_t s, uint8_t color) {
    for (int16_t dy = (int16_t)-4; dy <= (int16_t)4; dy++)
        for (int16_t dx = (int16_t)-4; dx <= (int16_t)4; dx++)
            canvas_plot(cv, (int16_t)((int16_t)tg_x[s] + dx),
                            (int16_t)((int16_t)tg_y[s] + dy), color);
}

// The static skeleton: every legal edge bright, every guarded-impossible edge dim. Drawing
// the impossible ones at all is the point of the picture — they are the arms the trap covers.
__attribute__((noinline))
static void draw_graph(BitmapCanvas *cv) {
    canvas_clear(cv);
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++) {
        for (uint8_t e = (uint8_t)0u; e < (uint8_t)TG_NE; e++) {
            uint8_t legal = (uint8_t)((tg_legal[s] >> e) & (uint8_t)1u);
            uint8_t dst = (uint8_t)((uint8_t)(s + (uint8_t)1u + e) % (uint8_t)TG_NS);
            canvas_line(cv, (int16_t)tg_x[s], (int16_t)tg_y[s],
                            (int16_t)tg_x[dst], (int16_t)tg_y[dst],
                            legal ? (uint8_t)2u : (uint8_t)1u);
        }
    }
    for (uint8_t s = (uint8_t)0u; s < (uint8_t)TG_NS; s++) node(cv, s, (uint8_t)2u);
}

__attribute__((noinline))
static void trace_step(BitmapCanvas *cv) {
    if (tv_hold) {
        tv_hold--;
        if (tv_hold == (uint16_t)0u) { tv_i = (uint16_t)0u; draw_graph(cv); }
        return;
    }
    if (tv_i >= tg_ntrace) { tv_hold = (uint16_t)HOLD_FRAMES; return; }

    uint8_t prev = tv_state;
    uint8_t rec  = tg_trace[tv_i];
    tv_state = (uint8_t)((rec >> 4) & 7u);
    if (tv_state >= (uint8_t)TG_NS) tv_state = (uint8_t)0u;

    node(cv, prev, (uint8_t)2u);
    canvas_line(cv, (int16_t)tg_x[prev], (int16_t)tg_y[prev],
                    (int16_t)tg_x[tv_state], (int16_t)tg_y[tv_state], (uint8_t)3u);
    node(cv, tv_state, (uint8_t)3u);
    tv_i = (uint16_t)(tv_i + 1u);
}

int main(void) {
    static App a;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a.text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a.t = (uint16_t)0u;
    text_puts(&a.text, 0, 1, "TRAPGUARD  GUARDED ARMS");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "GUARDED STATES", "TRAPGUARD");
    corpus_result = trapguard_gate_crc();   // expected 0x2C2D
    title_end(&a.screen, &title, 90);

    tv_i = (uint16_t)0u;
    tv_hold = (uint16_t)0u;
    tv_state = (uint8_t)0u;
    draw_graph(&a.canvas);

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            trace_step(&a.canvas);
            char buf[25];
            buf[0]='S'; buf[1]='=';
            buf[2]=(char)hexd[tv_state & 15u];
            buf[3]=' '; buf[4]='T'; buf[5]='=';
            buf[6]=(char)hexd[(tv_i >> 8) & 15u];
            buf[7]=(char)hexd[(tv_i >> 4) & 15u];
            buf[8]=(char)hexd[tv_i & 15u];
            buf[9]=' '; buf[10]='G'; buf[11]='=';
            buf[12]=(char)hexd[(tg_guarded >> 8) & 15u];
            buf[13]=(char)hexd[(tg_guarded >> 4) & 15u];
            buf[14]=(char)hexd[tg_guarded & 15u];
            buf[15]=' '; buf[16]='U'; buf[17]='N'; buf[18]='V'; buf[19]='=';
            buf[20]=(char)hexd[tg_legal_unvisited() & 15u];
            buf[21]=' '; buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
