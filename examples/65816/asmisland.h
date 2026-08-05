// Inline-Asm Island (#125) — opaque assembly inside native-width C code.
#ifndef ASMISLAND_H
#define ASMISLAND_H

#include <stdint.h>

#define ASMISLAND_STEPS 160u

static volatile uint16_t asmisland_word;
static volatile uint8_t asmisland_byte;

#if defined(__mos__)
__attribute__((noinline))
static uint16_t asmisland_step(uint16_t x, uint16_t k) {
    uint16_t live = (uint16_t)(x * 3u + k + 7u);
    asmisland_word = (uint16_t)(x ^ (uint16_t)0x55AAu);
    __asm__ volatile(
        "php\n"
        "sep #$20\n"
        ".byte $a9,$5a\n"       // LDA #$5A, explicitly one-byte immediate
        "sta asmisland_byte\n"
        "rep #$20\n"
        ".byte $a9,$ff,$00\n"   // LDA #$00FF, explicitly two-byte immediate
        "eor asmisland_word\n"
        "sta asmisland_word\n"
        "plp\n"
        ::: "a", "cc", "memory");
    // Both values remain live across the opaque island. Native-width code must
    // be re-established here, and the A clobber must prevent stale residency.
    live = (uint16_t)((live << 3) | (live >> 13));
    return (uint16_t)(live ^ asmisland_word ^ (uint16_t)asmisland_byte);
}
#else
static uint16_t asmisland_step(uint16_t x, uint16_t k) {
    uint16_t live = (uint16_t)(x * 3u + k + 7u);
    asmisland_word = (uint16_t)((x ^ (uint16_t)0x55AAu) ^ (uint16_t)0x00FFu);
    asmisland_byte = (uint8_t)0x5Au;
    live = (uint16_t)((live << 3) | (live >> 13));
    return (uint16_t)(live ^ asmisland_word ^ (uint16_t)asmisland_byte);
}
#endif

static uint16_t asmisland_model(void) {
    uint16_t x = (uint16_t)0x3141u;
    uint16_t h = (uint16_t)0xA51Au;
    for (uint16_t i = 1u; i <= (uint16_t)ASMISLAND_STEPS; i++) {
        x = asmisland_step(x, i);
        h = (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ x ^ i);
    }
    return h;
}

#endif
