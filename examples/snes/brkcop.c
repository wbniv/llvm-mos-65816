// Software Vectors — #140 of the compiler stress-test battery (Round 7, Cluster B).
//
// BRK and COP are the 65816's SYNCHRONOUS interrupts, and until 2026-08-04 this platform could not
// service either one: `$FFE6` BRK aliased the shared `irq` symbol (indistinguishable from a
// hardware IRQ) and `$FFE4` COP held the literal address `$0000`, so a native-mode `cop` jumped
// into low WRAM and executed data as code. The platform fix (separate weak `brk`/`cop` stubs in
// crt0 plus their own vector slots in link.ld) is part of this demo; the ROM below is what proves
// the wiring by overriding both stubs with real C `__attribute__((interrupt))` handlers.
//
// Each round takes four traps — BRK and COP, each once from a native-width (M=0/X=0) context and
// once from an 8-bit (M=1/X=1) context. Immediately after every trap's signature byte sits a
// poison-guard immediate load whose value is stored to a volatile and folded into the gate hash:
// native BRK/COP push PC+2, so RTI must resume ON that load. Resuming one byte early executes the
// signature byte as an opcode and the sentinel that reaches C is wrong.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/brkcop.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t t;
} App;

volatile uint16_t corpus_result;

// Handler-shared state. Volatile throughout: the handlers run at arbitrary points relative to the
// compiler's view of the mainline, exactly as in #123/#124, even though the traps are synchronous.
static volatile uint16_t brk_hits, cop_hits, brk_mix, cop_mix;

// Poison-guard landing pads. Written by the immediate that follows each trap's signature byte, so
// they are the observable proof of the RTI resume offset. Non-static so the inline asm below can
// name them directly (the asmisland #125 idiom).
volatile uint16_t brkcop_sent16;
volatile uint8_t brkcop_sent8;

// ---------------------------------------------------------------------------------------------
// The two software-interrupt handlers. Overriding crt0's weak `brk:`/`cop:` rti stubs, reached
// through the dedicated native vectors $FFE6 / $FFE4.
// ---------------------------------------------------------------------------------------------
void brk(void) __attribute__((interrupt, noinline));
void brk(void) {
    brk_hits = (uint16_t)(brk_hits + 1u);
    brk_mix = brkcop_step(brk_mix, (uint16_t)BRKCOP_BRK_K);
}

void cop(void) __attribute__((interrupt, noinline));
void cop(void) {
    cop_hits = (uint16_t)(cop_hits + 1u);
    cop_mix = brkcop_step(cop_mix, (uint16_t)BRKCOP_COP_K);
}

// ---------------------------------------------------------------------------------------------
// Trap sites. The MOS assembler has no `cop` mnemonic and no signature operand for `brk`, so both
// trap instructions are emitted as explicit bytes — which also pins the signature byte exactly:
//   .byte $00,$42  =  brk #$42        .byte $02,$5A  =  cop #$5A
// The assembler tracks rep/sep, so the poison-guard `lda #imm` assembles to the width the CPU will
// actually be in when RTI returns (3 bytes at M=0, 2 bytes at M=1).
// ---------------------------------------------------------------------------------------------
static void brk_fire16(void) {
    __asm__ volatile("php\n"
                     "rep #$30\n"          // M=0, X=0: the fault site is native-width
                     ".byte $00,$42\n"     // brk #$42
                     "lda #$5aa5\n"        // POISON GUARD (a9 a5 5a) — RTI must resume here
                     "sta brkcop_sent16\n"
                     "plp\n" ::: "a", "cc", "memory");
}

static void brk_fire8(void) {
    __asm__ volatile("php\n"
                     "sep #$30\n"          // M=1, X=1: the ordinary 8-bit context
                     ".byte $00,$42\n"     // brk #$42
                     "lda #$b7\n"          // POISON GUARD (a9 b7)
                     "sta brkcop_sent8\n"
                     "plp\n" ::: "a", "cc", "memory");
}

static void cop_fire16(void) {
    __asm__ volatile("php\n"
                     "rep #$30\n"
                     ".byte $02,$5a\n"     // cop #$5A
                     "lda #$a55a\n"        // POISON GUARD (a9 5a a5)
                     "sta brkcop_sent16\n"
                     "plp\n" ::: "a", "cc", "memory");
}

