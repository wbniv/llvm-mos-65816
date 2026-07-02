// #23 SNES compiler stress-test — L-SYSTEM: string rewriting (memcpy/strlen, grown buffer) + bracket stack.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/lsystem.c), the corpus slice
// (examples/snes/corpus/lsystem_sim.c) and the host oracle (tools/lsystem-sim.c).
//
// Why this demo exists: every other demo computes numbers — NONE build strings. This one grows an
// L-system by STRING REWRITING (repeatedly replacing each symbol of a char buffer with its production)
// then a turtle interprets the result into a fractal plant. It leans on the two corners the battery
// never executes:
//
//   1. STRING LIBCALLS over a grown buffer — each rewrite generation copies every symbol's production
//      (a variable-length string) into a growing output buffer with memcpy (RUNTIME length) and measures
//      productions with strlen. No other demo calls the string library at all.
//   2. BRACKET PUSH/POP STACK — the turtle's `[` saves its full state and `]` restores it, so each frond
//      returns to its branch point. A classic save/restore stack.
//
// BIT-EXACT DIFFERENTIAL: rewriting and interpretation are exact byte/integer operations (turtle position
// Q8.8 in int32, heading 0..255 indexing the shared SINCOS 8.8 LUT). Exact ops are reproducible, so a
// conforming build equals host x86 bit-for-bit; a memcpy/strlen miscompile or a botched stack frame
// corrupts the string or the path and the gate CRC diverges. Far-pointer-free (buffers, stack, turtle all
// in bank-0 WRAM) -> full 5-way bar.
#ifndef LSYSTEM_H
#define LSYSTEM_H

#include <stdint.h>
#include "../snes/sincos.h"     // SINCOS[256], signed 8.8 sine; cos(a)=SINCOS[(a+64)&255]

#ifndef LS_MAX_LEN
#define LS_MAX_LEN  2400u       // rewrite buffer cap (a generation that would overflow stops cleanly)
#endif
#ifndef LS_GEN
#define LS_GEN      6u          // rewrite generations (gen 6 = 2388 chars / 567 F-segments)
#endif
#ifndef LS_ANGLE
#define LS_ANGLE    18          // turn per +/- (of 256 = 360 deg ~ 25 deg)
#endif
#ifndef LS_STEP
#define LS_STEP     38          // forward distance per F, Q4.4 (1/16 px) — 38 ~ 2.4 px
#endif
#ifndef LS_START_X
#define LS_START_X  70
#endif
#ifndef LS_START_Y
#define LS_START_Y  124         // bottom-centre; the plant grows upward
#endif
#define LS_START_H  192         // heading pointing up (-y)
#define LS_CANVAS   128
#define LS_STACK    24          // bracket-stack depth

// One rewrite buffer (file-scope so it lives in .bss, not the soft stack). The rewrite is done IN PLACE
// with memmove (overlapping shift) — half the memory of ping-pong, and it exercises memmove too.
static char ls_buf[LS_MAX_LEN];

// Production for a symbol: the bracketed plant. Returns a NUL-terminated rule (or the symbol itself).
static const char *ls_rule(char c) {
  switch (c) {
    case 'X': return "F-[[X]+X]+F[+FX]-X";   // branch into two sub-fronds
    case 'F': return "FF";                    // elongate each segment
    default:  return (const char *)0;         // +, -, [, ] copy through as themselves
  }
}

