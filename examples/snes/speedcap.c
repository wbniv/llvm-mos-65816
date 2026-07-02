// Speed Cap Particles — #82 of the compiler stress-test demo battery.
// 12 float-velocity particles attracted to a center, speed-clamped by fminf/fmaxf.
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar, no far pointers).
//
// Codegen corners:
//   __builtin_fmaxf(v, -MAX_V) → G_FMAXNUM → .libcallFor S32 → fmaxf (math.cc:19)
//   __builtin_fminf(v,  MAX_V) → G_FMINNUM → .libcallFor S32 → fminf (math.cc:18)
// Both are libcalls — no inline lowering for S32 fmin/fmax on 65816.
// Distinct from #26 boids (integer fixed-point, aggregate-return ABI, no floats)
// and #77 satcast (fmin/fmax as sat-cast clamp, hex kaleidoscope visual).
//
// NaN-recovery demo (visual only, not in gate CRC):
//   Every 180 frames boid #0 gets a quiet NaN injected into vx.
//   fmaxf(NaN, -MAX_V) = -MAX_V   ← NaN-quieting (IEEE 754-2008 minNum/maxNum)
//   Boid #0 flashes red for 30 frames to show recovery.
//
// Visual: 12 particles as 8×8 tile squares on a 128×128 BitmapCanvas (BG3 2bpp).
//   Color 0: background (dark blue-black)
//   Color 1: normal particle (teal)
//   Color 2: speed-capped particle (orange) — when velocity hit MAX_V this step
//   Color 3: NaN-recovered particle (red) — 30 frames after NaN injection
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/speedcap.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      6u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u

// BG3 2bpp palette.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  2,  3),    // 0: dark blue-black bg
    SNES_RGB( 4, 20, 20),    // 1: teal (normal particle)
    SNES_RGB(28, 18,  2),    // 2: orange (speed-capped)
    SNES_RGB(28,  4,  2),    // 3: red (NaN-recovered)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    // Float velocity & integer position (in canvas pixel coords, 0..127)
    int16_t      px[SC_N], py[SC_N];
    float        vx[SC_N], vy[SC_N];
    // Previous tile positions (to clear before redraw)
    int16_t      old_tx[SC_N], old_ty[SC_N];
    // Bitmask: bit i set → particle i was speed-capped this step
    uint16_t     capped;
    // NaN recovery flash counter for particle 0
    uint8_t      nan_flash;
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Fill an 8×8 tile at canvas tile (cx, cy) with solid 2bpp color.
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *tp = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    uint8_t r;
    for (r = 0u; r < 8u; r++) { tp[r * 2u] = p0; tp[r * 2u + 1u] = p1; }
    // Mark tile dirty.
    if (cv->lo > tile) cv->lo = tile;
    if (cv->hi < tile) cv->hi = tile;
}

// Inject a quiet NaN into particle 0's vx (ROM visual only, not in gate CRC).
static void inject_nan(App *a) {
    union { uint32_t u; float f; } nan_u;
    nan_u.u = 0x7FC00000u;   // IEEE 754 single-precision quiet NaN
    a->vx[0] = nan_u.f;
    a->nan_flash = 30u;
}

static void physics_step(App *a) {
    uint8_t i;
    a->capped = 0u;
    for (i = 0u; i < (uint8_t)SC_N; i++) {
        float dx = (float)((int16_t)(SC_CENTER_X - a->px[i]));
        float dy = (float)((int16_t)(SC_CENTER_Y - a->py[i]));
        float sdx = dx * SC_K;
        float sdy = dy * SC_K;
        float nvx = a->vx[i] + sdx;
        float nvy = a->vy[i] + sdy;
        // Speed governor — the codegen corners (G_FMAXNUM → fmaxf; G_FMINNUM → fminf).
        // NaN-quieting: if vx[0] was NaN, fmaxf(NaN, -MAX_V) = -MAX_V (recovered).
        a->vx[i] = __builtin_fminf(__builtin_fmaxf(nvx, -SC_MAX_V), SC_MAX_V);
        a->vy[i] = __builtin_fminf(__builtin_fmaxf(nvy, -SC_MAX_V), SC_MAX_V);
        // Detect clamping (float comparison with normal floats — safe, no NaN here now).
        if (nvx > SC_MAX_V || nvx < -SC_MAX_V || nvy > SC_MAX_V || nvy < -SC_MAX_V)
            a->capped = (uint16_t)(a->capped | (uint16_t)(1u << i));
        int16_t ivx = (int16_t)a->vx[i];
        int16_t ivy = (int16_t)a->vy[i];
        a->px[i] = (int16_t)(a->px[i] + ivx);
        a->py[i] = (int16_t)(a->py[i] + ivy);
        // Clamp to canvas bounds.
        if (a->px[i] < 0) a->px[i] = 0;
        if (a->px[i] > 127) a->px[i] = 127;
        if (a->py[i] < 0) a->py[i] = 0;
        if (a->py[i] > 127) a->py[i] = 127;
    }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='S'; buf[1]='C'; buf[2]='=';
    buf[3]=H[(corpus_result>>12)&0xFu]; buf[4]=H[(corpus_result>>8)&0xFu];
    buf[5]=H[(corpus_result>>4)&0xFu]; buf[6]=H[corpus_result&0xFu];
    buf[7]=' '; buf[8]='F'; buf[9]='=';
    buf[10]=H[(a->frame>>12)&0xFu]; buf[11]=H[(a->frame>>8)&0xFu];
    buf[12]=H[(a->frame>>4)&0xFu]; buf[13]=H[a->frame&0xFu];
    buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void redraw_particles(App *a) {
    uint8_t i;
    // Clear old tile positions.
    for (i = 0u; i < (uint8_t)SC_N; i++) {
        if (a->old_tx[i] >= 0) {
            cell_fill(&a->canvas, (uint8_t)a->old_tx[i], (uint8_t)a->old_ty[i], 0u);
        }
    }
    // Draw new tile positions.
    for (i = 0u; i < (uint8_t)SC_N; i++) {
        uint8_t tx = (uint8_t)((uint8_t)a->px[i] >> 3);
        uint8_t ty = (uint8_t)((uint8_t)a->py[i] >> 3);
        uint8_t color;
        if (i == 0u && a->nan_flash > 0u) {
            color = 3u;  // red: NaN-recovered
        } else if ((a->capped >> i) & 1u) {
            color = 2u;  // orange: speed-capped
        } else {
            color = 1u;  // teal: normal
        }
        cell_fill(&a->canvas, tx, ty, color);
        a->old_tx[i] = (int16_t)tx;
        a->old_ty[i] = (int16_t)ty;
    }
}

static void app_init(App *a) {
    uint8_t i;
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    for (i = 0u; i < (uint8_t)SC_N; i++) {
        a->px[i] = SC_INIT_PX[i];
        a->py[i] = SC_INIT_PY[i];
        a->vx[i] = 0.0f;
        a->vy[i] = 0.0f;
        a->old_tx[i] = -1;
        a->old_ty[i] = -1;
    }
    a->capped = 0u;
    a->nan_flash = 0u;
    a->frame = 0u;
    text_puts(&a->text, 0, 2, "FMINF/FMAXF SPEED CAP");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_FMINNUM", "SPEED CAP");
    corpus_result = speedcap_gate_crc();   // runs during title; expected 0xF744
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        // NaN injection every 180 frames (visual demo of NaN-quieting by fmaxf).
        if (a.frame % 180u == 90u) inject_nan(&a);
        if (a.nan_flash > 0u) a.nan_flash = (uint8_t)(a.nan_flash - 1u);
        physics_step(&a);
        redraw_particles(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
