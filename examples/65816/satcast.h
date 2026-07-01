// Saturating-Cast Kaleidoscope (#77) — shared, portable logic header.
//
// Stresses:
//   fminf(32767.0f, x)  → G_FMINNUM  → SDK fminf  (math.cc:18)
//   fmaxf(-32768.0f, y) → G_FMAXNUM  → SDK fmaxf  (math.cc:19)
//   (int16_t) cast      → G_FPTOSI   → legalizer :502 inserts NaN guard
//     (buildIsFPClass(fcNan)+buildFMaxNum+buildFMinNum+buildFPTOUI+buildSelect)
//
// The explicit clamp idiom (int16_t)fmaxf(MIN,fminf(MAX,x)) links the SDK's
// fminf/fmaxf and G_FPTOSI without the fptosi_sat intrinsic.  The NaN guard
// at :502 fires only if a NaN reaches the cast (see sc_cast below).
// Distinct from:
//   #44 hdr-bloom: integer __builtin_add_overflow / G_UADDO, no float cast
//   #59 cosmzoom: exact 64-bit round-trip cast, no clamp, no fmin/fmax
//
// Visual: 6-fold hex kaleidoscope on the 128×128 BG3 canvas.  Each tile maps
// to hex axial coordinates (q,r,s=-q-r); sorting |q|,|r|,|s| folds to the
// first sextant (6-fold symmetry).  Float intensity = a²·SCALE_A − b²·SCALE_B
// + phase_f, where (a,b,c) = sorted absolute hex coords and phase_f advances
// each frame.  sc_cast(intensity) clamps and casts: outer tiles (large a)
// saturate to INT16_MAX (colour 3 = bright) at high phase; at low phase they
// saturate to INT16_MIN (colour 0 = dark).  Inner sextant edges show the
// colour gradient.
//
// WIDTH DISCIPLINE: all integers uint16_t/int16_t; float for sc_cast ops only.
// DIFFERENTIAL: correctly-rounded soft-float — fminf/fmaxf exact selections,
// FPTOSI round-toward-zero IEEE, NaN check folded as INT16_MIN; colour indices
// (0..3) are integer and CRC-folded; any wrong clamp direction or missing node
// diverges the CRC.
//
// See docs/plans/2026-07-01-77-snes-satcast.md.

#ifndef SATCAST_H
#define SATCAST_H

#include <stdint.h>
// fminf/fmaxf accessed via compiler builtins to avoid math.h include-path issues
// in the corpus cross-compile environment.  __builtin_fminf/__builtin_fmaxf are
// recognized by both clang (→ llvm.minnum/maxnum → G_FMINNUM/G_FMAXNUM) and gcc.
#define _SC_FMINF(a,b) __builtin_fminf((a),(b))
#define _SC_FMAXF(a,b) __builtin_fmaxf((a),(b))

// ------------------------------------------------------------------
// Saturating cast: clamp x to [INT16_MIN, INT16_MAX], then convert.
// Separate statements prevent FMA fusion.  NaN handled by legalizer
// guard on the target (legalizeShiftRotate :502) and explicitly on
// the host.
// ------------------------------------------------------------------
static inline int16_t sc_cast(float x) {
    // Host NaN guard (matches legalizer's INT16_MIN outcome).
    // On clang/target the legalizer inserts this guard automatically.
    if (x != x) return (int16_t)-32768;          // NaN → INT16_MIN
    float lo = _SC_FMINF(32767.0f, x);           // G_FMINNUM (__builtin_fminf)
    float hi = _SC_FMAXF(-32768.0f, lo);         // G_FMAXNUM (__builtin_fmaxf)
    return (int16_t)hi;                          // G_FPTOSI; :502 guard above
}

