/* snesgfx/m7title.h — Mode 7 zoom-in (no spin) + full-360° spin-out title splash.
 *
 * Standalone: call BEFORE display_init(). Switches to Mode 7 for the animation, then
 * returns with force-blank active. A subsequent display_init() wipes all Mode 7 state and
 * the BGMODE_1 drawables re-upload their content normally.
 *
 * VRAM layout (Mode 7 shares tilemap LOW bytes and char-data HIGH bytes in the same words):
 *   Tiles 0..63   — FONT8 glyphs 0..63, 8bpp, ink palette index 1 (bright title).
 *   Tiles 64..127 — same glyphs, ink palette index 2 (dim subtitle).
 *   Tilemap LOW bytes: all tile 0 (space/black), except text rows.
 *     line0 (subtitle) at tile row 12 → screen_y 96  — uses tiles 64..127 (ink=2)
 *     line1 (title)    at tile row 14 → screen_y 112 — uses tiles  0..63  (ink=1)
 *   Text centred in the 32-tile (256 px) visible window.
 *
 * CGRAM: 0=black, 1=white (shimmer), 2=dim (subtitle).
 *
 * Animation:
 *   Zoom-in  (~40 frames, exp decay): scale 0x010→0x100, no rotation, fade in.
 *   Hold     (caller-controlled):     shimmer on ink colour, static matrix.
 *   Spin-out (64 frames, linear):     full 360° spin + scale 0x100→0 + fade to black.
 *
 * API:
 *   m7splash_begin(line0, line1)  — zoom-in; returns at rest with screen visible.
 *   m7splash_end(hold_frames)     — hold + spin-out; returns with force-blank active.
 *   m7splash(line0, line1, hold)  — convenience: begin + end with no code between.
 *
 * Header-only (static inline). Needs <snes.h>, ../font8.h, ../sincos.h, mode7.h. */
#ifndef SNESGFX_M7TITLE_H
#define SNESGFX_M7TITLE_H

#include <snes.h>
#include "../font8.h"
#include "../sincos.h"
#include "../mode7.h"

/* Tilemap rows (tile units; pixel_y = row * 8). Matches title_layer.h convention:
 *   ROW0 = upper (subtitle, line0, dim)    → screen_y 96
 *   ROW1 = lower (title,    line1, bright) → screen_y 112  ← zoom centre (128,112) */
#define M7T_ROW0   12u   /* subtitle (line0, dim   ink=2) → screen_y 96  */
#define M7T_ROW1   14u   /* title    (line1, bright ink=1) → screen_y 112 */

/* Visible tile columns at 1:1 scale (256 px / 8 px/tile). */
#define M7T_VCOLS  32u

/* Palette index for set pixels of each line. */
#define M7T_INK1   0x01u  /* title    (bright white) */
#define M7T_INK2   0x02u  /* subtitle (dimmer)       */

/* Spin-out: 64 frames × 4 angle-units/frame = 256 = one full rotation. */
#define M7T_SPIN_FRAMES  64u
#define M7T_SPIN_STEP    4u
#define M7T_SCALE_STEP   4

/* State shared between begin() and end(). */
static uint8_t _m7t_phase = 0u;
static uint8_t _m7t_zero  = 0u;  /* fixed-source DMA zero byte (low WRAM bank 0) */

/* Triangle wave 0..127..0. */
static inline uint8_t _m7t_tri(uint8_t x) {
    return (uint8_t)((x & 0x80u) ? (uint8_t)(255u - x) : x);
}

/* Bounded strlen. */
static inline uint8_t _m7t_len(const char *s, uint8_t max) {
    uint8_t n = 0u;
    if (s) while (n < max && s[n]) n++;
    return n;
}

/* Write FONT8 glyph g as 8bpp Mode 7 tile at tile index `tile_idx`.
 * Pixels with the source bit set get palette value `ink`; clear bits get 0.
 * Caller must have set VMAIN = VMAIN_INC_HIGH_1 and REG_VMADD = tile_idx * 64. */
