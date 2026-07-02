/* snesgfx/m7title.h — Mode 7 zoom-in + 360° spin-out title splash.
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
#include "../font16.h"   /* real 16×16 Waldo font (face + SE drop-shadow) rendered as Mode-7 tiles */
#include "../sincos.h"
#include "../mode7.h"

/* Both lines use the real 16×16 Waldo font (2×2 Mode-7 8×8 tiles per glyph). Mode 7 has exactly 256
 * tiles = FONT16_N(64) glyphs × 4 tiles — a perfect fit; glyph g → tiles 4g..4g+3 (TL,TR,BL,BR).
 * Tilemap rows are the TOP row of each 2-row line (pixel_y = row * 8):
 *   line1 (title)    top row 13 → screen_y 104..119, centred on the zoom centre (128,112).
 *   line0 (subtitle) top row 10 → screen_y  80.. 95. */
#define M7T_ROW0   10u   /* subtitle (line0) top row */
#define M7T_ROW1   13u   /* title    (line1) top row → zoom centre */

/* Visible tile columns at 1:1 scale (256 px / 8 px/tile). */
#define M7T_VCOLS  32u
#define M7T_MAXCH  16u   /* max chars/line (2 tile-cols each → ≤ 32 cols) */

/* Mode-7 8bpp palette indices for the Waldo glyph pixels. */
#define M7T_FACE    0x01u  /* face  → CGRAM 1 (white, shimmer) */
#define M7T_SHADOW  0x02u  /* shadow→ CGRAM 2 (fixed dark)     */

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

/* Glyph index for an ASCII char (space / out-of-set → 0). */
static inline uint8_t _m7t_glyph(uint8_t ch) {
    return (ch >= FONT16_FIRST && ch < (uint8_t)(FONT16_FIRST + FONT16_N))
             ? (uint8_t)(ch - FONT16_FIRST) : 0u;
}

/* Write all 64 Waldo glyphs (× 4 tiles = 256 tiles) as Mode 7 8bpp character data (HIGH bytes),
 * sequentially from tile 0. FONT16 word = face_byte | shadow_byte<<8 → pixel = FACE / SHADOW / 0.
 * Tile 4g+q holds glyph g's quadrant q (0=TL,1=TR,2=BL,3=BR). */
static void _m7t_write_all_glyphs(void) {
    REG_VMAIN = VMAIN_INC_HIGH_1;
    REG_VMADD = 0u;   /* sequential: VMADD auto-advances after each HIGH write */
    for (uint16_t g = 0u; g < FONT16_N; g++) {
        for (uint8_t q = 0u; q < 4u; q++) {
            for (uint8_t r = 0u; r < 8u; r++) {
                uint16_t w = FONT16[(uint16_t)(g * 32u) + (uint16_t)(q * 8u) + r];
                uint8_t fb = (uint8_t)w, sb = (uint8_t)(w >> 8u);
                for (uint8_t p = 0u; p < 8u; p++) {
                    uint8_t bit = (uint8_t)(0x80u >> p);
                    REG_VMDATAH = (uint8_t)((fb & bit) ? M7T_FACE : ((sb & bit) ? M7T_SHADOW : 0u));
                }
            }
        }
    }
}

/* Write one centred 16×16 line into the tilemap (LOW bytes): 2 tiles/glyph across `row` (TL,TR) and
 * `row+1` (BL,BR). Glyph g → tiles 4g+0..3. */
static void _m7t_write_line(const char *s, uint8_t row) {
    if (!s) return;
    uint8_t n  = _m7t_len(s, M7T_MAXCH);
    uint8_t sc = (uint8_t)((M7T_VCOLS - (uint8_t)(2u * n)) / 2u);   /* left tile-col */
    REG_VMAIN = VMAIN_INC_LOW_1;
    /* top row: TL,TR */
    REG_VMADD = (uint16_t)((uint16_t)row * 128u + sc);
    for (uint8_t i = 0u; i < n; i++) {
        uint8_t g = _m7t_glyph((uint8_t)s[i]);
        REG_VMDATAL = (uint8_t)(4u * g + 0u);
        REG_VMDATAL = (uint8_t)(4u * g + 1u);
    }
    /* bottom row: BL,BR */
    REG_VMADD = (uint16_t)((uint16_t)(row + 1u) * 128u + sc);
    for (uint8_t i = 0u; i < n; i++) {
        uint8_t g = _m7t_glyph((uint8_t)s[i]);
        REG_VMDATAL = (uint8_t)(4u * g + 2u);
        REG_VMDATAL = (uint8_t)(4u * g + 3u);
    }
}

