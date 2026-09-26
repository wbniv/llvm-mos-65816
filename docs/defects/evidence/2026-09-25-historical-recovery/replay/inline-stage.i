# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64-probe.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64-probe.c" 2
# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64.h" 1




# 1 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 1 3
# 100 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef int16_t int_least16_t;
typedef uint16_t uint_least16_t;
typedef int16_t int_fast16_t;
typedef uint16_t uint_fast16_t;





typedef signed char int8_t;

typedef unsigned char uint8_t;







typedef int8_t int_least8_t;
typedef uint8_t uint_least8_t;
typedef int8_t int_fast8_t;
typedef uint8_t uint_fast8_t;
# 295 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 6 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64.h" 2



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

static uint64_t bitboard64_attacks(uint64_t b) {
    uint64_t left1 = (b >> 1) & 0x7F7F7F7F7F7F7F7FULL;
    uint64_t left2 = (b >> 2) & 0x3F3F3F3F3F3F3F3FULL;
    uint64_t right1 = (b << 1) & 0xFEFEFEFEFEFEFEFEULL;
    uint64_t right2 = (b << 2) & 0xFCFCFCFCFCFCFCFCULL;
    uint64_t horizontal1 = left1 | right1;
    uint64_t horizontal2 = left2 | right2;
    return (horizontal1 << 16) | (horizontal1 >> 16)
         | (horizontal2 << 8) | (horizontal2 >> 8);
}

static void bitboard64_reset(void) {
    bitboard64_state.current = 1ULL;
    bitboard64_state.visited = 1ULL;
    bitboard64_state.reachable = bitboard64_attacks(1ULL);
    bitboard64_state.square = 0u;
    bitboard64_state.degree = 2u;
    bitboard64_state.leading = 63u;
}

static uint64_t bitboard64_onehot(uint8_t n) {
    uint64_t bit = 1ULL;
    while (n--) bit <<= 1;
    return bit;
}

__attribute__((noinline))
static uint16_t bitboard64_step(uint16_t h, uint16_t round) {
    uint64_t moves = bitboard64_attacks(bitboard64_state.current);
    uint64_t candidates = moves & ~bitboard64_state.visited;
    bitboard64_opaque = moves;
    uint8_t degree = (uint8_t)__builtin_popcountll(bitboard64_opaque);
    uint8_t next;
    if (candidates) {
        bitboard64_opaque = candidates;
        next = (uint8_t)__builtin_ctzll(bitboard64_opaque);
    } else {

        uint64_t seed = bitboard64_onehot((uint8_t)((round * 13u + degree * 7u) & 63u));
        bitboard64_opaque = seed;
        next = (uint8_t)__builtin_ctzll(bitboard64_opaque);
        bitboard64_state.visited = 0u;
    }
    uint64_t next_bit = bitboard64_onehot(next);
    bitboard64_opaque = next_bit;
    uint8_t leading = (uint8_t)__builtin_clzll(bitboard64_opaque);
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
    for (uint16_t round = 0; round < 96u; round++)
        h = bitboard64_step(h, round);
    return h;
}
# 2 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64-probe.c" 2

volatile uint16_t bitboard64_probe_result;

void bitboard64_probe(void) {
    bitboard64_reset();
    bitboard64_probe_result = bitboard64_step(0x120Bu, 23u);
}
