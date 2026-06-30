/* fn_plot.h — Recursive-descent float function parser + evaluator.
 *
 * Parser grammar:
 *   expr   = term (('+' | '-') term)*
 *   term   = factor (('*' | '/') factor)*
 *   factor = '(' expr ')' | '-' factor | 'x' | float_literal
 *   float_literal = digit+ ('.' digit*)?
 *
 * Stresses:
 *   - Recursive call graph (soft-stack pressure): fn_eval_expr→fn_eval_term→fn_eval_factor→
 *     fn_eval_expr (for '(…)' subexpressions) — up to 7 levels deep.
 *   - Soft-float libcalls on every evaluation: __mulsf3, __addsf3, __subsf3, __divsf3,
 *     __negsf2, __fixsfsi — the libcall family #21 (Mandelbrot) exercises iteratively; this
 *     demo exercises it recursively, in a completely different call shape.
 *   - String scan (char-by-char pointer walk through the expression).
 *   - Token dispatch via if/switch over token type.
 *
 * Width rules (host: int=32; target: int=16; both: float=32-bit IEEE-754):
 *   All integer state uses explicit-width types (uint8_t, uint16_t, int16_t).
 *   All arithmetic uses float (soft-float on the SNES 65816).
 *   char comparisons are safe: ASCII chars < 128, unsigned/signed is a non-issue.
 *   The type-punning in fn_fp_lo/fn_fp_hi reads float bytes through uint8_t* (valid C99).
 *
 * No hardware here. See examples/snes/fn-plot.c for the SNES renderer.
 * See docs/plans/2026-06-30-24-snes-fn-plot.md.
 */
#ifndef FN_PLOT_H
#define FN_PLOT_H

#include <stdint.h>

/* Gate constants */
#define FN_GATE_N 64u   /* x-sample count; ~9 SNES frames to compute */

/* Four baked expressions; index 0 is the gate expression.
 * Width annotation: pure const string data, placed in ROM. */
static const char * const fn_exprs[] = {
    "x*x-0.5",       /* parabola: 2 mulsf3 + 1 subsf3/frame */
    "x*x*x-x",       /* cubic:    3 mulsf3 + 1 subsf3/frame */
    "x/(x*x+1.0)",   /* rational: 2 mulsf3 + 1 addsf3 + 1 divsf3/frame */
    "x*x*x*x-x*x",   /* quartic:  4 mulsf3 + 2 subsf3/frame (W-shape) */
};
#define FN_NEXPR 4u

/* ─── Forward declarations for mutual recursion ─────────────────────────── */
static float fn_eval_expr  (const char **p, float x);
static float fn_eval_term  (const char **p, float x);
static float fn_eval_factor(const char **p, float x);

/* ─── Helpers ────────────────────────────────────────────────────────────── */

static inline void fn_skip_ws(const char **p) {
    while (**p == ' ') (*p)++;
}

/* Parse an unsigned float literal from *p; advance *p past it.
 * Stresses __mulsf3 (v*10), __addsf3 (v + digit*frac), __mulsf3 (frac*0.1). */
static float fn_parse_num(const char **p) {
    float v = 0.0f;
    while (**p >= '0' && **p <= '9') {
        v = v * 10.0f + (float)(uint8_t)(**p - '0');
        (*p)++;
    }
    if (**p == '.') {
        (*p)++;
        float frac = 0.1f;
        while (**p >= '0' && **p <= '9') {
            v = v + (float)(uint8_t)(**p - '0') * frac;
            frac = frac * 0.1f;
            (*p)++;
        }
    }
    return v;
}

/* ─── Recursive-descent evaluator ───────────────────────────────────────── */

/* factor = '(' expr ')' | '-' factor | 'x' | float_literal
 * noinline: preserve the recursive call shape so the soft-stack ABI is stressed. */
__attribute__((noinline))
static float fn_eval_factor(const char **p, float x) {
    fn_skip_ws(p);
    if (**p == '(') {
        (*p)++;
        float v = fn_eval_expr(p, x);
        if (**p == ')') (*p)++;
        return v;
    }
    if (**p == '-') {
        (*p)++;
        return -fn_eval_factor(p, x);  /* __negsf2 */
    }
    if (**p == 'x') {
        (*p)++;
        return x;
    }
    return fn_parse_num(p);
}

/* term = factor (('*' | '/') factor)*
 * noinline: preserve realistic call shape for ABI stress. */
__attribute__((noinline))
static float fn_eval_term(const char **p, float x) {
    float v = fn_eval_factor(p, x);
    fn_skip_ws(p);
    while (**p == '*' || **p == '/') {
        uint8_t op = (uint8_t)**p;
        (*p)++;
        float r = fn_eval_factor(p, x);
        if (op == (uint8_t)'*') v = v * r;   /* __mulsf3 */
        else                    v = v / r;   /* __divsf3 */
        fn_skip_ws(p);
    }
    return v;
}

/* expr = term (('+' | '-') term)*
 * noinline: preserve recursive call shape for soft-stack stress. */
__attribute__((noinline))
static float fn_eval_expr(const char **p, float x) {
    float v = fn_eval_term(p, x);
    fn_skip_ws(p);
    while (**p == '+' || **p == '-') {
        uint8_t op = (uint8_t)**p;
        (*p)++;
        float r = fn_eval_term(p, x);
        if (op == (uint8_t)'+') v = v + r;   /* __addsf3 */
        else                    v = v - r;   /* __subsf3 */
        fn_skip_ws(p);
    }
    return v;
}

/* Evaluate expression expr_idx at x. Re-parses the string each call
 * (intentional: exercises the full recursive-descent path every pixel). */
static inline float fn_eval(uint8_t expr_idx, float x) {
    const char *p = fn_exprs[expr_idx];
    return fn_eval_expr(&p, x);
}

/* ─── IEEE float bit extraction (valid C99 type-punning via uint8_t*) ───── */

static inline uint16_t fn_fp_lo(float f) {
    const uint8_t *b = (const uint8_t *)&f;
    return (uint16_t)b[0] | ((uint16_t)b[1] << 8);
}
static inline uint16_t fn_fp_hi(float f) {
    const uint8_t *b = (const uint8_t *)&f;
    return (uint16_t)b[2] | ((uint16_t)b[3] << 8);
}

/* ─── Gate CRC ───────────────────────────────────────────────────────────── */

/* Evaluate fn_exprs[0] ("x*x-0.5") at FN_GATE_N equally-spaced x in [-2.0, +2.0),
 * fold the lower and upper 16-bit halves of each IEEE float result into a 16-bit CRC.
 * Bit-exact on host and target: float is IEEE-754 single-precision on both; soft-float
 * guarantees the same rounding as the host FPU (assuming no FMA contraction). */
static uint16_t fn_gate_crc(void) {
    uint16_t h = 0;
    uint16_t i;
    for (i = 0; i < FN_GATE_N; i++) {
        /* step = 4.0 / 64 = 0.0625; x in [-2.0, 1.9375] */
        float xi = -2.0f + (float)i * 0.0625f;
        float yi = fn_eval((uint8_t)0, xi);
        uint16_t lo = fn_fp_lo(yi);
        uint16_t hi = fn_fp_hi(yi);
        h = (uint16_t)(((h << 1) | (h >> 15)) ^ lo ^ hi);
    }
    return h;
}

#endif /* FN_PLOT_H */
