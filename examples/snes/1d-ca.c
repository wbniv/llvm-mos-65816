// Rule 90 / Rule 110 — 1-D Cellular Automaton SNES demo (#6 of the compiler stress-test battery).
//
// 256-cell bitpacked CA scrolls down the screen one generation per frame:
//   Rule 90  — Sierpinski triangle (XOR of left+right neighbour)
//   Rule 110 — complex aperiodic pattern (Turing-complete)
// A button toggles between rules. Start resets to a single-cell seed.
//
// Display: BG3 (2bpp) — 32×32 tile ring buffer. Chr at VRAM word 0x0000 (1024 tiles × 16 B
// = 16 KB); tilemap at VRAM word 0x4000 (32×32 identity map, never changes). BG3VOFS scrolls
// the ring by one pixel per generation. DMA: 512 B per completed tile-row (every 8 gens).
//
// No far pointers → all state in bank-0 WRAM → 5-way differential bar.
// See docs/plans/2026-06-27-6-snes-rule90-110-1d-ca.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
/* This demo's BG3 chr fills VRAM words 0x0000..0x2000 (1024 2bpp tiles), so move the title's BG2
   char base clear of it before including title_layer.h (default 0x1000 would collide). */
#define TITLE_CHR_WORD 0x6000u
#include "snesgfx/title_layer.h"
#include "snesgfx/controller.h"
#include "../65816/ca1d.h"

// BG3 layout
#define CA_CHR_WORD   0x0000u   // chr base (word): tiles 0..1023 (1024 × 16 B = 16 KB)
#define CA_MAP_WORD   0x4000u   // tilemap base (word): 32×32 identity map
#define CA_TILE_ROWS     32u    // ring tile-rows (256 pixels tall)

// BG3 2bpp palette: colour 0 = background (dead cell), colour 3 = live cell.
// Rules share a palette; live-cell colour changes on toggle to signal the new rule.
#define PAL_DEAD   SNES_RGB( 0,  0,  0)   // black
#define PAL_R90    SNES_RGB( 0, 31,  0)   // bright green  (Rule 90 / Sierpinski)
#define PAL_R110   SNES_RGB(31, 18,  0)   // amber-gold    (Rule 110 / chaos)

// ---------------------------------- CaDisplay drawable ---------------------------------------
// Custom Drawable: owns BG3, the tile ring, and the BG3VOFS scroll register.

typedef struct {
    Drawable base;
    uint8_t  tile_buf[512];     // shadow for one tile-row (32 tiles × 16 B)
    uint8_t  write_tile_row;    // 0..31: ring tile-row being built
    uint8_t  write_pix_row;     // 0..7:  pixel row within that tile-row
    uint8_t  dma_tile_row;      // tile-row to DMA (valid when tile_dirty)
    uint8_t  tile_dirty;        // 1 = dma_tile_row needs upload this vblank
    uint8_t  vofs_lo;           // BG3VOFS low byte for current frame (high byte = 0)
    uint8_t  pal_dirty;         // 1 = CGRAM[3] needs update (rule changed)
    uint16_t live_colour;       // current live-cell BGR555 colour
} CaDisplay;