/* Advance the shimmer phase and COMPUTE the ink colour (no PPU write — call outside vblank). */
static uint16_t _m7t_shimmer_color(void) {
    _m7t_phase = (uint8_t)(_m7t_phase + 2u);
    uint8_t lvl = (uint8_t)(22u + (_m7t_tri(_m7t_phase) >> 4u));  /* 22..29, within 0..31 */
    return (uint16_t)SNES_RGB(lvl, lvl, lvl);
}

/* Write CGRAM entry 1 (title ink). MUST be called inside v-blank (or force-blank). */
static inline void _m7t_put_ink(uint16_t ink) {
    REG_CGADD = 1u; REG_CGDATA = (uint8_t)ink; REG_CGDATA = (uint8_t)(ink >> 8u);
}

/* ── public API ───────────────────────────────────────────────────────────────────────────────── */

/* Zoom-in (no rotation). Returns when text is at rest and screen is fully bright. */
static inline void m7splash_begin(const char *line0, const char *line1) {
    REG_NMITIMEN = 0u;             /* NMI OFF during the bulk VRAM/CGRAM upload: the char-data write is a
                                      long non-atomic loop, and an NMI mid-transfer can disturb VMADD/the
                                      sequence and leave corrupt tiles → intermittent title bands. */
    REG_INIDISP  = 0x80u;          /* force-blank while we write VRAM / CGRAM */

    /* Tilemap: clear all LOW bytes to tile 0 (space = transparent/black). */
    m7_tilemap_clear(0u, (uint16_t)(uintptr_t)&_m7t_zero, M7_TILEMAP_WORDS);

    /* Character data: write 128 glyph tiles (HIGH bytes). */
    _m7t_write_all_glyphs();

    /* Tilemap: write both 16×16 lines. line1 (title, arg2) at the zoom centre; line0 (subtitle) above. */
    _m7t_write_line(line1, M7T_ROW1);
    _m7t_write_line(line0, M7T_ROW0);

    /* CGRAM: 0=black backdrop, 1=white face (shimmer overrides each frame), 2=dark drop-shadow. */
    {
        REG_CGADD = 0u;
        REG_CGDATA = 0x00u; REG_CGDATA = 0x00u;   /* 0 = black                */
        REG_CGDATA = 0xFFu; REG_CGDATA = 0x7Fu;   /* 1 = white face (shimmer) */
        REG_CGDATA = 0x84u; REG_CGDATA = 0x10u;   /* 2 = dark shadow (0x1084) */
    }

    /* VRAM/CGRAM are set up under force-blank; enable NMI now so snes_wait_vblank() actually blocks
       (it needs the NMI to pace frames on this setup — without it the whole animation runs instantly). */
    REG_NMITIMEN = NMITIMEN_NMI;

    /* Mode 7: BG1 only, centre=(128,112), scroll=(0,0). */
    m7_begin();
    /* m7_begin() leaves M7SEL=0 (WRAP): when the plane scales below 1:1 (zoom-in/out) the 128×128 map
       repeats and tiles the title across the whole screen → bands. Force no-wrap: outside the map =
       character 0 (our blank/black tile), so a shrunk plane sits on a clean black field. */
    REG_M7SEL = 0x80u;
    m7_set_center(128u, 112u);
    m7_set_scroll(0u, 0u);

    /* Zoom-in loop: scale 0x010 → 0x100, no rotation, brightness 0 → INIDISP_ON.
       COMPUTE the frame's values BEFORE wait_vblank, then write matrix/CGRAM/INIDISP FIRST inside
       vblank — a mid-frame m7_set_matrix would shift the Mode-7 transform partway down = bands. */
    int16_t scale = (int16_t)0x010;
    uint8_t bright = 0u;
    _m7t_phase = 0u;
    for (;;) {
        int16_t step = (int16_t)((int16_t)((int16_t)0x100 - scale) >> 3);
        if (step < 1) step = 1;
        scale = (int16_t)(scale + step);
        if (scale >= (int16_t)0x0FE) scale = (int16_t)0x100;
        if (bright < (uint8_t)INIDISP_ON) bright++;
        uint16_t ink = _m7t_shimmer_color();
        (void)REG_RDNMI;      /* clear stale v-blank flag → block until a FRESH v-blank (display.h pattern) */
        snes_wait_vblank();
        m7_set_matrix(scale, 0, 0, scale);
        _m7t_put_ink(ink);
        REG_INIDISP = bright;
        if (scale == (int16_t)0x100 && bright == (uint8_t)INIDISP_ON) break;
    }
}

