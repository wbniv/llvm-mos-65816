// Shared, PURE signed-64-bit odometer — host-linkable, no hardware.  Demo #43.
//
// The codegen corner: **signed 64-bit divide + modulo** (`__divdi3` / `__moddi3`), distinct from #22's
// *unsigned* `__udivdi3`.  A giant signed odometer ticks THROUGH zero (negative → positive); each frame
// its value is decomposed into 18 decimal digits by the classic `v%10` / `v/=10` loop, which on a
// negative operand exercises the **sign-correction** wrappers around the 64-bit division libcalls
// (C truncates toward zero; `%` of a negative operand yields a non-positive remainder).
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - the odometer + steps are int64_t (identical on host and target); digits are uint8_t
//   - the fold masks every step to uint16_t
// See docs/plans/2026-06-30-43-snes-sodo.md.
#ifndef SODO_H
#define SODO_H

#include <stdint.h>

#define ODO_DIGITS 18            // enough for a full int64 magnitude

// Decompose a signed 64-bit value into ODO_DIGITS base-10 digits (LSB first) + a sign (-1/0/1).
// Each iteration: `v % 10` -> __moddi3 (sign-corrected), `v / 10` -> __divdi3 (sign-corrected).
static void odo_digits(int64_t v, uint8_t *dig, int8_t *sign) {
    *sign = (int8_t)((v < 0) ? -1 : (v > 0 ? 1 : 0));
    for (uint8_t i = 0; i < ODO_DIGITS; i++) {
        int64_t d = v % (int64_t)10;      // signed modulo (negative for v<0)
        if (d < 0) d = -d;
        dig[i] = (uint8_t)d;
        v = v / (int64_t)10;              // signed divide (truncates toward zero)
    }
}

// ---------------------------------------------------------------------------------------------
// Differential gate: sweep the odometer through zero, folding each frame's digits + sign.

static inline uint16_t sodo_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 60u
#endif

// A step chosen so the run crosses zero and lands on assorted signs/magnitudes.
#define ODO_BASE (-(int64_t)620000000000LL)
#define ODO_STEP ( (int64_t)  41000000000LL)

static uint16_t sodo_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        int64_t v = ODO_BASE + (int64_t)i * ODO_STEP;    // sweeps negative -> positive
        uint8_t dig[ODO_DIGITS];
        int8_t sign;
        odo_digits(v, dig, &sign);
        uint16_t s = (uint16_t)(uint8_t)sign;
        for (uint8_t k = 0; k < ODO_DIGITS; k++)
            s = (uint16_t)((uint16_t)(s * 10u) + dig[k]);
        h = sodo_fold(h, s);
    }
    return h;
}

#endif /* SODO_H */