// ------------------------------------------------------------------
// Tile colour [0..3] for the 6-fold saturation kaleidoscope.
// tx, ty in [0..15]; phase_f is the animation float (advances per frame).
//
// Algorithm:
//   q = tx−8, r = ty−8, s = −q−r     (hex axial coordinates)
//   a,b,c = sort(|q|,|r|,|s|)         (a≥b≥c≥0; first sextant = 6-fold fold)
//   intensity = a²·200 − b²·50 + phase_f   (separate float statements)
//   iv = sc_cast(intensity)
//   colour = top 2 bits of (iv offset to unsigned) → [0..3]
// Sort by value (no pointers — avoids slow stack-address-of on the 65816).
// ------------------------------------------------------------------
static inline uint8_t sc_tile_color(uint16_t tx, uint16_t ty, float phase_f) {
    int16_t q = (int16_t)((int16_t)tx - (int16_t)8);
    int16_t r = (int16_t)((int16_t)ty - (int16_t)8);
    int16_t s = (int16_t)((int16_t)0 - q - r);

    // Absolute values.
    uint16_t a = (uint16_t)(q < (int16_t)0 ? (uint16_t)(-(int16_t)q) : (uint16_t)q);
    uint16_t b = (uint16_t)(r < (int16_t)0 ? (uint16_t)(-(int16_t)r) : (uint16_t)r);
    uint16_t c = (uint16_t)(s < (int16_t)0 ? (uint16_t)(-(int16_t)s) : (uint16_t)s);
    // Branchless sort by value (no pointer args → stays register-resident on 65816).
    uint16_t t;
    if (a < b) { t = a; a = b; b = t; }
    if (b < c) { t = b; b = c; c = t; }
    if (a < b) { t = a; a = b; b = t; }
    (void)c;  // c not used in the intensity formula

    // Float intensity: separate statements (no FMA fusion).
    float fa = (float)(int16_t)a;   // __floatsisf
    float fb = (float)(int16_t)b;   // __floatsisf
    float a2 = fa * fa;             // __mulsf3  (a in [0..15] → a² in [0..225])
    float b2 = fb * fb;             // __mulsf3
    float ta = a2 * 200.0f;         // __mulsf3  (0..45000 > INT16_MAX for a>=13)
    float tb = b2 * 50.0f;          // __mulsf3  (0..11250)
    float raw = ta - tb;            // __subsf3
    float intensity = raw + phase_f; // __addsf3

    // Saturating cast: fmaxf/fminf then (int16_t).
    int16_t iv = sc_cast(intensity);

    // Map int16_t → [0..3]: shift value to unsigned [0..65535], take top 2 bits.
    // INT16_MIN → 0, near-zero → 2, INT16_MAX → 3.
    return (uint8_t)((uint16_t)((uint16_t)iv + (uint16_t)32768u) >> (uint16_t)14u);
}

// CRC fold step (rotating XOR).
static inline uint16_t sc_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// ------------------------------------------------------------------
// Differential gate: GATE_N phases × 8 tiles per phase (kept small
// for soft-float speed: each sc_tile_color has 4 __mulsf3 + 2 fmin/fmax).
// phase_f = (float)(int16_t)(phase * 4096) gives wide sweep in 16 steps.
// Tiles chosen to hit saturated outer (tx=1,ty=1), gradient mid (tx=7,ty=7),
// and centre (tx=8,ty=8) — all three behavioural zones.
// GATE_N = 16 (16 phases × 8 tiles = 128 float-cast ops; non-zero CRC).
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 16u
#endif

static const uint8_t _SC_TX[8] = { 1u, 3u, 6u, 8u,  9u, 11u, 14u,  2u };
static const uint8_t _SC_TY[8] = { 1u, 5u, 7u, 8u, 10u, 12u, 15u, 13u };

static uint16_t satcast_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t phase;
    for (phase = (uint16_t)0u; phase < (uint16_t)GATE_N; phase++) {
        // Sweep phase_f over saturation-inducing range.
        float phase_f = (float)(int16_t)((uint16_t)(phase * (uint16_t)4096u));
        uint16_t i;
        for (i = (uint16_t)0u; i < (uint16_t)8u; i++) {
            uint8_t col = sc_tile_color((uint16_t)_SC_TX[i], (uint16_t)_SC_TY[i], phase_f);
            h = sc_fold(h, (uint16_t)col);
        }
    }
    return h;
}

#endif /* SATCAST_H */