static void _m7t_write_glyph_raw(uint8_t g, uint8_t ink) {
    for (uint8_t r = 0u; r < 8u; r++) {
        uint8_t bits = (uint8_t)FONT8[(uint16_t)g * 8u + r]; /* plane 0: bit7=left */
        for (uint8_t p = 0u; p < 8u; p++)
            REG_VMDATAH = (uint8_t)(((bits >> (7u - p)) & 1u) ? ink : 0u);
    }
}

/* Write all 64 FONT8 glyphs as Mode 7 8bpp character data (HIGH bytes).
 * Tile 0..63 = glyphs with ink=M7T_INK1 (title).
 * Tile 64..127 = same glyphs with ink=M7T_INK2 (subtitle). */
static void _m7t_write_all_glyphs(void) {
    REG_VMAIN = VMAIN_INC_HIGH_1;
    /* Tiles 0..63 — ink=M7T_INK1. Sequential: VMADD auto-advances after each HIGH write. */
    REG_VMADD = 0u;
    for (uint8_t g = 0u; g < FONT8_N; g++)
        _m7t_write_glyph_raw(g, M7T_INK1);
    /* Tiles 64..127 — ink=M7T_INK2. */
    REG_VMADD = (uint16_t)(FONT8_N * 64u);
    for (uint8_t g = 0u; g < FONT8_N; g++)
        _m7t_write_glyph_raw(g, M7T_INK2);
}

/* Write centred glyph indices into tilemap (LOW bytes) at tile row `row`.
 * `tile_base` is added to the glyph index (0 for ink1 tiles, FONT8_N for ink2 tiles). */
static void _m7t_write_row(const char *s, uint8_t row, uint8_t tile_base) {
    if (!s) return;
    uint8_t n  = _m7t_len(s, M7T_VCOLS);
    uint8_t sc = (uint8_t)((M7T_VCOLS - n) / 2u);
    REG_VMAIN = VMAIN_INC_LOW_1;
    REG_VMADD = (uint16_t)((uint16_t)row * 128u + sc);
    for (uint8_t i = 0u; i < n; i++)
        REG_VMDATAL = (uint8_t)(tile_base + (uint8_t)s[i] - (uint8_t)FONT8_FIRST);
}

/* Update shimmer: drive CGRAM entry 1 with a triangle-wave luminance. */
static void _m7t_shimmer(void) {
    _m7t_phase = (uint8_t)(_m7t_phase + 2u);
    uint8_t lvl = (uint8_t)(22u + (_m7t_tri(_m7t_phase) >> 4u));  /* 22..29, within 0..31 */
    uint16_t ink = (uint16_t)SNES_RGB(lvl, lvl, lvl);
    REG_CGADD = 1u; REG_CGDATA = (uint8_t)ink; REG_CGDATA = (uint8_t)(ink >> 8u);
}

/* ── public API ───────────────────────────────────────────────────────────────────────────────── */

