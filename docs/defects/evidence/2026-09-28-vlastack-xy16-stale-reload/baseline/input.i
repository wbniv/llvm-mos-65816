# 1 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c" 2
# 10 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c"
# 1 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/../../65816/vlastack.h" 1
# 33 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/../../65816/vlastack.h"
# 1 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 1 3
# 100 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
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
# 295 "/work/build/carry-gate/baseline-install/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 34 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/../../65816/vlastack.h" 2








static uint8_t vs_rle[(24u * (1u + 2u * 16u))];
static uint16_t vs_rowoff[24u];
static uint8_t vs_img[24u][64u];
static uint8_t vs_nruns[24u];
static uint16_t vs_pfxsum[24u];
static uint16_t vs_totalruns;

static uint16_t vs_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}



__attribute__((noinline))
static void vs_build(void) {
    uint16_t s = (uint16_t)0x2F1Bu;
    uint16_t w = (uint16_t)0u;
    vs_totalruns = (uint16_t)0u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)24u; y++) {
        vs_rowoff[y] = w;
        uint16_t hdr = w;
        w++;
        uint8_t n = (uint8_t)0u;
        uint16_t x = (uint16_t)0u;
        while (x < (uint16_t)64u && n < (uint8_t)16u) {
            s = (uint16_t)(vs_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
            uint16_t len = (uint16_t)((uint16_t)((s >> 9) & 7u) + 2u);
            if (n == (uint8_t)(16u - 1u) || (uint16_t)(x + len) > (uint16_t)64u)
                len = (uint16_t)(64u - x);
            uint8_t val = (uint8_t)((uint8_t)((s >> 5) & 3u) |
                                    (uint8_t)((uint8_t)((y + n) & 3u) << 2));
            vs_rle[w++] = (uint8_t)len;
            vs_rle[w++] = val;
            x = (uint16_t)(x + len);
            n++;
        }
        vs_rle[hdr] = n;
        vs_totalruns = (uint16_t)(vs_totalruns + n);
    }
}





__attribute__((noinline))
static void vs_decode(void) {
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)24u; y++) {
        uint16_t p = vs_rowoff[y];
        uint8_t nruns = vs_rle[p];
        vs_nruns[y] = nruns;

        uint16_t pfx[nruns];


        uint16_t acc = (uint16_t)0u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++) {
            acc = (uint16_t)(acc + (uint16_t)vs_rle[(uint16_t)(p + 1u + (uint16_t)(i * 2u))]);
            pfx[i] = acc;
        }



        uint16_t x = (uint16_t)0u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++) {
            uint16_t end = pfx[i];
            uint8_t val = vs_rle[(uint16_t)(p + 2u + (uint16_t)(i * 2u))];
            while (x < end && x < (uint16_t)64u) { vs_img[y][x] = val; x++; }
        }
        while (x < (uint16_t)64u) { vs_img[y][x] = (uint8_t)0u; x++; }


        uint16_t f = (uint16_t)0x9E37u;
        for (uint8_t i = (uint8_t)0u; i < nruns; i++)
            f = (uint16_t)(vs_mul((uint16_t)(f ^ pfx[i]), (uint16_t)25173u) + (uint16_t)13849u);
        vs_pfxsum[y] = f;
    }
}

static uint16_t vs_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(vs_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}





static uint16_t vlastack_gate_crc(void) {
    uint16_t h = (uint16_t)0x4D2Bu;
    vs_build();
    vs_decode();
    h = vs_mix(h, vs_totalruns);
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)24u; y++) {
        h = vs_mix(h, (uint16_t)vs_nruns[y]);
        h = vs_mix(h, vs_pfxsum[y]);
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)64u; x++)
            h = vs_mix(h, (uint16_t)vs_img[y][x]);
    }
    return h;
}



static uint8_t vs_max_runs(void) {
    uint8_t m = (uint8_t)0u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)24u; y++)
        if (vs_nruns[y] > m) m = vs_nruns[y];
    return m;
}
static uint8_t vs_min_runs(void) {
    uint8_t m = (uint8_t)255u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)24u; y++)
        if (vs_nruns[y] < m) m = vs_nruns[y];
    return m;
}
# 11 "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c" 2

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = vlastack_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
