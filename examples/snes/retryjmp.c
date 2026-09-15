// Retry-On-Fault Ladder — #118 of the compiler stress-test battery.
// Round 6 (harden-the-fixes), Cluster G, the RE-ENTRY guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35). Builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar); the headless 5-way gate is corpus/retryjmp_sim.c.
//
// Codegen corner: #116 backtrack varies the unwind DEPTH and #117 csrjmp pins the callee-saved
// RESTORE OFFSETS; this one pins RE-ENTRANCY. ONE setjmp site is re-armed and re-entered 24
// times, each attempt jumping back from a different call depth over a different soft-stack
// high-water mark (rj_work is noinline and recursive with six 16-bit locals live across its
// recursive call, so every level is a real jsr frame over a real soft-stack frame). A defect
// that LEAKS state across re-entries — a soft SP that creeps, an S that only reconstructs
// correctly the first time — drifts the whole outcome sequence rather than corrupting one value.
//
// It is also the demo that found the +mos-xy16 A16-clobber MISCOMPILE: an X16/Y16 soft-stack
// spill is staged through the accumulator, and the allocator was never told, so the 16-bit value
// bound for rj_result[] was destroyed by its own index reload. Fixed 2026-09-15 —
// docs/investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md. The bars below are
// drawn straight out of rj_depth[]/rj_code[]/rj_result[], the arrays the gate CRC folds, so that
// class of defect is visible on screen and not only in a hash.
//
// Visual: a ladder of 24 attempt columns. Each attempt's bar climbs one rung per frame group to
// the depth it actually reached. An attempt that ran clean settles GREEN at its depth; one that
// faulted flashes RED at the fault depth and SNAPS BACK to the baseline — the longjmp — leaving
// a short blue stub as its record. The target depth is a faint tick on every column.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/retryjmp.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define RUNG_H        11    /* canvas pixels per depth level        */
#define BASE_Y       126    /* baseline row of the ladder           */
#define COL_W          4    /* bar width in pixels                  */
#define COL_PITCH      5    /* 24 * 5 = 120, centred in 128         */
#define COL_X0         4

#define CLIMB_FRAMES  4u    /* v-blanks per rung while climbing     */
#define FLASH_FRAMES 14u    /* v-blanks the fault flash is held     */
#define SETTLE_FRAMES 8u    /* v-blanks a finished attempt is held  */
#define SWEEP_FRAMES 120u   /* v-blanks the full ladder is held     */

// BG3 2bpp palette: backdrop, the record stub, a clean attempt, the fault flash.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(1, 1, 5),            // 0: backdrop
    SNES_RGB(5, 8, 18),           // 1: settled stub / target tick
    SNES_RGB(6, 27, 10),          // 2: attempt completed (green)
    SNES_RGB(31, 6, 4),           // 3: faulted — the longjmp (red)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

// Replay state.
static uint8_t  rp_att;     /* attempt being replayed        */
static uint8_t  rp_rung;    /* rungs drawn for it so far     */
static uint16_t rp_hold;    /* frames left in a hold phase   */
static uint8_t  rp_phase;   /* 0 climb, 1 flash, 2 settle, 3 sweep hold */

static void bar_seg(BitmapCanvas *cv, uint8_t att, uint8_t rung, uint8_t color) {
    int16_t x0 = (int16_t)(COL_X0 + (int16_t)att * COL_PITCH);
    int16_t y1 = (int16_t)(BASE_Y - (int16_t)rung * RUNG_H);
    int16_t y0 = (int16_t)(y1 - (RUNG_H - 2));
    for (uint8_t w = (uint8_t)0u; w < (uint8_t)COL_W; w++)
        canvas_line(cv, (int16_t)(x0 + (int16_t)w), y0, (int16_t)(x0 + (int16_t)w), y1, color);
}

static void bar_clear(BitmapCanvas *cv, uint8_t att) {
    int16_t x0 = (int16_t)(COL_X0 + (int16_t)att * COL_PITCH);
    for (uint8_t w = (uint8_t)0u; w < (uint8_t)COL_W; w++)
        canvas_line(cv, (int16_t)(x0 + (int16_t)w), (int16_t)0, (int16_t)(x0 + (int16_t)w),
                    (int16_t)BASE_Y, (uint8_t)0u);
}