/* Hold for `hold_frames` v-blanks, then full-360° spin + zoom-out + fade to black.
 * Returns with force-blank active (REG_INIDISP = 0x80). */
static inline void m7splash_end(uint16_t hold_frames) {
    /* Hold: shimmer ink, static matrix. Compute ink, then write inside vblank. */
    for (uint16_t f = 0u; f < hold_frames; f++) {
        uint16_t ink = _m7t_shimmer_color();
        (void)REG_RDNMI;      /* clear stale v-blank flag → block until a FRESH v-blank (display.h pattern) */
        snes_wait_vblank();
        m7_set_matrix((int16_t)0x100, 0, 0, (int16_t)0x100);
        _m7t_put_ink(ink);
        REG_INIDISP = (uint8_t)INIDISP_ON;
    }

    /* Spin-out + zoom-out + fade: 64 frames, full 360° spin, scale 0x100 → 0, brightness → 0.
       The 4 matrix terms (int32 multiplies) are COMPUTED BEFORE wait_vblank so m7_set_matrix's writes
       are the first thing done inside vblank, not mid-frame. */
    int16_t scale = (int16_t)0x100;
    uint8_t angle = 0u, bright = (uint8_t)INIDISP_ON;
    for (uint8_t g = 0u; g < M7T_SPIN_FRAMES; g++) {
        angle = (uint8_t)(angle + M7T_SPIN_STEP);   /* 4/frame × 64 = 256 = full turn */
        scale = (int16_t)(scale - M7T_SCALE_STEP);   /* 4/frame × 64 = 256 → reaches 0 */
        if (scale < 0) scale = 0;
        if ((g & 3u) == 0u && bright > 0u) bright--;/* fade every 4 frames; 15 steps → 0 */
        int16_t cs = SINCOS[(uint8_t)(angle + 64u)];
        int16_t sn = SINCOS[angle];
        int16_t ma = (int16_t)(((int32_t)cs * scale) >> 8);
        int16_t mb = (int16_t)(-((int32_t)sn * scale) >> 8);
        int16_t mc = (int16_t)(((int32_t)sn * scale) >> 8);
        int16_t md = (int16_t)(((int32_t)cs * scale) >> 8);
        (void)REG_RDNMI;      /* clear stale v-blank flag → block until a FRESH v-blank (display.h pattern) */
        snes_wait_vblank();
        m7_set_matrix(ma, mb, mc, md);
        REG_INIDISP = bright;
    }
    REG_INIDISP = 0x80u;  /* force-blank — caller can now call display_init(). No VRAM wipe here: the
                             demo's own _canvas_reserve() zeroes this region under force-blank at setup. */
}

/* Convenience wrapper for demos with no compute between begin and end. */
static inline void m7splash(const char *line0, const char *line1, uint16_t hold_frames) {
    m7splash_begin(line0, line1);
    m7splash_end(hold_frames);
}

#endif /* SNESGFX_M7TITLE_H */
