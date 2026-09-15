// Callee-Saved Restore Curve — #117 of the compiler stress-test battery.
// Round 6 (harden-the-fixes), Cluster G, the CSR-RESTORE-OFFSET guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35). Builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar); the headless 5-way gate is corpus/csrjmp_sim.c.
//
// Codegen corner: jmp_buf carries csrs[14] — the __rc18..__rc31 callee-saved block. #116
// backtrack varies the UNWIND DEPTH; this one pins the restore OFFSETS. 14 coefficient bytes
// live in locals across a setjmp while a noinline worker keeps 14 of its own byte values live
// across calls (so it owns every callee-saved slot) and then longjmps, bypassing the epilogue
// that would otherwise put the caller's values back. Only longjmp's csrs[] restore can recover
// them, and an off-by-one in those offsets corrupts exactly one coefficient.
//
// Visual: the six restored coefficient sets each drive a harmonograph — two detuned sine terms
// per axis under a decaying envelope, through a 32-bit multiply chain (__mulsi3). The curves
// draw stroke by stroke and cycle. One corrupted coefficient warps exactly one axis.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/csrjmp.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STROKE_FRAMES 2u    /* v-blanks per drawn curve segment */
#define HOLD_FRAMES  90u    /* v-blanks the finished curve is held before the next pass */

// BG3 2bpp palette: black, the curve's two strokes, and the bright head of the pen.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(4, 10, 20),          // 1: settled stroke
    SNES_RGB(10, 22, 30),         // 2: recent stroke
    SNES_RGB(31, 28, 12),         // 3: pen head
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  cv_pass;      /* coefficient set being drawn */
static uint8_t  cv_samp;      /* next sample index           */
static uint16_t cv_hold;      /* frames left holding a finished curve */
static int16_t  cv_px, cv_py; /* previous sample, canvas space        */

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 1, "CSRJMP  RC18-RC31 RESTORE");
}

// Draw the next segment of the current pass's curve from its RESTORED coefficient vector.
__attribute__((noinline))
static void stroke_step(BitmapCanvas *cv) {
    if (cv_hold) {                       /* holding the finished curve */
        cv_hold--;
        if (cv_hold == (uint16_t)0u) {
            cv_pass = (uint8_t)((uint8_t)(cv_pass + 1u) % (uint8_t)CJ_PASSES);
            cv_samp = (uint8_t)0u;
            canvas_clear(cv);
        }
        return;
    }
    int16_t x, y;
    cj_point(cj_obs[cv_pass], cv_samp, &x, &y);
    if (cv_samp != (uint8_t)0u) canvas_line(cv, cv_px, cv_py, x, y, (uint8_t)2u);
    canvas_plot(cv, x, y, (uint8_t)3u);
    cv_px = x; cv_py = y;
    cv_samp++;
    if (cv_samp >= (uint8_t)CJ_NSAMP) cv_hold = (uint16_t)HOLD_FRAMES;
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "CALLEE-SAVED RESTORE", "CSRJMP");
    corpus_result = csrjmp_gate_crc();   // expected 0xADD8
    title_end(&a.screen, &title, 90);

    cv_pass = (uint8_t)0u;
    cv_samp = (uint8_t)0u;
    cv_hold = (uint16_t)0u;
    cv_px = (int16_t)64; cv_py = (int16_t)64;

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STROKE_FRAMES) == (uint16_t)0u) {
            stroke_step(&a.canvas);
            char buf[21];
            buf[0]='S'; buf[1]='E'; buf[2]='T'; buf[3]=' '; buf[4]=(char)('1' + (char)cv_pass);
            buf[5]='/'; buf[6]=(char)('0' + (char)CJ_PASSES);
            buf[7]=' '; buf[8]='C'; buf[9]='0'; buf[10]='=';
            uint8_t c0 = cj_obs[cv_pass][0];
            buf[11] = (char)("0123456789ABCDEF"[(c0 >> 4) & 15u]);
            buf[12] = (char)("0123456789ABCDEF"[c0 & 15u]);
            buf[13]=' '; buf[14]='C'; buf[15]='D'; buf[16]='=';
            uint8_t c13 = cj_obs[cv_pass][13];
            buf[17] = (char)("0123456789ABCDEF"[(c13 >> 4) & 15u]);
            buf[18] = (char)("0123456789ABCDEF"[c13 & 15u]);
            buf[19]=' '; buf[20]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