// The target tick: how far this attempt WOULD have gone had it not faulted.
static void target_tick(BitmapCanvas *cv, uint8_t att) {
    uint8_t tgt = rj_target_for(att);
    int16_t x0 = (int16_t)(COL_X0 + (int16_t)att * COL_PITCH);
    int16_t y  = (int16_t)(BASE_Y - (int16_t)tgt * RUNG_H);
    if (y < (int16_t)0) y = (int16_t)0;
    canvas_line(cv, x0, y, (int16_t)(x0 + (COL_W - 1)), y, (uint8_t)1u);
}

static void hex16(char *d, uint16_t v) {
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)4u; i++)
        d[i] = (char)("0123456789ABCDEF"[(v >> (uint8_t)(12u - 4u * i)) & (uint16_t)15u]);
}

static void hud(App *a) {
    char buf[21];
    uint8_t att = rp_att;
    buf[0]='A'; buf[1]=(char)('0' + (char)(att / 10u)); buf[2]=(char)('0' + (char)(att % 10u));
    buf[3]=' '; buf[4]='D'; buf[5]=(char)('0' + (char)rj_depth[att]);
    buf[6]='/'; buf[7]=(char)('0' + (char)rj_target_for(att));
    buf[8]=' '; buf[9]='C'; buf[10]=(char)('0' + (char)(rj_code[att] / 10u));
    buf[11]=(char)('0' + (char)(rj_code[att] % 10u));
    buf[12]=' '; buf[13]='R'; buf[14]='=';
    hex16(&buf[15], rj_result[att]);
    buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 1, "RETRYJMP  ONE SITE X24");
}

// One replay step: advance the current attempt's bar, or finish it.
__attribute__((noinline))
static void ladder_step(App *a) {
    BitmapCanvas *cv = &a->canvas;

    if (rp_hold) {
        rp_hold--;
        if (rp_hold != (uint16_t)0u) return;
        if (rp_phase == (uint8_t)1u) {           /* fault flash done -> snap back */
            bar_clear(cv, rp_att);
            target_tick(cv, rp_att);
            bar_seg(cv, rp_att, (uint8_t)0u, (uint8_t)1u);   /* the record stub */
            rp_phase = (uint8_t)2u;
            rp_hold = (uint16_t)SETTLE_FRAMES;
            return;
        }
        if (rp_phase == (uint8_t)3u) {           /* whole ladder held -> restart */
            canvas_clear(cv);
            rp_att = (uint8_t)0u; rp_rung = (uint8_t)0u; rp_phase = (uint8_t)0u;
            target_tick(cv, (uint8_t)0u);
            hud(a);
            return;
        }
        /* settle done -> next attempt */
        rp_att = (uint8_t)(rp_att + 1u);
        if (rp_att >= (uint8_t)RJ_ATTEMPTS) {
            rp_att = (uint8_t)(RJ_ATTEMPTS - 1u);
            rp_phase = (uint8_t)3u;
            rp_hold = (uint16_t)SWEEP_FRAMES;
            return;
        }
        rp_rung = (uint8_t)0u;
        rp_phase = (uint8_t)0u;
        target_tick(cv, rp_att);
        hud(a);
        return;
    }

    /* climbing */
    uint8_t reached = rj_depth[rp_att];
    uint8_t faulted = (uint8_t)(rj_code[rp_att] != (uint8_t)0u);
    if (rp_rung <= reached) {
        bar_seg(cv, rp_att, rp_rung, faulted ? (uint8_t)1u : (uint8_t)2u);
        rp_rung = (uint8_t)(rp_rung + 1u);
        return;
    }
    if (faulted) {                                /* light the whole abandoned run red */
        for (uint8_t r = (uint8_t)0u; r <= reached; r++)
            bar_seg(cv, rp_att, r, (uint8_t)3u);
        rp_phase = (uint8_t)1u;
        rp_hold = (uint16_t)FLASH_FRAMES;
    } else {
        rp_phase = (uint8_t)2u;
        rp_hold = (uint16_t)SETTLE_FRAMES;
    }
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "RETRY ON FAULT LADDER", "RETRYJMP");
    corpus_result = retryjmp_gate_crc();   // expected 0x3388
    title_end(&a.screen, &title, 90);

    rp_att = (uint8_t)0u;
    rp_rung = (uint8_t)0u;
    rp_hold = (uint16_t)0u;
    rp_phase = (uint8_t)0u;
    target_tick(&a.canvas, (uint8_t)0u);
    hud(&a);

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)CLIMB_FRAMES) == (uint16_t)0u)
            ladder_step(&a);
        display_frame(&a.screen);
    }
}
