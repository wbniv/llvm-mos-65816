// IRQ Gate — #139 of the compiler stress-test battery (Round 7, Cluster B).
//
// The first non-NMI hardware vector in this project ever to reach a C handler. crt0's weak
// `irq: rti` stub is overridden by a real __attribute__((interrupt)) handler driven by the PPU
// V-count timer, with the v-blank NMI simultaneously live. The timer is programmed to scanline
// IRQGATE_VTIME, ahead of v-blank, and the armed IRQ handler then RENDEZVOUS with the NMI —
// after its own work it spins until the NMI tally moves. Every armed IRQ is therefore preempted
// by an NMI while it is still inside its own 65816 interrupt envelope: envelope reentrancy,
// asserted rather than assumed, and structural rather than dependent on raster timing.
//
// Four things are asked at once:
//   * is the width-safe envelope emitted on the IRQ path, not just the NMI path;
//   * can a C program run CLI/SEI discipline correctly around an armed handler;
//   * does an MMIO acknowledge ($4211 TIMEUP) survive being written in C inside an ISR;
//   * is the envelope reentrant when one interrupt lands inside another.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/irqgate.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t t;
} App;

volatile uint16_t corpus_result;

// Handler-shared state. Everything an ISR touches is volatile, including the handshake flags.
static volatile uint16_t nmi_tally, irq_tally, nest_hits;
static volatile uint32_t nmi_mix, irq_mix;
static volatile uint8_t nmi_armed, irq_armed, nmi_done, irq_done, irq_depth;
static volatile uint16_t main_live16;
static volatile uint32_t main_live32;

// ---------------------------------------------------------------------------------------------
// The two hardware handlers.
// ---------------------------------------------------------------------------------------------
void nmi(void) __attribute__((interrupt, noinline));
void nmi(void) {
    if (nmi_armed) {
        // Reentrancy observation: a nonzero depth means this NMI interrupted the IRQ handler
        // between its own envelope's save and restore.
        if (irq_depth) nest_hits = (uint16_t)(nest_hits + 1u);
        uint16_t n = (uint16_t)(nmi_tally + 1u);
        nmi_tally = n;
        nmi_mix = irqgate_nmi_step(nmi_mix, n);
        if (n == (uint16_t)IRQGATE_NMI_STOP) {
            nmi_armed = 0u;                 // publication barrier: nothing later mutates the snapshot
            nmi_done = 1u;
        }
    }
}

void irq(void) __attribute__((interrupt, noinline));
void irq(void) {
    if (irq_armed) {
        irq_depth = 1u;
        uint16_t n = (uint16_t)(irq_tally + 1u);
        uint16_t nmi_at_entry = nmi_tally;
        // The long body — several hundred cycles of native-width work at raster line VTIME.
        irq_mix = irqgate_irq_step(irq_mix, n);
        // RENDEZVOUS. Hold the handler open until the v-blank NMI has actually fired, so the NMI
        // is guaranteed to land inside this envelope rather than merely likely to. NMI is
        // non-maskable, so the I flag the IRQ entry set does not block it. Bounded, so a
        // pathological run produces a wrong CRC rather than a hang.
        for (uint16_t s = 0u; s < (uint16_t)IRQGATE_SPIN_LIMIT; s++) {
            if (nmi_tally != nmi_at_entry) break;
        }
        irq_tally = n;
        if (n == (uint16_t)IRQGATE_IRQ_STOP) {
            irq_armed = 0u;
            irq_done = 1u;
        }
        irq_depth = 0u;
    }
    // ACK. TIMEUP ($4211) is read-to-clear: without this read the IRQ line stays asserted and the
    // handler re-enters forever the moment RTI restores I. A C volatile MMIO read from inside an
    // ISR is exactly the shape this demo is here to prove.
    volatile uint8_t ack = REG_TIMEUP;
    (void)ack;
}

// CLI/SEI from C. crt0 masks IRQ at reset (`sei` in .init.50) and nothing has ever cleared it, so
// unmasking is this demo's job — and it must happen only AFTER both handlers are armed.
static inline void cpu_cli(void) { __asm__ volatile("cli" ::: "memory"); }
static inline void cpu_sei(void) { __asm__ volatile("sei" ::: "memory"); }

static uint16_t run_gate(void) {
    nmi_tally = 0u;
    irq_tally = 0u;
    nest_hits = 0u;
    nmi_mix = (uint32_t)IRQGATE_NMI_SEED;
    irq_mix = (uint32_t)IRQGATE_IRQ_SEED;
    nmi_done = 0u;
    irq_done = 0u;
    irq_depth = 0u;
    nmi_armed = 1u;
    irq_armed = 1u;

    // Program the V-count timer. Written as two 8-bit stores rather than through the REG_HTIME /
    // REG_VTIME 16-bit aliases: the 5A22's MMIO is byte-wide, and an 8-bit store pair is the same
    // sequence in every width mode.
    REG_HTIMEL = 0u;
    REG_HTIMEH = 0u;
    REG_VTIMEL = (uint8_t)IRQGATE_VTIME;
    REG_VTIMEH = 0u;
    REG_NMITIMEN = (uint8_t)(NMITIMEN_NMI | NMITIMEN_AUTOJOY | NMITIMEN_IRQ_V);
    {
        volatile uint8_t stale = REG_TIMEUP;   // drop any latched flag before unmasking
        (void)stale;
    }
    cpu_cli();

    // Native arithmetic gives both interrupts long M=0/X=0 landing windows, as in #123.
    uint16_t live16 = (uint16_t)0xA55Au;
    uint32_t live32 = (uint32_t)0xC001D00Du;
    while (!(nmi_done && irq_done)) {
        live16 = (uint16_t)((live16 << 1) ^ (live16 >> 3) ^ (uint16_t)0x1021u);
        live32 = (uint32_t)((live32 << 3) ^ (live32 >> 5) ^ (uint32_t)live16);
        main_live16 = live16;
        main_live32 = live32;
    }

    cpu_sei();
    REG_NMITIMEN = (uint8_t)(NMITIMEN_NMI | NMITIMEN_AUTOJOY);  // timer IRQ source off
    {
        volatile uint8_t stale = REG_TIMEUP;
        (void)stale;
    }
    return irqgate_hash(nmi_tally, nmi_mix, irq_tally, irq_mix, nest_hits);
}

