// Montgomery Orbit — #84 of the compiler stress-test demo battery.
// Renders the multiplicative-group orbit x_i = g^i mod N as a star-polygon polyline
// on a 128x128 BG3 canvas. The modular multiplication is Montgomery REDC — modmul
// with NO division (__mulsi3 + >>16 + mask + conditional subtract, no __udivsi3).
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar, no far pointers).
//
// Distinct from #61 dhmix (64-bit modexp via __udivdi3) and #20 factorial
// (base-10000 bignum via __udivmodsi4) — this is the division-FREE modmul demo.
//
// Visual: the orbit residues map to angles on a circle; connecting consecutive
// points traces a rotating star polygon whose density reflects ord(g) mod N.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/montorbit.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define ORBIT_PTS    MO_K
#define CX           64
#define CY           64
#define RADIUS       58

// 32-entry sin LUT (quarter-symmetry), Q8 (values -256..256), index 0..31 = 0..360°.
static const int16_t sin32[32] = {
    0,   50,   98,  142,  181,  212,  237,  251,
  256,  251,  237,  212,  181,  142,   98,   50,
    0,  -50,  -98, -142, -181, -212, -237, -251,
 -256, -251, -237, -212, -181, -142,  -98,  -50,
};
static inline int16_t isin(uint8_t a) { return sin32[a & 31u]; }
static inline int16_t icos(uint8_t a) { return sin32[(a + 8u) & 31u]; }

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  4),    // 0: dark bg
    SNES_RGB( 4, 24, 26),    // 1: cyan orbit line
    SNES_RGB(26,  4, 24),    // 2: magenta vertex
    SNES_RGB(30, 30, 20),    // 3: bright current point
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     rot;      // animation rotation phase
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Map a canonical residue [0,N) to a screen point on the circle, with rotation.
static void residue_point(uint16_t canon, uint16_t rot, int16_t *px, int16_t *py) {
    // angle index 0..31 from residue: (canon * 32 / N) — use the high bits of a
    // 32-bit scaled product to avoid division (canon << 5 then >> ~ shift).
    // Approximate canon/N * 32 by (canon * 32) >> 16 * (65536/N) — but simplest:
    // angle = (canon & 31) rotated. Keeps it division-free and visually a star.
    uint8_t a = (uint8_t)(((uint8_t)canon + (uint8_t)rot) & 31u);
    *px = (int16_t)(CX + (int16_t)(((int32_t)icos(a) * RADIUS) >> 8));
    *py = (int16_t)(CY + (int16_t)(((int32_t)isin(a) * RADIUS) >> 8));
}

static void draw_orbit(App *a) {
    canvas_clear(&a->canvas);
    uint16_t g_mont = mo_to_mont(MO_G);
    uint16_t x_mont = mo_to_mont((uint16_t)1u);
    int16_t x0 = 0, y0 = 0, xf = 0, yf = 0;
    uint16_t i;
    for (i = 0u; i < (uint16_t)ORBIT_PTS; i++) {
        uint16_t canon = mo_orbit_point(g_mont, &x_mont);
        int16_t px, py;
        residue_point(canon, a->rot, &px, &py);
        if (i == 0u) { x0 = px; y0 = py; xf = px; yf = py; }
        else         { canvas_line(&a->canvas, x0, y0, px, py, 1u); x0 = px; y0 = py; }
        // vertex dot
        canvas_plot(&a->canvas, px, py, 2u);
    }
    // close the polygon
    canvas_line(&a->canvas, x0, y0, xf, yf, 1u);
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='N'; buf[10]='=';
    buf[11]=H[(MO_N>>12)&0xFu]; buf[12]=H[(MO_N>>8)&0xFu];
    buf[13]=H[(MO_N>>4)&0xFu]; buf[14]=H[MO_N&0xFu];
    buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->rot = 0u;
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "MONTGOMERY REDC NODIV");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "MONT REDC", "MODMUL NO DIV");
    corpus_result = montorbit_gate_crc();   // expected 0xBA9B
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        if ((a.frame & 7u) == 0u) a.rot = (uint16_t)(a.rot + 1u);
        draw_orbit(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