// Rewrite the axiom LS_GEN times IN PLACE in a single grown buffer, expanding each symbol with memmove
// (shift the tail right, an overlapping copy) + memcpy (write the production) + strlen (its length) — the
// string-libcall corner. A generation that would overflow LS_MAX_LEN stops cleanly (the remaining symbols
// of that generation stay unexpanded — still well-formed, since a production is never split). Returns the
// buffer and its final length.
static const char *lsystem_build(uint16_t *out_len) {
  ls_buf[0] = 'X';
  uint16_t len = 1;
  for (uint8_t g = 0; g < (uint8_t)LS_GEN; g++) {
    uint16_t i = 0;
    while (i < len) {
      const char *p = ls_rule(ls_buf[i]);
      if (!p) { i++; continue; }                                // literal: leave as-is
      uint16_t pl = (uint16_t)__builtin_strlen(p);              // <-- strlen
      if ((uint16_t)(len + (pl - 1u)) > (uint16_t)(LS_MAX_LEN - 1u)) goto done;  // would overflow → stop
      __builtin_memmove(&ls_buf[i + pl], &ls_buf[i + 1],        // <-- memmove: shift the tail right by pl-1
                        (uint16_t)(len - (i + 1u)));
      __builtin_memcpy(&ls_buf[i], p, pl);                      // <-- memcpy: write the production in place
      len = (uint16_t)(len + (pl - 1u));
      i = (uint16_t)(i + pl);                                   // skip past the freshly inserted production
    }
  }
done:
  if (out_len) *out_len = len;
  return ls_buf;
}

// Turtle state, saved/restored by the bracket stack.
typedef struct { int32_t x, y; uint8_t h, depth; } LTurtle;

// Per-segment emit callback (the renderer draws; the gate passes NULL). Coords are canvas pixels 0..127.
typedef void (*LEmit)(void *ctx, uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t col);

static inline uint8_t ls_px(int32_t q88) {
  int32_t p = q88 >> 8;
  if (p < 0) p = 0; else if (p > LS_CANVAS - 1) p = LS_CANVAS - 1;
  return (uint8_t)p;
}

// Interpret the rewritten string as turtle graphics. Folds every F segment into a rotate-XOR CRC16 and,
// if `emit` is non-NULL, draws it. The `[`/`]` save/restore is the bracket-stack corner. Returns the CRC.
static uint16_t lsystem_interp(const char *s, uint16_t len, LEmit emit, void *ctx) {
  LTurtle t; t.x = (int32_t)LS_START_X << 8; t.y = (int32_t)LS_START_Y << 8;
  t.h = LS_START_H; t.depth = 0;
  LTurtle stk[LS_STACK]; uint8_t sp = 0;
  uint16_t crc = 0xFFFF;
  for (uint16_t i = 0; i < len; i++) {
    char c = s[i];
    if (c == 'F') {
      int32_t nx = t.x + ((int32_t)LS_STEP * SINCOS[(uint8_t)(t.h + 64)] >> 4);   // __mulsi3 (cos); Q4.4 step
      int32_t ny = t.y + ((int32_t)LS_STEP * SINCOS[t.h] >> 4);                   // __mulsi3 (sin)
      uint8_t x0 = ls_px(t.x), y0 = ls_px(t.y), x1 = ls_px(nx), y1 = ls_px(ny);
      uint8_t col = (uint8_t)(t.depth == 0 ? 1u : (t.depth < 3u ? 2u : 3u));
      crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)((x0 << 8) | y0));
      crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)((x1 << 8) | y1));
      crc = (uint16_t)((uint16_t)(((unsigned)crc << 1) | ((unsigned)crc >> 15)) ^ (uint16_t)col);
      if (emit) emit(ctx, x0, y0, x1, y1, col);
      t.x = nx; t.y = ny;
    } else if (c == '+') {
      t.h = (uint8_t)(t.h - (uint8_t)LS_ANGLE);
    } else if (c == '-') {
      t.h = (uint8_t)(t.h + (uint8_t)LS_ANGLE);
    } else if (c == '[') {
      if (sp < LS_STACK) stk[sp++] = t;          // push the whole turtle state
      if (t.depth < 255u) t.depth++;
    } else if (c == ']') {
      if (sp > 0) t = stk[--sp];                 // restore it
    }
    // 'X' and anything else: no-op
  }
  return crc;
}

// Differential anchor: rewrite then interpret with no draw callback; return the path CRC. Exercises the
// string libcalls (build) and the bracket stack (interp). Far-pointer-free -> 5-way, bit-exact.
static inline uint16_t lsystem_gate_crc(void) {
  uint16_t len;
  const char *s = lsystem_build(&len);
  return lsystem_interp(s, len, (LEmit)0, (void *)0);
}

#endif /* LSYSTEM_H */