// ---------------------------------------------------------------------------------------------
// Presentation: a raster diagram of the frame. The vertical axis is the scanline counter; the two
// interrupts occupy the two rows where they actually fire, and the gold overlap bracket lights
// only while the observed nest count keeps pace with the IRQ tally.
// ---------------------------------------------------------------------------------------------
static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 7), SNES_RGB(4, 11, 21), SNES_RGB(26, 7, 22), SNES_RGB(30, 26, 9)
};

static const char HEX[] = "0123456789ABCDEF";

static void put_hex4(char *b, uint16_t v) {
    b[0] = HEX[(v >> 12) & 15u];
    b[1] = HEX[(v >> 8) & 15u];
    b[2] = HEX[(v >> 4) & 15u];
    b[3] = HEX[v & 15u];
}

static void update_hud(App *a) {
    char b[21];
    for (uint8_t i = 0u; i < 20u; i++) b[i] = ' ';
    b[20] = '\0';
    b[0] = 'N';
    b[1] = '=';
    put_hex4(&b[2], nmi_tally);
    b[7] = 'I';
    b[8] = '=';
    put_hex4(&b[9], irq_tally);
    b[14] = 'X';
    b[15] = '=';
    put_hex4(&b[16], nest_hits);
    text_puts(&a->text, 1, 1, b);
}

static void paint(App *a) {
    /* Rows 0-12 = active display, row 13 = the IRQ raster line (V=IRQGATE_VTIME), row 14 = the
       v-blank NMI band, row 15 = the overlap bracket that lights only where the IRQ handler was
       still open when the NMI hit. A beam runs down the active area each frame. */
    uint8_t beam = (uint8_t)((a->t >> 1) & 15u);
    uint8_t nested = (uint8_t)(nest_hits != 0u && nest_hits == irq_tally);
    uint8_t irq_pulse = (uint8_t)((irq_tally + (a->t >> 2)) & 15u);
    uint8_t nmi_pulse = (uint8_t)((nmi_tally + (a->t >> 2)) & 15u);
    for (uint8_t y = 0u; y < 16u; y++) {
        for (uint8_t x = 0u; x < 16u; x++) {
            uint8_t c;
            if (y <= 12u) {
                c = (uint8_t)(((x + (uint8_t)(nmi_mix >> 8)) & 7u) == 0u ? 1u : 0u);
                if (y == beam) c = 1u;
            } else if (y == 13u) {
                c = 2u;                                   /* IRQ line, scanline 224 */
                if (x == irq_pulse) c = 3u;
            } else if (y == 14u) {
                c = 1u;                                   /* v-blank band, NMI at 225 */
                if (x == nmi_pulse) c = 3u;
            } else {
                /* Overlap bracket: lit only where the IRQ handler was still open when NMI hit. */
                c = (uint8_t)(nested ? 3u : 0u);
                if (!nested && (x & 3u) == 0u) c = 1u;
            }
            canvas_fill_solid_tile(&a->canvas, x, y, c);
        }
    }
    a->canvas.lo = 0u;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

int main(void) {
    static App a;
    static TitleLayer title;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, 8, 6);
    text_init(&a.text, CANVAS_MAP, 1, 25);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, pal, 0, (uint8_t)sizeof pal);
    text_puts(&a.text, 0, 2, "TIMER IRQ GATE");
    title_begin16(&a.screen, &title, "IRQGATE", "RASTER IRQ MEETS NMI");
    title_end(&a.screen, &title, 30);

    /* The gate spins for ~120 v-blanks with the screen static; publish a real frame and a status
       line first so the interval never reads as a hang (the #124 lesson). */
    paint(&a);
    text_puts(&a.text, 1, 1, "ARMING 120 NMI 96 IRQ");
    display_frame(&a.screen);

    corpus_result = run_gate();

    {
        char b[19];
        for (uint8_t i = 0u; i < 18u; i++) b[i] = ' ';
        b[18] = '\0';
        b[0] = 'C';
        b[1] = 'R';
        b[2] = 'C';
        b[3] = '=';
        put_hex4(&b[4], corpus_result);
        text_puts(&a.text, 0, 2, b);
    }
    for (;;) {
        paint(&a);
        update_hud(&a);
        a.t++;
        display_frame(&a.screen);
    }
}
