// Bank/Direct-Page Windows — #141 of the compiler stress-test battery (Round 7, Cluster B).
//
// The D/DBR half of the interrupt-entry contract. A native-mode 65816 interrupt entry forces
// PBR=0 and sets I, but leaves D (direct-page base) and DBR (data bank) exactly as the
// interrupted code had them. Compiled code depends on both every few instructions: every __rc
// imaginary-register access — including the soft-stack pointer __rc0/1 — is D-relative, and
// every absolute access to a C object is DBR-relative. User inline asm may legally move either
// (the #125 asmisland precedent); this demo opens such windows with the NMI armed and RENDEZVOUS
// with the handler inside each one, so a handler entry on a moved D/DBR is guaranteed, not
// merely likely, in every width mode. The interrupt envelope must save D and DBR and
// re-establish the C ABI state (D=0, DBR=0) — this ROM is the loud gate on that contract.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/dpbank.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t t;
} App;

volatile uint16_t corpus_result;

// Handler-shared state. Non-static: the window spins reference these BY NAME from inline asm, so
// the symbols must survive LTO with their C names intact. PINNED to absolute WRAM: the compiler
// otherwise promotes small globals to the zero page (phase-A finding), which silently turns every
// "absolute" access to them into a D-relative one — in a D window the handler's echo store and
// the spin's read then rendezvous inside the decoy instead of in real memory, and in a B window
// they bypass DBR entirely. The demo's addressing claims require these to be genuinely absolute.
#define DPBANK_ABS __attribute__((section(".bss.dpbank")))
DPBANK_ABS volatile uint16_t dpbank_nmi_tally;
DPBANK_ABS volatile uint32_t dpbank_mix;
DPBANK_ABS volatile uint8_t dpbank_echo;  // tally low byte, stored by the handler — the spin release
DPBANK_ABS volatile uint8_t dpbank_t0;    // pre-window snapshot of dpbank_echo, compared by the spins
DPBANK_ABS volatile uint8_t dpbank_armed, dpbank_done;

// The decoy the D window points the direct page at. An unfixed handler's __rc saves land here,
// and the soft-stack pointer it then loads from here is garbage — wild stores follow. A fixed
// handler never touches it: the sentinel checksum is folded into the CRC.
DPBANK_ABS volatile uint8_t dpbank_decoy[DPBANK_DECOY_SIZE];

static volatile uint16_t main_live16;
static volatile uint32_t main_live32;

// ---------------------------------------------------------------------------------------------
// The NMI handler: deliberately D- and DBR-hungry. Ten rounds of 32-bit work force a wide __rc
// live set plus a soft-stack frame (all D-relative); the volatile globals are absolute stores
// (all DBR-relative); the frame-resident volatile local is the #139 C0-check shape.
// ---------------------------------------------------------------------------------------------
void nmi(void) __attribute__((interrupt, noinline));
void nmi(void) {
    if (dpbank_armed) {
        uint16_t n = (uint16_t)(dpbank_nmi_tally + 1u);
        dpbank_nmi_tally = n;
        dpbank_mix = dpbank_step(dpbank_mix, n);
        volatile uint8_t mark = (uint8_t)(n ^ 0x5Au);
        dpbank_mix ^= (uint32_t)mark;
        dpbank_echo = (uint8_t)n;
        if (n == (uint16_t)DPBANK_NMI_STOP) {
            dpbank_armed = 0u;
            dpbank_done = 1u;
        }
    }
}

// ---------------------------------------------------------------------------------------------
// The two windows. Pure asm bodies: no compiled code may run while D or DBR is moved, because
// compiled code is exactly what assumes they are 0. Each spin pins its own width (php/sep/plp),
// so the island is byte-identical in default, a16 and xy16 builds, and each spins until the
// handler's echo byte changes — the rendezvous that guarantees an NMI landed inside the window.
// ---------------------------------------------------------------------------------------------

// D window: direct page moved onto the decoy. DBR is still 0, so the spin may use plain absolute
// addressing (16-bit operands resolve as absolute, not direct-page, for these WRAM symbols).
__attribute__((noinline)) static void dpbank_window_d(void) {
    __asm__ volatile(
        "php\n"
        "phd\n"
        "pea dpbank_decoy\n"
        "pld\n"                   // D := &decoy — every direct-page access now lands in it
        "sep #$20\n"
        "1:\n"
        "lda dpbank_echo\n"
        "cmp dpbank_t0\n"
        "beq 1b\n"                // released only by the handler
        "pld\n"                   // D := 0
        "plp\n"
        ::: "a", "cc", "memory");
}

// B window: DBR moved to $7F, the SECOND 64K of WRAM. Deliberately not $7E: bank-0 addresses
// below $2000 mirror $7E, so $7E would alias the same memory and hide misdirected accesses; $7F
// makes every absolute access inside the window target genuinely different RAM. The spin
// therefore cannot use absolute addressing — it uses raw-encoded 24-bit long addressing
// ($AF/$CF = lda/cmp long), which ignores DBR; the mirrored bank byte $7E reaches the real
// low-WRAM locations of the two symbols.
__attribute__((noinline)) static void dpbank_window_b(void) {
    __asm__ volatile(
        "php\n"
        "phb\n"
        "pea $7f7f\n"
        "plb\n"
        "plb\n"                   // DBR := $7F (twice, balancing the two pea bytes)
        "sep #$20\n"
        "1:\n"
        ".byte $af\n"             // lda f:$7E:dpbank_echo
        ".word dpbank_echo\n"
        ".byte $7e\n"
        ".byte $cf\n"             // cmp f:$7E:dpbank_t0
        ".word dpbank_t0\n"
        ".byte $7e\n"
        "beq 1b\n"
        "plb\n"                   // DBR := 0
        "plp\n"
        ::: "a", "cc", "memory");
}

