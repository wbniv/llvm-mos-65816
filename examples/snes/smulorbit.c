// Signed Multiply-Overflow Orbit Sentinel — #76 of the compiler stress-test battery.
// Renders an orbit-scatter on a 128x128 BG3 canvas using __builtin_mul_overflow on
// int16_t and int32_t operands.  Builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar).
//
// Codegen corners:
//   (1) G_SMULO at s16: __builtin_mul_overflow(vx16, sf, &scaled) -> lowerMulo at
//       LegalizerHelper.cpp:2693 (widen-multiply-sign-check, not a libcall itself)
//   (2) G_SMULO at s32: int32_t overflow check -> compiler-rt __mulosi4
//       First demo to link __mulosi4; distinct from #44 (G_UADDO) and #56 (G_SMULH)
//
// Visual: 6 orbiters trace looping paths on the canvas.  When signed overflow fires
// (velocity * growing_scale overflows int16_t), the orbiter teleports to the mirror
// quadrant and leaves a bright orange spark.  The growing scale_factor (t/4 + 1)
// causes periodic teleports; the orbit density builds up over time.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/smulorbit.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

// BG3 2bpp palette: black → dim trail → medium trail → bright overflow spark.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(4, 4, 18),           // 1: dim orbit trail (dark blue)
    SNES_RGB(6, 14, 28),          // 2: medium trail (brighter blue)
    SNES_RGB(31, 18, 2),          // 3: overflow spark (bright orange)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    SOrbiter     orbs[SO_N];
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    so_init(a->orbs);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 2, "SMULO ORBIT  G_SMULO");
}

// Fade the canvas by XOR-ing every 8th pixel: dims old trails without full clear.
__attribute__((noinline))
static void fade_canvas(BitmapCanvas *cv) {
    // Every frame, XOR a stripe of the chr to dim the trails.
    // We walk through all tiles but only touch the planes selectively.
    for (uint16_t t = 0u; t < (uint16_t)CANVAS_NTILES; t += (uint16_t)4u) {
        uint8_t *p = &cv->chr[t * (uint16_t)CANVAS_TILEBYTES];
        // Clear plane-0 (dim bit) to fade colors 1→0, 3→2
        for (uint8_t r = 0u; r < 8u; r++) p[r * 2u] = (uint8_t)(p[r * 2u] >> 1);
    }
    // Mark all dirty
    cv->lo = (uint16_t)0u;
    cv->hi = (uint16_t)(CANVAS_NTILES - 1u);
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "SMULO ORBIT", "SIGNED MUL OVERFLOW");
    corpus_result = smulorbit_gate_crc();   // expected 0xD81B
    title_end(&a.screen, &title, 90);

    uint16_t spark_count = (uint16_t)0u;
    for (;;) {
        a.t++;
        // Fade trails every 8 frames
        if ((a.t & (uint16_t)7u) == (uint16_t)0u) fade_canvas(&a.canvas);
        // Step and plot each orbiter
        for (uint8_t i = 0u; i < (uint8_t)SO_N; i++) {
            SOrbiter *o = &a.orbs[i];
            uint8_t color = so_step(o, a.t);
            if (color == (uint8_t)3u) spark_count++;
            canvas_plot(&a.canvas, (int16_t)o->px, (int16_t)o->py, color);
        }
        // Update HUD: show spark count
        char buf[21];
        buf[0]='O'; buf[1]='V'; buf[2]='F'; buf[3]='L'; buf[4]='O'; buf[5]='W';
        buf[6]='S'; buf[7]=':'; buf[8]=' ';
        buf[9]=(char)('0' + (char)((spark_count / (uint16_t)1000u) % (uint16_t)10u));
        buf[10]=(char)('0' + (char)((spark_count / (uint16_t)100u) % (uint16_t)10u));
        buf[11]=(char)('0' + (char)((spark_count / (uint16_t)10u) % (uint16_t)10u));
        buf[12]=(char)('0' + (char)(spark_count % (uint16_t)10u));
        buf[13]=' '; buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' ';
        buf[19]=' '; buf[20]='\0';
        text_puts(&a.text, 1, 0, buf);
        display_frame(&a.screen);
    }
}
