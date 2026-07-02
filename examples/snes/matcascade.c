// Matrix Cascade — #91 of the compiler stress-test demo battery.
// A spinning wireframe lattice on a 128x128 BG3 canvas: a grid of points is transformed by
// an animated Q8 mat2 built from chained by-value matrix multiplies (the sret hidden-pointer
// struct-return ABI). Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Distinct from #26 boids (vec2 32-bit register-pair return): mat2 is 8 bytes → sret.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/matcascade.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define GRID         5           // 5x5 lattice of points
#define CX           64
#define CY           64

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  5),    // 0: bg
    SNES_RGB( 8, 18, 28),    // 1: lattice edges (cyan)
    SNES_RGB(28, 12, 28),    // 2: nodes (magenta)
    SNES_RGB(30, 30, 20),    // 3: axis
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      phase;
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Build the animated transform by cascading a few rotation matrices (exercises sret each frame).
static mat2 build_xform(int16_t phase) {
    mat2 m; m.a = 256; m.b = 0; m.c = 0; m.d = 256;   // identity
    uint8_t i;
    for (i = 0u; i < 3u; i++)
        m = mat_mul(m, mc_rot((int16_t)(phase + (int16_t)i)));   // chained by-value → sret
    // light scale so it stays on-canvas
    m.a >>= 1; m.b >>= 1; m.c >>= 1; m.d >>= 1;
    return m;
}

static void draw_lattice(App *a) {
    canvas_clear(&a->canvas);
    mat2 m = build_xform(a->phase);
    int16_t px[GRID][GRID], py[GRID][GRID];
    int8_t gx, gy;
    for (gy = 0; gy < GRID; gy++) {
        for (gx = 0; gx < GRID; gx++) {
            int16_t lx = (int16_t)((gx - 2) * 20);   // lattice coords -40..40
            int16_t ly = (int16_t)((gy - 2) * 20);
            int16_t ox, oy;
            mc_xform(m, lx, ly, &ox, &oy);
            int16_t sx = (int16_t)(CX + ox), sy = (int16_t)(CY + oy);
            if (sx < 0) sx = 0; if (sx > 127) sx = 127;
            if (sy < 0) sy = 0; if (sy > 127) sy = 127;
            px[gy][gx] = sx; py[gy][gx] = sy;
        }
    }
    // edges: horizontal + vertical lattice lines
    for (gy = 0; gy < GRID; gy++)
        for (gx = 0; gx < GRID; gx++) {
            if (gx + 1 < GRID) canvas_line(&a->canvas, px[gy][gx], py[gy][gx], px[gy][gx+1], py[gy][gx+1], 1u);
            if (gy + 1 < GRID) canvas_line(&a->canvas, px[gy][gx], py[gy][gx], px[gy+1][gx], py[gy+1][gx], 1u);
            canvas_plot(&a->canvas, px[gy][gx], py[gy][gx], 2u);
        }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='S'; buf[10]='R'; buf[11]='E'; buf[12]='T';
    buf[13]=' '; buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->phase = 0;
    a->frame = 0u;
    text_puts(&a->text, 0, 2, "MATRIX CASCADE SRET");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "MAT CASCADE", "SRET STRUCT RET");
    corpus_result = matcascade_gate_crc();   // expected 0x8064
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        if ((a.frame & 3u) == 0u) a.phase = (int16_t)(a.phase + 1);
        draw_lattice(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