static void _cad_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    CaDisplay *cad = (CaDisplay *)d;
    uint16_t r, c;

    // BG3 layer registers (force-blank: write-once values set here, never changed).
    REG_BG3SC  = SNES_BGSC(CA_MAP_WORD, 0);   // 32×32 tilemap at CA_MAP_WORD
    REG_BG34NBA = 0;                            // BG3 chr at word 0x0000

    // Scroll: write twice to set both low and high bytes of the latch.
    REG_BG3HOFS = 0; REG_BG3HOFS = 0;   // horizontal scroll = 0 (never changes)
    REG_BG3VOFS = 0; REG_BG3VOFS = 0;   // vertical scroll = 0 for now (updated per frame)

    // Initial palette (force-blank: direct CGRAM write is safe).
    REG_CGADD = 0;
    REG_CGDATA = (uint8_t)PAL_DEAD; REG_CGDATA = (uint8_t)(PAL_DEAD >> 8);   // colour 0
    REG_CGDATA = (uint8_t)PAL_DEAD; REG_CGDATA = (uint8_t)(PAL_DEAD >> 8);   // colour 1
    REG_CGDATA = (uint8_t)PAL_DEAD; REG_CGDATA = (uint8_t)(PAL_DEAD >> 8);   // colour 2
    REG_CGDATA = (uint8_t)cad->live_colour;                                    // colour 3 low
    REG_CGDATA = (uint8_t)(cad->live_colour >> 8);                            // colour 3 high

    // Zero all chr tiles (1024 × 8 VRAM words = 8192 words = dead cells everywhere).
    snes_vram_addr(CA_CHR_WORD);
    for (uint16_t w = 0; w < (uint16_t)(1024u * 8u); w++) REG_VMDATA = 0;

    // Identity tilemap: entry at (col, tile_row) → chr tile# = tile_row*32 + col.
    snes_vram_addr(CA_MAP_WORD);
    for (r = 0; r < (uint16_t)CA_TILE_ROWS; r++)
        for (c = 0; c < 32u; c++)
            REG_VMDATA = (uint16_t)(r * 32u + c);

    d->tm_bits = TM_BG3;
}

static void _cad_emit(Drawable *d, UploadQueue *q) {
    CaDisplay *cad = (CaDisplay *)d;

    // Update BG3 vertical scroll. emit() runs BEFORE snes_wait_vblank (active display), so the
    // scroll latch must NOT be poked here directly — that shears the picture mid-frame. Enqueue it
    // so upq_flush() applies it in the v-blank window with the DMA. (High byte always 0: range 0..255.)
    upq_push_scroll(q, (uint16_t)(uintptr_t)&REG_BG3VOFS, (uint16_t)cad->vofs_lo);

    // Upload a completed tile-row if ready (DMA 512 B to chr VRAM).
    if (cad->tile_dirty) {
        upq_push_vram(q,
            (uint16_t)((uint16_t)cad->dma_tile_row * 0x100u),  // dest word in chr VRAM
            cad->tile_buf, 0x00u, 512u, VMAIN_INC_HIGH_1);
        cad->tile_dirty = 0;
    }

    // Update live-cell colour if rule changed.
    if (cad->pal_dirty) {
        static uint16_t pal3[1];
        pal3[0] = cad->live_colour;
        upq_push_cgram(q, 3, pal3, 0x00u, 2u);   // CGRAM entry 3 = 2 bytes
        cad->pal_dirty = 0;
    }
}

static const DrawableVT CAD_VT = { _cad_reserve, _cad_emit };

static void ca_display_init(CaDisplay *cad, uint16_t live_colour) {
    uint16_t i;
    cad->base.vt = &CAD_VT;
    cad->base.tm_bits = 0;
    for (i = 0; i < 512u; i++) cad->tile_buf[i] = 0;
    cad->write_tile_row = 0;
    cad->write_pix_row  = 0;
    cad->dma_tile_row   = 0;
    cad->tile_dirty     = 0;
    cad->vofs_lo        = 0;
    cad->pal_dirty      = 0;
    cad->live_colour    = live_colour;
}

// Push one CA row (CA_BYTES bytes) into the tile ring; triggers DMA every 8 rows.
// tile_buf layout: [col*16 + pix_row*2] = plane-0 byte, [+1] = plane-1 byte.
// For 2-color display: dead cell = 0b00 (colour 0), live cell = 0b11 (colour 3).
static void ca_display_push(CaDisplay *cad, const uint8_t *row) {
    uint8_t col;
    uint8_t pr = cad->write_pix_row;
    for (col = 0; col < 32u; col++) {
        cad->tile_buf[(uint16_t)col * 16u + (uint16_t)pr * 2u]      = row[col];
        cad->tile_buf[(uint16_t)col * 16u + (uint16_t)pr * 2u + 1u] = row[col];
    }
    if (pr == 7u) {
        cad->write_pix_row  = 0;
        cad->dma_tile_row   = cad->write_tile_row;
        cad->tile_dirty     = 1;
        cad->write_tile_row = (uint8_t)((cad->write_tile_row + 1u) & 31u);
    } else {
        cad->write_pix_row = (uint8_t)(pr + 1u);
    }
}

