// Bitboard Knight Tour (#120) — s64 popcount/clz/ctz libcall coverage.
#ifndef BITBOARD64_H
#define BITBOARD64_H

#include <stdint.h>

#define BITBOARD64_STEPS 96u

typedef struct {
    uint64_t current;
    uint64_t visited;
    uint64_t reachable;
    uint8_t square;
    uint8_t degree;
    uint8_t leading;
} Bitboard64State;

static Bitboard64State bitboard64_state;
static volatile uint64_t bitboard64_opaque;

__attribute__((noinline)) static uint8_t bitboard64_pop(uint64_t x) {
    return (uint8_t)__builtin_popcountll(x);
}

__attribute__((noinline)) static uint8_t bitboard64_ctz(uint64_t x) {
    return (uint8_t)__builtin_ctzll(x);
}

__attribute__((noinline)) static uint8_t bitboard64_clz(uint64_t x) {
    return (uint8_t)__builtin_clzll(x);
}

static uint64_t bitboard64_attacks(uint64_t b) {
    uint64_t left1  = (b >> 1) & UINT64_C(0x7F7F7F7F7F7F7F7F);
    uint64_t left2  = (b >> 2) & UINT64_C(0x3F3F3F3F3F3F3F3F);
    uint64_t right1 = (b << 1) & UINT64_C(0xFEFEFEFEFEFEFEFE);
    uint64_t right2 = (b << 2) & UINT64_C(0xFCFCFCFCFCFCFCFC);
    uint64_t horizontal1 = left1 | right1;
    uint64_t horizontal2 = left2 | right2;
    return (horizontal1 << 16) | (horizontal1 >> 16)
         | (horizontal2 << 8)  | (horizontal2 >> 8);
}

static void bitboard64_reset(void) {
    bitboard64_state.current = UINT64_C(1);
    bitboard64_state.visited = UINT64_C(1);
    bitboard64_state.reachable = bitboard64_attacks(UINT64_C(1));
    bitboard64_state.square = 0u;
    bitboard64_state.degree = 2u;
    bitboard64_state.leading = 63u;
}

static uint64_t bitboard64_onehot(uint8_t n) {
    uint64_t bit = UINT64_C(1);
    while (n--) bit <<= 1;
    return bit;
}

__attribute__((noinline))
static uint16_t bitboard64_step(uint16_t h, uint16_t round) {
    uint64_t moves = bitboard64_attacks(bitboard64_state.current);
    uint64_t candidates = moves & ~bitboard64_state.visited;
    bitboard64_opaque = moves;
    uint8_t degree = bitboard64_pop(bitboard64_opaque);
    uint8_t next;
    if (candidates) {
        bitboard64_opaque = candidates;
        next = bitboard64_ctz(bitboard64_opaque);
    } else {
        // Keep the visual moving after a closed component while preserving a nonzero ctz input.
        uint64_t seed = bitboard64_onehot((uint8_t)((round * 13u + degree * 7u) & 63u));
        bitboard64_opaque = seed;
        next = bitboard64_ctz(bitboard64_opaque);
        bitboard64_state.visited = 0u;
    }
    uint64_t next_bit = bitboard64_onehot(next);
    bitboard64_opaque = next_bit;
    uint8_t leading = bitboard64_clz(bitboard64_opaque);
    bitboard64_state.current = next_bit;
    bitboard64_state.visited |= next_bit;
    bitboard64_state.reachable = bitboard64_attacks(next_bit);
    bitboard64_state.square = next;
    bitboard64_state.degree = degree;
    bitboard64_state.leading = leading;

    h = (uint16_t)((h << 5) | (h >> 11));
    h ^= (uint16_t)next | (uint16_t)((uint16_t)degree << 8);
    h = (uint16_t)(h + leading + (uint16_t)bitboard64_state.visited
                   + (uint16_t)(bitboard64_state.visited >> 32));
    return h;
}

static uint16_t bitboard64_model(void) {
    uint16_t h = 0xB120u;
    bitboard64_reset();
    for (uint16_t round = 0; round < BITBOARD64_STEPS; round++)
        h = bitboard64_step(h, round);
    return h;
}

#endif
