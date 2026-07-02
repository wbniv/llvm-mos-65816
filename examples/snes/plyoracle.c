// PlyOracle — #92 of the compiler stress-test demo battery (final pick).
// An animated 3x3 AI self-play tic-tac-toe on a 128x128 BG3 canvas, both sides driven by
// negamax + alpha-beta. The compiler stress is the negate-on-return recursion (G_SUB 0,x)
// + G_SMAX + alpha-beta cutoff CFG. Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way).
//
// Distinct from #17/#18: alternating-sign minimax recursion, not plain/log-depth recursion.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/plyoracle.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  3,  6),    // 0: bg
    SNES_RGB(14, 16, 20),    // 1: grid lines
    SNES_RGB(28, 10, 10),    // 2: X (red)
    SNES_RGB(10, 20, 30),    // 3: O (blue)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     x, o;     // bitboards
    uint8_t      turn;     // 0=X, 1=O
    uint8_t      opening;  // which opening (cycles)
    uint16_t     frame;
    uint16_t     wins_x, wins_o, draws;
} App;

volatile uint16_t corpus_result;

// draw an X mark in cell c (0..8): two diagonals
static void draw_X(BitmapCanvas *cv, uint8_t c) {
    uint8_t cx = (uint8_t)((c % 3u) * 40u + 8u), cy = (uint8_t)((c / 3u) * 40u + 8u);
    canvas_line(cv, (int16_t)cx, (int16_t)cy, (int16_t)(cx+24), (int16_t)(cy+24), 2u);
    canvas_line(cv, (int16_t)(cx+24), (int16_t)cy, (int16_t)cx, (int16_t)(cy+24), 2u);
}
// draw an O mark (box outline) in cell c
static void draw_O(BitmapCanvas *cv, uint8_t c) {
    uint8_t cx = (uint8_t)((c % 3u) * 40u + 8u), cy = (uint8_t)((c / 3u) * 40u + 8u);
    canvas_line(cv, (int16_t)cx, (int16_t)cy, (int16_t)(cx+24), (int16_t)cy, 3u);
    canvas_line(cv, (int16_t)(cx+24), (int16_t)cy, (int16_t)(cx+24), (int16_t)(cy+24), 3u);
    canvas_line(cv, (int16_t)(cx+24), (int16_t)(cy+24), (int16_t)cx, (int16_t)(cy+24), 3u);
    canvas_line(cv, (int16_t)cx, (int16_t)(cy+24), (int16_t)cx, (int16_t)cy, 3u);
}

static void draw_board(App *a) {
    canvas_clear(&a->canvas);
    // grid lines at 40,80
    uint8_t i;
    for (i = 0u; i < (uint8_t)CANVAS_W; i++) {
        canvas_plot(&a->canvas, (int16_t)i, 40, 1u); canvas_plot(&a->canvas, (int16_t)i, 80, 1u);
        canvas_plot(&a->canvas, 40, (int16_t)i, 1u); canvas_plot(&a->canvas, 80, (int16_t)i, 1u);
    }
    uint8_t c;
    for (c = 0u; c < 9u; c++) {
        if (a->x & (uint16_t)(1u << c)) draw_X(&a->canvas, c);
        else if (a->o & (uint16_t)(1u << c)) draw_O(&a->canvas, c);
    }
}

static void new_game(App *a) {
    a->opening = (uint8_t)((a->opening + 1u) % 9u);
    a->x = (uint16_t)(1u << a->opening);   // X's forced first move
    a->o = 0u;
    a->turn = 1u;                          // O to move
}

// Advance one ply (negamax move). Returns 1 if the game ended.
static uint8_t step_game(App *a) {
    if (po_wins(a->x)) { a->wins_x++; return 1u; }
    if (po_wins(a->o)) { a->wins_o++; return 1u; }
    if ((uint16_t)(a->x | a->o) == 0x1FFu) { a->draws++; return 1u; }
    uint8_t mv;
    if (a->turn == 0u) { mv = po_best_move(a->x, a->o); if (mv < 9u) a->x = (uint16_t)(a->x | (1u << mv)); }
    else               { mv = po_best_move(a->o, a->x); if (mv < 9u) a->o = (uint16_t)(a->o | (1u << mv)); }
    a->turn = (uint8_t)(a->turn ^ 1u);
    return 0u;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='X'; buf[10]=H[a->wins_x&0xFu]; buf[11]='O'; buf[12]=H[a->wins_o&0xFu];
    buf[13]='D'; buf[14]=H[a->draws&0xFu];
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
    a->opening = 8u;  // so first new_game() → 0
    a->wins_x = 0u; a->wins_o = 0u; a->draws = 0u;
    a->frame = 0u;
    new_game(a);
    text_puts(&a->text, 0, 3, "PLYORACLE NEGAMAX");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "PLYORACLE", "NEGAMAX A-B");
    corpus_result = plyoracle_gate_crc();   // expected 0x1DB6
    title_end(&a.screen, &title, 90);
    uint8_t hold = 0u;
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        // one ply every ~20 frames; brief hold on game end then reset
        if ((a.frame % 20u) == 0u) {
            if (hold > 0u) { hold--; if (hold == 0u) new_game(&a); }
            else if (step_game(&a)) hold = 3u;
        }
        draw_board(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