// ---------------------------------- App --------------------------------------------------

volatile uint16_t corpus_result;

typedef struct {
    Display    screen;
    CaDisplay  disp;
    Controller pad;
    uint8_t    row_a[CA_BYTES];    // ping-pong source/dest (avoids 32-byte copy per frame)
    uint8_t    row_b[CA_BYTES];
    uint8_t    use_a;              // 1: cur=row_a, dst=row_b; 0: cur=row_b, dst=row_a
    uint8_t    rule;
    uint16_t   gen;
} App;

static void app_reset_ca(App *a) {
    uint8_t b;
    for (b = 0; b < (uint8_t)CA_BYTES; b++) a->row_a[b] = a->row_b[b] = 0;
    a->row_a[CA_BYTES / 2u] = 1u;   // single-cell seed at center
    a->use_a = 1u;
    a->gen   = 0;
    // vofs resets too (VOFS written from gen in the main loop)
    a->disp.vofs_lo = (uint8_t)(0u - 223u);   // gen=0 → vofs=33 (fills from bottom up)
}

static void app_init(App *a) {
    a->rule = CA_RULE_90;
    ca_display_init(&a->disp, PAL_R90);
    display_init(&a->screen);
    controller_init(&a->pad);
    display_add(&a->screen, (Drawable *)&a->disp);
    app_reset_ca(a);
}

int main(void) {
    static App a;
    app_init(&a);

    // Title overlay (BG2, char base moved to 0x6000 above); held during the gate CRC, then torn
    // down before the automaton scrolls. Gate-neutral (no DMA; corpus_result is the pre-loop hash).
    static TitleLayer title;
    title_begin(&a.screen, &title, "CELL AUTOMATA", "RULE 90 / 110");

    corpus_result = ca_gate_crc();
    title_end(&a.screen, &title, 110);                            // ~2 s title (consistent on-screen time)

    for (;;) {
        uint8_t *src, *dst;

        // 1. Read pad (pressed = newly down this frame).
        controller_poll(&a.pad);
        if (controller_pressed(&a.pad) & JOY_A) {
            // Toggle rule; change live-cell colour to signal the switch.
            a.rule = (a.rule == (uint8_t)CA_RULE_90) ? (uint8_t)CA_RULE_110 : (uint8_t)CA_RULE_90;
            a.disp.live_colour = (a.rule == (uint8_t)CA_RULE_90) ? PAL_R90 : PAL_R110;
            a.disp.pal_dirty = 1;
        }
        if (controller_pressed(&a.pad) & JOY_START) {
            app_reset_ca(&a);
        }

        // 2. CA step (ping-pong: avoids 32-byte copy).
        src = a.use_a ? a.row_a : a.row_b;
        dst = a.use_a ? a.row_b : a.row_a;
        ca_step(src, dst, a.rule);

        // 3. Emit new row to tile ring.
        ca_display_push(&a.disp, dst);

        // 4. Advance counters.
        a.gen++;
        a.use_a ^= 1u;

        // 5. Scroll: keep newest row at bottom of 224-pixel visible window.
        //    vofs = (gen - 223) & 0xFF — wraps naturally as uint8_t arithmetic.
        a.disp.vofs_lo = (uint8_t)(a.gen - 223u);

        // 6. V-blank: emit scroll reg + DMA tile-row + palette; release blank on frame 1.
        display_frame(&a.screen);
    }
}