static uint16_t run_gate(void) {
    dpbank_nmi_tally = 0u;
    dpbank_mix = (uint32_t)DPBANK_MIX_SEED;
    dpbank_echo = 0u;
    dpbank_done = 0u;
    for (uint8_t i = 0u; i < (uint8_t)DPBANK_DECOY_SIZE; i++)
        dpbank_decoy[i] = dpbank_decoy_byte(i);
    dpbank_armed = 1u;

    uint16_t hits_d = 0u;
    uint16_t hits_b = 0u;
    uint16_t live16 = (uint16_t)0xB0D1u;
    uint32_t live32 = (uint32_t)0xD1BAC0DEu;

    for (uint8_t it = 0u; it < (uint8_t)DPBANK_WINDOW_ITERS; it++) {
        // Guard: never open a window the handler can no longer release.
        if (!(dpbank_armed && dpbank_nmi_tally <= (uint16_t)DPBANK_GUARD_MAX)) break;
        dpbank_t0 = dpbank_echo;
        dpbank_window_d();
        if (dpbank_echo != dpbank_t0) hits_d = (uint16_t)(hits_d + 1u);

        // Native-width C work between the windows — ordinary #123 ambient state.
        live16 = (uint16_t)((live16 << 1) ^ (live16 >> 3) ^ (uint16_t)0x1021u);
        live32 = (uint32_t)((live32 << 3) ^ (live32 >> 5) ^ (uint32_t)live16);
        main_live16 = live16;
        main_live32 = live32;

        if (!(dpbank_armed && dpbank_nmi_tally <= (uint16_t)DPBANK_GUARD_MAX)) break;
        dpbank_t0 = dpbank_echo;
        dpbank_window_b();
        if (dpbank_echo != dpbank_t0) hits_b = (uint16_t)(hits_b + 1u);
    }

    // Windows done; let the handler run out to its stop count in plain ambient code.
    while (!dpbank_done) {
        live16 = (uint16_t)((live16 << 1) ^ (live16 >> 3) ^ (uint16_t)0x1021u);
        live32 = (uint32_t)((live32 << 3) ^ (live32 >> 5) ^ (uint32_t)live16);
        main_live16 = live16;
        main_live32 = live32;
    }

    uint16_t decoy_sum = 0u;
    for (uint8_t i = 0u; i < (uint8_t)DPBANK_DECOY_SIZE; i++)
        decoy_sum = (uint16_t)(decoy_sum + (uint16_t)dpbank_decoy[i]);

    return dpbank_hash(dpbank_nmi_tally, dpbank_mix, hits_d, hits_b, decoy_sum);
}

// ---------------------------------------------------------------------------------------------
// Presentation: a memory-map strip. Left band = direct page at $0000 (__rc home), middle band =
// the decoy the D window points at, right band = bank $7F. The active window kind pulses; the
// bottom bracket lights gold only while both hit counters keep pace with the iteration count.
// ---------------------------------------------------------------------------------------------
static const uint16_t pal[4] = {
    SNES_RGB(2, 3, 8), SNES_RGB(6, 12, 20), SNES_RGB(24, 9, 20), SNES_RGB(30, 26, 9)
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
    put_hex4(&b[2], dpbank_nmi_tally);
    b[7] = 'M';
    b[8] = '=';
    put_hex4(&b[9], (uint16_t)dpbank_mix);
    b[14] = 'C';
    b[15] = '=';
    put_hex4(&b[16], corpus_result);
    text_puts(&a->text, 1, 1, b);
}

static void paint(App *a) {
    /* Columns 0-4 = direct page at $0000, 5-9 = the decoy page the D window points at,
       10-15 = bank $7F where the B window sends absolute accesses. Row 15 = the contract
       bracket, gold when the run's CRC matched the host oracle. */
    uint8_t phase = (uint8_t)((a->t >> 2) & 7u);
    uint8_t ok = (uint8_t)(corpus_result != 0u);
    for (uint8_t y = 0u; y < 16u; y++) {
        for (uint8_t x = 0u; x < 16u; x++) {
            uint8_t c;
            if (y == 15u) {
                c = (uint8_t)(ok ? 3u : (uint8_t)((x & 3u) == 0u ? 1u : 0u));
            } else if (x < 5u) {
                c = (uint8_t)(((x + y) & 3u) == 0u ? 1u : 0u);
                if (y == phase) c = 1u;
            } else if (x < 10u) {
                c = 2u;
                if (y == (uint8_t)((phase + 3u) & 15u)) c = 3u;
            } else {
                c = (uint8_t)(((x ^ y) & 3u) == 0u ? 2u : 0u);
                if (y == (uint8_t)((phase + 6u) & 15u)) c = 3u;
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
    text_puts(&a.text, 0, 2, "D DBR WINDOW GATE");
    title_begin16(&a.screen, &title, "DPBANK", "NMI VS MOVED D AND DBR");
    title_end(&a.screen, &title, 30);

    /* The gate spins for ~120 v-blanks with the screen static; publish a real frame and a status
       line first so the interval never reads as a hang (the #124 lesson). */
    paint(&a);
    text_puts(&a.text, 1, 1, "ARMING 120 NMI 40 WIN");
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
