// Shared, PURE Huffman bit-stream decode — host-linkable, no hardware.  Demo #67.
//
// The codegen corner: a **bit-granular stream reader + pointer-linked tree descent**.  The decoder pulls
// one bit at a time (MSB-first) and walks a Huffman tree — left on a 0, right on a 1 — emitting a symbol
// at each leaf, then restarting from the root.  Distinct from #49 (LZ), which was a BYTE-oriented decoder
// copying back-references; this is a BIT reader threading a tree of node pointers.
//
// A 16x16 image (4 colours) is Huffman-encoded (a canonical prefix code) into a bitstream, then decoded
// bit by bit — the classic "image loading in" reveal.  Encoding is a setup helper; the DECODE is the
// corner and is cross-checked against the original in the gate.
//
// WIDTH DISCIPLINE: the bit cursor, tree indices and symbols are uint8/uint16; the stream is a byte
// array; all integer -> bit-exact host vs target.  See docs/plans/2026-06-30-67-snes-huffman.md.
#ifndef HUFFMAN_H
#define HUFFMAN_H

#include <stdint.h>

#define HF_W 16u
#define HF_H 16u
#define HF_N (HF_W * HF_H)          // 256 pixels
#define HF_STREAM_BYTES 96u         // >= worst case: 256 syms * 3 bits / 8 = 96 bytes

// Canonical prefix code for 4 symbols: 0->"0", 1->"10", 2->"110", 3->"111".
static const uint8_t HF_CODE[4]  = { 0u, 0x2u, 0x6u, 0x7u };   // code bits (right-aligned)
static const uint8_t HF_CLEN[4]  = { 1u, 2u,   3u,   3u   };   // code lengths

// The Huffman tree as a flat node array: node.child[bit]; leaf when sym >= 0.
// nodes: 0=root {->1(0), ->2(1)};  1=leaf sym0;  2={->3(0), ->4(1)}; 3=leaf sym1; 4={->5(0),->6(1)};
//        5=leaf sym2; 6=leaf sym3.
static const int8_t  HF_SYM[7]   = { -1,  0, -1,  1, -1,  2,  3 };   // -1 = internal node
static const uint8_t HF_KID0[7]  = {  1,  0,  3,  0,  5,  0,  0 };   // child on bit 0
static const uint8_t HF_KID1[7]  = {  2,  0,  4,  0,  6,  0,  0 };   // child on bit 1

// The source image: a symbol (0..3) per pixel — concentric diamonds so the reveal is recognisable.
static inline uint8_t hf_img(uint8_t x, uint8_t y) {
    uint8_t dx = (uint8_t)((x < 8u) ? (8u - x) : (x - 8u));
    uint8_t dy = (uint8_t)((y < 8u) ? (8u - y) : (y - 8u));
    return (uint8_t)((dx + dy) & 3u);
}

// Encode the whole image into `out` (MSB-first bit packing); returns the number of BITS written.
static uint16_t hf_encode(uint8_t *out) {
    for (uint16_t i = 0u; i < HF_STREAM_BYTES; i++) out[i] = 0u;
    uint16_t bit = 0u;
    for (uint16_t p = 0u; p < HF_N; p++) {
        uint8_t s = hf_img((uint8_t)(p % HF_W), (uint8_t)(p / HF_W));
        uint8_t len = HF_CLEN[s], code = HF_CODE[s];
        for (uint8_t k = 0u; k < len; k++) {
            uint8_t b = (uint8_t)((code >> (len - 1u - k)) & 1u);          // MSB-first
            if (b) out[bit >> 3] |= (uint8_t)(0x80u >> (bit & 7u));
            bit++;
        }
    }
    return bit;
}

// Decode ONE symbol from `in` starting at *bit (advanced past the consumed bits).  THE CORNER: pull one
// bit (MSB-first), descend HF_KID0/HF_KID1, until a leaf (HF_SYM >= 0), restart from root next call.
static uint8_t hf_decode_one(const uint8_t *in, uint16_t *bit) {
    uint8_t node = 0u;                                        // root
    while (HF_SYM[node] < 0) {                                // walk to a leaf
        uint8_t b = (uint8_t)((in[*bit >> 3] >> (7u - (*bit & 7u))) & 1u);     // MSB-first bit
        (*bit)++;
        node = b ? HF_KID1[node] : HF_KID0[node];
    }
    return (uint8_t)HF_SYM[node];
}

// Decode `count` symbols from the bitstream `in` into `out` by walking the Huffman tree bit by bit.
static void hf_decode(const uint8_t *in, uint8_t *out, uint16_t count) {
    uint16_t bit = 0u;
    for (uint16_t p = 0u; p < count; p++) out[p] = hf_decode_one(in, &bit);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t hf_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// Fold the decoded image and cross-check it equals the source (a decode miscompile diverges twice: the
// folded pixels change AND the mismatch counter goes non-zero).  A single-pass gate — no GATE_N loop
// needed; the 256-pixel decode is plenty of bit-tree walking.
static uint16_t huffman_gate_crc(void) {
    static uint8_t stream[HF_STREAM_BYTES];
    static uint8_t out[HF_N];
    uint16_t bits = hf_encode(stream);
    hf_decode(stream, out, HF_N);
    uint16_t h = 0u, bad = 0u;
    for (uint16_t p = 0u; p < HF_N; p++) {
        uint8_t src = hf_img((uint8_t)(p % HF_W), (uint8_t)(p / HF_W));
        if (out[p] != src) bad++;
        h = hf_fold(h, (uint16_t)(out[p] | (uint16_t)(p << 2)));   // mix position so symmetry can't cancel
    }
    for (uint16_t i = 0u; i < HF_STREAM_BYTES; i++) h = hf_fold(h, (uint16_t)stream[i]);  // fold the stream
    h = hf_fold(h, bits);
    h = hf_fold(h, bad);                                      // 0 if decode == source
    return h;
}

#endif /* HUFFMAN_H */