/* Zoom-in (no rotation). Returns when text is at rest and screen is fully bright. */
static inline void m7splash_begin(const char *line0, const char *line1) {
    REG_NMITIMEN = NMITIMEN_NMI;   /* ensure snes_wait_vblank() works before display_init */
    REG_INIDISP  = 0x80u;          /* force-blank while we write VRAM / CGRAM */

    /* Tilemap: clear all LOW bytes to tile 0 (space = transparent/black). */
    m7_tilemap_clear(0u, (uint16_t)(uintptr_t)&_m7t_zero, M7_TILEMAP_WORDS);

    /* Character data: write 128 glyph tiles (HIGH bytes). */
    _m7t_write_all_glyphs();

    /* Tilemap: write text rows.
     * line1 (title, arg2)    → tiles  0..63  (ink=1, bright) at M7T_ROW1=14 (zoom centre).
     * line0 (subtitle, arg1) → tiles 64..127 (ink=2, dim)   at M7T_ROW0=12 (above centre). */
    _m7t_write_row(line1, M7T_ROW1, 0u);
    _m7t_write_row(line0, M7T_ROW0, FONT8_N);

    /* CGRAM: 0=black backdrop, 1=white (shimmer overrides each frame), 2=dim subtitle. */
    {
        uint16_t dim = (uint16_t)SNES_RGB(16u, 16u, 14u);
        REG_CGADD = 0u;
        REG_CGDATA = 0x00u; REG_CGDATA = 0x00u;               /* 0 = black           */
        REG_CGDATA = 0xFFu; REG_CGDATA = 0x7Fu;               /* 1 = white (shimmer) */
        REG_CGDATA = (uint8_t)dim; REG_CGDATA = (uint8_t)(dim >> 8u); /* 2 = dim grey */
    }

    /* Mode 7: BG1 only, no wrap, centre=(128,112), scroll=(0,0). */
    m7_begin();
    m7_set_center(128u, 112u);
    m7_set_scroll(0u, 0u);

    /* Zoom-in loop: scale 0x010 → 0x100, no rotation, brightness 0 → INIDISP_ON. */
    int16_t scale = (int16_t)0x010;
    uint8_t bright = 0u;
    _m7t_phase = 0u;
    for (;;) {
        snes_wait_vblank();
        /* Exponential approach to 0x100 (shift=3 ≈ 25 frames); minimum step=1 prevents stall. */
        int16_t step = (int16_t)((int16_t)((int16_t)0x100 - scale) >> 3);
        if (step < 1) step = 1;
        scale = (int16_t)(scale + step);
        if (scale >= (int16_t)0x0FE) scale = (int16_t)0x100;
        if (bright < (uint8_t)INIDISP_ON) bright++;
        _m7t_shimmer();
        m7_set_matrix(scale, 0, 0, scale);
        REG_INIDISP = bright;
        if (scale == (int16_t)0x100 && bright == (uint8_t)INIDISP_ON) break;
    }
}

/* Hold for `hold_frames` v-blanks, then full-360° spin + zoom-out + fade to black.
 * Returns with force-blank active (REG_INIDISP = 0x80). */
static inline void m7splash_end(uint16_t hold_frames) {
    /* Hold: shimmer ink, static matrix. */
    for (uint16_t f = 0u; f < hold_frames; f++) {
        snes_wait_vblank();
        _m7t_shimmer();
        m7_set_matrix((int16_t)0x100, 0, 0, (int16_t)0x100);
        REG_INIDISP = (uint8_t)INIDISP_ON;
    }

    /* Spin-out + zoom-out + fade: 64 frames, full 360° spin, scale → 0, brightness → 0. */
    int16_t scale = (int16_t)0x100;
    uint8_t angle = 0u, bright = (uint8_t)INIDISP_ON;
    for (uint8_t g = 0u; g < M7T_SPIN_FRAMES; g++) {
        angle = (uint8_t)(angle + M7T_SPIN_STEP);   /* 4/frame × 64 = 256 = full turn */
        scale = (int16_t)(scale - M7T_SCALE_STEP);   /* 4/frame × 64 = 256 → reaches 0 */
        if (scale < 0) scale = 0;
        if ((g & 3u) == 0u && bright > 0u) bright--;/* fade every 4 frames; 15 steps → 0 */
        snes_wait_vblank();
        int16_t cs = SINCOS[(uint8_t)(angle + 64u)];
        int16_t sn = SINCOS[angle];
        m7_set_matrix((int16_t)(((int32_t)cs * scale) >> 8),
                      (int16_t)(-((int32_t)sn * scale) >> 8),
                      (int16_t)(((int32_t)sn * scale) >> 8),
                      (int16_t)(((int32_t)cs * scale) >> 8));
        REG_INIDISP = bright;
    }
    REG_INIDISP = 0x80u;  /* force-blank — caller can now call display_init() */
}

/* Convenience wrapper for demos with no compute between begin and end. */
static inline void m7splash(const char *line0, const char *line1, uint16_t hold_frames) {
    m7splash_begin(line0, line1);
    m7splash_end(hold_frames);
}

#endif /* SNESGFX_M7TITLE_H */
