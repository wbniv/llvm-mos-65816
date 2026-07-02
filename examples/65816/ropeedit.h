// Gap-Buffer Rope Editor (#96) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster A (final). Re-stresses patch 0002
// (`MOSInsertREPSEP::placeIntraBlock`, the #23 lsystem / +mos-xy16 in-place-memmove index-width
// fix) AT SCALE, in a realistic data-structure form: a gap buffer (the classic text-editor rope).
// Text lives in buf[0,gap_start) and buf[gap_end,RE_N); the gap is the free region at the cursor.
// Every cursor MOVE `memmove`s the intervening text ACROSS the gap — left OR right — and with a
// 576-byte buffer holding ~480 chars, those moves are > 256 bytes, so the SDK memmove indexes with
// a 16-bit register (the #23 width-flag boundary). A scripted edit stream (type / delete / jump)
// drives both directions repeatedly, and the moves overlap the gap (re-hitting #79's G_MEMMOVE
// direction logic too). Unlike #93 ovmove (4 synthetic memmoves/step) this is memmove as a real
// editor primitive — bigger, both ways, interleaved with grow/shrink.
//
// WIDTH DISCIPLINE: offsets uint16_t; text uint8_t; no float; no divide in the hot path (the one
// modulo picks a cursor target during setup of each op). DIFFERENTIAL: a gap buffer is a pure byte
// shuffle → bit-identical host vs target. A dropped 16-bit-offset high byte mis-moves text AND
// diverges the byte-CRC. See docs/plans/2026-07-02-96-snes-ropeedit.md.

#ifndef ROPEEDIT_H
#define ROPEEDIT_H

#include <stdint.h>
#define _RE_MEMMOVE(d, s, n) __builtin_memmove((d), (s), (n))

#define RE_N     576u                                   // gap buffer bytes (> 256 → 16-bit offset)
#define RE_FILL  ((uint8_t)0x2Eu)                        // '.' — full init so the buffer is deterministic

typedef struct {
    uint8_t  buf[RE_N];
    uint16_t gap_start;   // text occupies [0, gap_start)
    uint16_t gap_end;     // ...and [gap_end, RE_N); the gap is [gap_start, gap_end)
} Rope;

static void re_init(Rope *r) {
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)RE_N; i++) r->buf[i] = RE_FILL;
    r->gap_start = (uint16_t)0u;
    r->gap_end   = (uint16_t)RE_N;
}

static inline uint16_t re_textlen(const Rope *r) {
    return (uint16_t)(r->gap_start + (uint16_t)((uint16_t)RE_N - r->gap_end));
}

// Insert one char at the cursor (fills the gap from the left).
static inline void re_insert(Rope *r, uint8_t ch) {
    if (r->gap_start < r->gap_end) r->buf[r->gap_start++] = ch;
}

// Backspace (grows the gap from the left).
static inline void re_delete(Rope *r) {
    if (r->gap_start > (uint16_t)0u) r->gap_start--;
}

// Move the cursor (gap) to logical position pos, memmoving text across the gap. BOTH directions;
// the moved span can exceed 256 bytes → a 16-bit-indexed SDK memmove (the #23 boundary), and the
// ranges can overlap the gap (#79 direction logic). noinline: a real call boundary + pressure.
__attribute__((noinline))
static void re_move(Rope *r, uint16_t pos) {
    if (pos < r->gap_start) {
        uint16_t count = (uint16_t)(r->gap_start - pos);                 // shift text right into gap tail
        _RE_MEMMOVE(&r->buf[(uint16_t)(r->gap_end - count)], &r->buf[pos], count);
        r->gap_end   = (uint16_t)(r->gap_end - count);
        r->gap_start = pos;
    } else if (pos > r->gap_start) {
        uint16_t count = (uint16_t)(pos - r->gap_start);                 // shift text left into gap head
        _RE_MEMMOVE(&r->buf[r->gap_start], &r->buf[r->gap_end], count);
        r->gap_start = (uint16_t)(r->gap_start + count);
        r->gap_end   = (uint16_t)(r->gap_end + count);
    }
}

// Byte-CRC fold over the whole physical buffer (fully initialised → deterministic incl. stale gap).
static inline uint16_t re_fold(uint16_t h, uint16_t v, uint16_t step) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    + v
                    + (uint16_t)((uint16_t)step * (uint16_t)53u));
}

// --------------------------------------------------------------------------
// Differential gate: build a big body of text, then run GATE_N scripted edit ops (each does a big
// both-direction cursor jump = a >256-byte memmove, plus type/delete), folding all RE_N bytes/op.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 20u
#endif

static Rope _re_gate;   // BSS (not soft-stack)

static uint16_t ropeedit_gate_crc(void) {
    re_init(&_re_gate);
    // Phase 0: type ~480 chars so the text spans the buffer (cursor jumps → >256-byte memmoves).
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)480u; i++)
        re_insert(&_re_gate, (uint8_t)((uint8_t)0x41u + (uint8_t)((uint16_t)i % (uint16_t)26u)));  // 'A'..'Z'

    uint16_t h    = (uint16_t)0u;
    uint16_t seed = (uint16_t)0xBEEFu;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        // xorshift16 for a deterministic edit script.
        seed ^= (uint16_t)(seed << 7); seed ^= (uint16_t)(seed >> 9); seed ^= (uint16_t)(seed << 8);
        uint16_t tl  = re_textlen(&_re_gate);
        uint16_t pos = (uint16_t)(seed % (uint16_t)(tl + (uint16_t)1u));   // jump target 0..textlen
        re_move(&_re_gate, pos);                                           // the >256-byte memmove
        // type a short run, then delete a couple (grow + shrink around the cursor).
        for (uint16_t j = (uint16_t)0u; j < (uint16_t)6u; j++)
            re_insert(&_re_gate, (uint8_t)((uint8_t)0x61u + (uint8_t)((uint16_t)((uint16_t)step + j) % (uint16_t)26u)));
        re_delete(&_re_gate); re_delete(&_re_gate);
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)RE_N; i++)
            h = re_fold(h, (uint16_t)_re_gate.buf[i], step);
    }
    return h;
}

#endif /* ROPEEDIT_H */