static void cop_fire8(void) {
    __asm__ volatile("php\n"
                     "sep #$30\n"
                     ".byte $02,$5a\n"     // cop #$5A
                     "lda #$4d\n"          // POISON GUARD (a9 4d)
                     "sta brkcop_sent8\n"
                     "plp\n" ::: "a", "cc", "memory");
}

// The gate: the identical loop to brkcop_model(), except that every state advance is performed by
// a real trap and every sentinel is the value READ BACK from the poison-guard store.
static uint16_t run_gate(void) {
    brk_hits = 0u;
    cop_hits = 0u;
    brk_mix = (uint16_t)BRKCOP_BRK_SEED;
    cop_mix = (uint16_t)BRKCOP_COP_SEED;
    uint16_t sent = (uint16_t)BRKCOP_SENT_SEED;
    for (uint16_t r = 1u; r <= (uint16_t)BRKCOP_ROUNDS; r++) {
        brk_fire16();
        sent = brkcop_sent_mix(sent, brkcop_sent16, r);
        brk_fire8();
        sent = brkcop_sent_mix(sent, (uint16_t)brkcop_sent8, r);
        cop_fire16();
        sent = brkcop_sent_mix(sent, brkcop_sent16, r);
        cop_fire8();
        sent = brkcop_sent_mix(sent, (uint16_t)brkcop_sent8, r);
    }
    return brkcop_hash(brk_hits, cop_hits, brk_mix, cop_mix, sent);
}

// ---------------------------------------------------------------------------------------------
// Presentation. Two vector lanes — BRK above the seam, COP below — each carrying a travelling
// packet whose lane position is derived from that handler's own accumulated mix, so the two
// vectors are visibly distinct agents rather than one shared handler.
// ---------------------------------------------------------------------------------------------
static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 7), SNES_RGB(4, 9, 18), SNES_RGB(6, 24, 29), SNES_RGB(30, 22, 6)
};

static const char HEX[] = "0123456789ABCDEF";

static void put_hex4(char *b, uint16_t v) {
    b[0] = HEX[(v >> 12) & 15u];
    b[1] = HEX[(v >> 8) & 15u];
    b[2] = HEX[(v >> 4) & 15u];
    b[3] = HEX[v & 15u];
}

static void update_hud(App *a) {
    char b[25];
    for (uint8_t i = 0u; i < 24u; i++) b[i] = ' ';
    b[24] = '\0';
    b[0] = 'B';
    b[1] = '=';
    put_hex4(&b[2], brk_hits);
    b[7] = 'C';
    b[8] = '=';
    put_hex4(&b[9], cop_hits);
    b[14] = 'C';
    b[15] = 'R';
    b[16] = 'C';
    b[17] = '=';
    put_hex4(&b[18], corpus_result);
    text_puts(&a->text, 1, 1, b);
}

static void paint(App *a) {
    uint8_t brk_pos = (uint8_t)(((a->t >> 1) + (brk_mix >> 4)) & 15u);
    uint8_t cop_pos = (uint8_t)((15u - (((a->t >> 1) + (cop_mix >> 4)) & 15u)) & 15u);
    uint8_t brk_lane = (uint8_t)(2u + (brk_mix & 3u));
    uint8_t cop_lane = (uint8_t)(11u + (cop_mix & 3u));
    for (uint8_t y = 0u; y < 16u; y++) {
        for (uint8_t x = 0u; x < 16u; x++) {
            uint8_t c;
            if (y == 7u || y == 8u) {
                /* The vector seam: the two dedicated slots, no longer one shared handler. */
                c = (uint8_t)((x == 4u || x == 11u) ? 3u : 1u);
            } else if (y < 7u) {
                c = (uint8_t)(((x + (brk_mix >> 8)) & 7u) == 0u ? 1u : 0u);
                if (y == brk_lane) c = 2u;
                if (x == brk_pos && y == brk_lane) c = 3u;
            } else {
                c = (uint8_t)(((x + (cop_mix >> 8)) & 7u) == 0u ? 1u : 0u);
                if (y == cop_lane) c = 2u;
                if (x == cop_pos && y == cop_lane) c = 3u;
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
    text_puts(&a.text, 0, 2, "SOFTWARE VECTORS");
    title_begin16(&a.screen, &title, "BRKCOP", "BRK AND COP SPLIT");
    title_end(&a.screen, &title, 30);
    corpus_result = run_gate();
    for (;;) {
        paint(&a);
        update_hud(&a);
        a.t++;
        display_frame(&a.screen);
    }
}
