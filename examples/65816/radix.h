// Shared, PURE LSD radix / counting sort — host-linkable, no hardware.  Demo #64.
//
// The codegen corner: a **non-comparison sort** — LSD radix sort built from a histogram (count each
// digit), a prefix-sum (turn counts into output offsets) and a stable scatter (place each element at its
// offset), with **zero comparisons**.  #17 (sort-race) animated quicksort/heapsort/mergesort, all
// comparison-based; a compare-free scatter sort is a different loop nest — array reads/writes and
// running sums, no `cmp` on the hot path.
//
// The demo sorts a row of bars base-16, one nibble at a time (low nibble, then high nibble), animating
// the array after each pass — the bars re-bucket, stable within each digit, until sorted.
//
// WIDTH DISCIPLINE: values are uint8, counts/offsets uint16, all integer -> bit-exact host vs target.
// See docs/plans/2026-06-30-64-snes-radix.md.
#ifndef RADIX_H
#define RADIX_H

#include <stdint.h>

#ifndef RX_N
#define RX_N 16u               // number of elements (bars; one per display column)
#endif
#define RX_RADIX 16u           // base-16 digits (nibbles)

// One stable counting-sort pass on the nibble at `shift` (0 or 4): histogram -> prefix-sum -> scatter.
static void rx_pass(const uint8_t *in, uint8_t *out, uint16_t n, uint8_t shift) {
    uint16_t count[RX_RADIX];
    for (uint8_t d = 0u; d < RX_RADIX; d++) count[d] = 0u;
    for (uint16_t i = 0u; i < n; i++)                       // histogram
        count[(uint8_t)((in[i] >> shift) & 0x0Fu)]++;
    uint16_t sum = 0u;                                       // prefix-sum -> starting offsets
    for (uint8_t d = 0u; d < RX_RADIX; d++) { uint16_t c = count[d]; count[d] = sum; sum = (uint16_t)(sum + c); }
    for (uint16_t i = 0u; i < n; i++) {                     // stable scatter
        uint8_t d = (uint8_t)((in[i] >> shift) & 0x0Fu);
        out[count[d]] = in[i];
        count[d]++;
    }
}

// LSD radix sort of a[0..n) in place (two nibble passes via a scratch buffer).
static void rx_sort(uint8_t *a, uint16_t n) {
    uint8_t tmp[RX_N];
    rx_pass(a, tmp, n, 0u);        // sort by low nibble
    rx_pass(tmp, a, n, 4u);        // then high nibble -> fully sorted
}

// A single pass exposed for the animation (returns into out; caller ping-pongs buffers).
static inline void rx_pass_into(const uint8_t *in, uint8_t *out, uint16_t n, uint8_t shift) {
    rx_pass(in, out, n, shift);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t rx_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 60u
#endif

// Fold the sorted output of GATE_N pseudo-random arrays.  Cross-checks baked into the fold: after each
// sort the array MUST be non-decreasing (fold a 1 per out-of-order pair -> any inversion diverges) and a
// permutation of the input (fold the XOR and sum of both -> must match).  A miscompile in the
// histogram/prefix/scatter diverges.
static uint16_t radix_gate_crc(void) {
    uint16_t h = 0u;
    uint16_t rng = 0x1234u;
    for (uint16_t t = 0u; t < (uint16_t)GATE_N; t++) {
        uint8_t a[RX_N];
        uint16_t in_xor = 0u, in_sum = 0u;
        for (uint16_t i = 0u; i < RX_N; i++) {
            rng ^= (uint16_t)(rng << 7); rng ^= (uint16_t)(rng >> 9); rng ^= (uint16_t)(rng << 8);
            a[i] = (uint8_t)(rng & 0xFFu);
            in_xor ^= a[i]; in_sum = (uint16_t)(in_sum + a[i]);
        }
        rx_sort(a, RX_N);
        uint16_t out_xor = 0u, out_sum = 0u, inv = 0u;
        for (uint16_t i = 0u; i < RX_N; i++) {
            out_xor ^= a[i]; out_sum = (uint16_t)(out_sum + a[i]);
            if (i > 0u && a[i] < a[i - 1u]) inv++;          // must stay 0 (sorted)
            h = rx_fold(h, (uint16_t)a[i]);
        }
        h = rx_fold(h, (uint16_t)(inv));                    // 0 if sorted
        h = rx_fold(h, (uint16_t)(in_xor ^ out_xor));       // 0 if permutation
        h = rx_fold(h, (uint16_t)(in_sum - out_sum));       // 0 if permutation
    }
    return h;
}

#endif /* RADIX_H */
