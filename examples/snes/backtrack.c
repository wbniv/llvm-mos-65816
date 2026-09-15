// Backtracking Solver — #116 of the compiler stress-test battery.
// Round 6 (harden-the-fixes), Cluster G, the FLAGSHIP guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35). Builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar); the headless 5-way gate is corpus/backtrack_sim.c.
//
// Codegen corner: a longjmp on the 65816 in native mode must reconstruct the page-1 16-bit
// hardware S (the common 6502-only setjmp.S drops it into page 0), restore the soft stack
// pointer, and restore the __rc18..__rc31 callee-saved block — all at once, from a frame depth
// the jumping code never knew. corpus/setjmp_sim.c covers the minimum: one frame, one jump, no
// live callee-saved registers. This escalates to the real corner — an 8-queens search where
// every recursion level owns a setjmp choice point and every dead end longjmps straight to the
// deepest still-viable ancestor, so a single jump discards anywhere from 1 to BT_N+1 jsr frames.
//
// Visual: the recorded event trace replays on an 8x8 board. Queens drop in row by row as the
// search descends; on a backjump the abandoned rows flash red and SNAP BACK off the board, and
// the search resumes from the ancestor it jumped to.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/backtrack.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define EV_FRAMES    6u    /* v-blanks per replayed trace event */
#define FLASH_FRAMES 3u    /* how many event steps an abandoned row stays lit */

// BG3 2bpp palette: the board's two square shades, the queen, the abandoned-row flash.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(1, 1, 4),            // 0: dark square
    SNES_RGB(6, 6, 12),           // 1: light square
    SNES_RGB(28, 26, 6),          // 2: queen (gold)
    SNES_RGB(31, 6, 4),           // 3: abandoned row (red flash)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

// Replay state: which rows currently hold a queen, and which are flashing out.
static uint8_t  rp_col[BT_N];
static uint8_t  rp_on[BT_N];
static uint8_t  rp_flash[BT_N];
static uint16_t rp_i;         /* next trace index                  */
static uint16_t rp_places;    /* queens dropped so far in the replay */
static uint16_t rp_backs;     /* backjumps replayed so far           */

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 2, "BACKTRACK  SETJMP UNWIND");
}

// Paint the whole 8x8 board: 2x2 tiles per cell over the full 16x16-tile canvas.
__attribute__((noinline))
static void draw_board(BitmapCanvas *cv) {
    for (uint8_t r = 0u; r < (uint8_t)BT_N; r++) {
        for (uint8_t c = 0u; c < (uint8_t)BT_N; c++) {
            uint8_t color;
            if (rp_on[r] && rp_col[r] == c)      color = 2u;
            else if (rp_flash[r])                color = 3u;
            else                                 color = (uint8_t)(((r ^ c) & 1u) ? 1u : 0u);
            uint8_t tx = (uint8_t)(c * 2u), ty = (uint8_t)(r * 2u);
            canvas_fill_solid_tile(cv, tx,             ty,             color);
            canvas_fill_solid_tile(cv, (uint8_t)(tx+1u), ty,             color);
            canvas_fill_solid_tile(cv, tx,             (uint8_t)(ty+1u), color);
            canvas_fill_solid_tile(cv, (uint8_t)(tx+1u), (uint8_t)(ty+1u), color);
        }
    }
    cv->lo = (uint16_t)0u;
    cv->hi = (uint16_t)(CANVAS_NTILES - 1u);
}

// Advance the replay by one recorded event. PLACE drops a queen and clears the rows below it;
// BACKJUMP flashes every row from the jump target down and sweeps them off the board.
__attribute__((noinline))
static void replay_step(void) {
    for (uint8_t r = 0u; r < (uint8_t)BT_N; r++)
        if (rp_flash[r]) rp_flash[r]--;

    if (rp_i >= bt_tn) {   /* trace exhausted: start the replay over */
        rp_i = (uint16_t)0u;
        rp_places = (uint16_t)0u;
        rp_backs = (uint16_t)0u;
        for (uint8_t r = 0u; r < (uint8_t)BT_N; r++) { rp_on[r] = 0u; rp_flash[r] = 0u; }
        return;
    }

    uint8_t ev = bt_trace[rp_i++];
    if (BT_EV_IS_BACK(ev)) {
        uint8_t to = BT_EV_LO(ev);
        for (uint8_t r = to; r < (uint8_t)BT_N; r++) {
            if (rp_on[r]) rp_flash[r] = (uint8_t)FLASH_FRAMES;
            rp_on[r] = 0u;
        }
        rp_backs++;
    } else {
        uint8_t r = BT_EV_HI(ev);
        rp_col[r] = BT_EV_LO(ev);
        rp_on[r] = 1u;
        for (uint8_t k = (uint8_t)(r + 1u); k < (uint8_t)BT_N; k++) rp_on[k] = 0u;
        rp_places++;
    }
}

static void put_u16(char *dst, uint16_t v) {
    dst[0] = (char)('0' + (char)((v / (uint16_t)1000u) % (uint16_t)10u));
    dst[1] = (char)('0' + (char)((v / (uint16_t)100u) % (uint16_t)10u));
    dst[2] = (char)('0' + (char)((v / (uint16_t)10u) % (uint16_t)10u));
    dst[3] = (char)('0' + (char)(v % (uint16_t)10u));
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "8-QUEENS BACKJUMP", "BACKTRACK");
    corpus_result = backtrack_gate_crc();   // expected 0x7336
    title_end(&a.screen, &title, 90);

    rp_i = (uint16_t)0u;
    rp_places = (uint16_t)0u;
    rp_backs = (uint16_t)0u;
    for (uint8_t r = 0u; r < (uint8_t)BT_N; r++) { rp_on[r] = 0u; rp_flash[r] = 0u; rp_col[r] = 0u; }

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)EV_FRAMES) == (uint16_t)0u) {
            replay_step();
            draw_board(&a.canvas);
            char buf[21];
            buf[0]='P'; buf[1]='U'; buf[2]='T'; buf[3]=':'; buf[4]=' ';
            put_u16(&buf[5], rp_places);
            buf[9]=' '; buf[10]='B'; buf[11]='A'; buf[12]='C'; buf[13]='K'; buf[14]=':'; buf[15]=' ';
            put_u16(&buf[16], rp_backs);
            buf[20]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
