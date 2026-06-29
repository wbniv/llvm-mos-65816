// Shared, PURE Fourier-epicycles math — the single source of truth for the host oracle
// (tools/epicycles-sim.c), the corpus differential slice (examples/snes/corpus/epicycles_sim.c),
// and the on-screen renderer (examples/snes/epicycles.c). Like spiro.h / mandel.h, this is the
// code under test for the differential: the SAME body runs on the host oracle (int = 32) and the
// 65816 target (int = 16), so host == target bit-for-bit by construction.
//
//   P(t) = Σ_k c_k · exp(i·2π·f_k·t)        (a sum of EPI_NHARM rotating vectors)
//
// Each epicycle k has an integer frequency f_k and a complex coefficient c_k = (re,im); the tip of
// the chain traces a baked outline (a 5-pointed star — examples/65816/epicycles_tables.h, the DFT
// of the star perimeter). The renderer draws the nested circles + arms and the emerging outline
// into a NEAR tiled bitmap canvas (no far pointers), so the program builds default-8-bit AND
// +mos-a16 AND +mos-xy16 and earns the full 5-way differential bar.
//
// The codegen this stresses: a sin/cos-LUT inner loop with FOUR 16×16→32 multiplies per harmonic
// (__mulsi3 — the complex multiply re·cos − im·sin / re·sin + im·cos) + 32-bit accumulation across
// all harmonics, per traced point. All integer ⇒ host == target. NO 32-bit divide (that is the
// spirograph/n-body profile) — this is the many-multiply-accumulate profile.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable, self-contained. See
// docs/plans/2026-06-28-10-snes-fourier-epicycles.md.
#ifndef EPICYCLES_H
#define EPICYCLES_H

#include <stdint.h>
#include "epicycles_tables.h"

// Keep each stamped function a separate noinline callee so its live range is bounded: under -Os the
// compiler otherwise inlines epi_point's 4·N products + 2·N LUT loads + the accumulators into one
// giant main(), and the combined +mos-a16/+mos-xy16 register pressure overflows the imaginary-reg
// file (the handoff §4 pressure trap; same reason spiro.h's SPIRO_FN is noinline). Harmless on host.
#ifndef EPI_FN
#define EPI_FN __attribute__((noinline)) static
#endif

// ---------------------------------------------------------------------------------------------
// 256-entry signed Q8.8 sine LUT (256 == 1.0), range ±256. cos(a) = sin(a + 64). Identical table
// to spiro.h / examples/snes/sincos.h, inlined so the header is self-contained and host-linkable.
//   python3 -c 'import math;print(",".join(str(round(256*math.sin(2*math.pi*a/256))) for a in range(256)))'
static const int16_t EPI_SIN_LUT[256] = {
     0,    6,   13,   19,   25,   31,   38,   44,   50,   56,   62,   68,   74,   80,   86,   92,
    98,  104,  109,  115,  121,  126,  132,  137,  142,  147,  152,  157,  162,  167,  172,  177,
   181,  185,  190,  194,  198,  202,  206,  209,  213,  216,  220,  223,  226,  229,  231,  234,
   237,  239,  241,  243,  245,  247,  248,  250,  251,  252,  253,  254,  255,  255,  256,  256,
   256,  256,  256,  255,  255,  254,  253,  252,  251,  250,  248,  247,  245,  243,  241,  239,
   237,  234,  231,  229,  226,  223,  220,  216,  213,  209,  206,  202,  198,  194,  190,  185,
   181,  177,  172,  167,  162,  157,  152,  147,  142,  137,  132,  126,  121,  115,  109,  104,
    98,   92,   86,   80,   74,   68,   62,   56,   50,   44,   38,   31,   25,   19,   13,    6,
     0,   -6,  -13,  -19,  -25,  -31,  -38,  -44,  -50,  -56,  -62,  -68,  -74,  -80,  -86,  -92,
   -98, -104, -109, -115, -121, -126, -132, -137, -142, -147, -152, -157, -162, -167, -172, -177,
  -181, -185, -190, -194, -198, -202, -206, -209, -213, -216, -220, -223, -226, -229, -231, -234,
  -237, -239, -241, -243, -245, -247, -248, -250, -251, -252, -253, -254, -255, -255, -256, -256,
  -256, -256, -256, -255, -255, -254, -253, -252, -251, -250, -248, -247, -245, -243, -241, -239,
  -237, -234, -231, -229, -226, -223, -220, -216, -213, -209, -206, -202, -198, -194, -190, -185,
  -181, -177, -172, -167, -162, -157, -152, -147, -142, -137, -132, -126, -121, -115, -109, -104,
   -98,  -92,  -86,  -80,  -74,  -68,  -62,  -56,  -50,  -44,  -38,  -31,  -25,  -19,  -13,   -6,
};
#define EPI_SIN(a) (EPI_SIN_LUT[(uint8_t)(a)])
#define EPI_COS(a) (EPI_SIN_LUT[(uint8_t)((a) + 64)])

// ---------------------------------------------------------------------------------------------
// Gate sizing: one full trace is 256 phase units; the gate samples EPI_GATE_N points at stride
// EPI_GATE_STRIDE (64 × 4 = 256 → the whole star). Each point folds 4·EPI_NHARM multiplies, so a
// miscompiled product perturbs the hash on the first point.
#define EPI_PERIOD       256u
#define EPI_GATE_N        32u
#define EPI_GATE_STRIDE    8u

// HOT path: the tip of the epicycle chain at phase `step` (0..255). The four 16×16→32 products per
// harmonic (__mulsi3) + the 32-bit accumulation are the declared stress.
EPI_FN void epi_point(uint8_t step, int16_t *ox, int16_t *oy) {
    int32_t rx = 0, ry = 0;
    for (uint8_t k = 0; k < EPI_NHARM; k++) {
        uint8_t idx = (uint8_t)((int16_t)EPI_FREQ[k] * (int16_t)(uint16_t)step);  // f_k·step mod 256
        int16_t c = EPI_COS(idx), s = EPI_SIN(idx);
        int16_t re = EPI_RE[k], im = EPI_IM[k];
        rx += (int32_t)re * c - (int32_t)im * s;          // Re(c_k · e^{iθ})
        ry += (int32_t)re * s + (int32_t)im * c;          // Im(c_k · e^{iθ})
    }
    *ox = (int16_t)(rx >> EPI_SHIFT);
    *oy = (int16_t)(ry >> EPI_SHIFT);
}

// Renderer helper: the running partial sums (the epicycle chain joints) at phase `step`. Fills
// jx/jy[0..EPI_NHARM]: joint 0 = centre (0,0), joint k+1 = tip after adding harmonic k. The arm
// jx[k]→jx[k+1] is harmonic k's rotating vector; its length is that epicycle's radius. Same
// per-harmonic multiplies as epi_point (kept separate so the gate path stays minimal).
EPI_FN void epi_chain(uint8_t step, int16_t *jx, int16_t *jy) {
    int32_t rx = 0, ry = 0;
    jx[0] = 0; jy[0] = 0;
    for (uint8_t k = 0; k < EPI_NHARM; k++) {
        uint8_t idx = (uint8_t)((int16_t)EPI_FREQ[k] * (int16_t)(uint16_t)step);
        int16_t c = EPI_COS(idx), s = EPI_SIN(idx);
        int16_t re = EPI_RE[k], im = EPI_IM[k];
        rx += (int32_t)re * c - (int32_t)im * s;
        ry += (int32_t)re * s + (int32_t)im * c;
        jx[k + 1] = (int16_t)(rx >> EPI_SHIFT);
        jy[k + 1] = (int16_t)(ry >> EPI_SHIFT);
    }
}

// ---------------------------------------------------------------------------------------------
// Cheap 16-bit rotate-left-xor rolling hash (the spiro_fold / img_hash16 idiom): folds the full 16
// bits of each coordinate. Proof channel: host hash == target hash over the same point stream.
static inline uint16_t epi_fold(uint16_t h, int16_t v) {
    uint16_t hi = (uint16_t)((h >> 15) & 1u);
    return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ (uint16_t)v);
}

// The differential gate: thread one rolling hash over EPI_GATE_N tip points spanning the full
// trace. A codegen defect in any harmonic's complex multiply perturbs the hash.
EPI_FN uint16_t epi_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < EPI_GATE_N; i++) {
        int16_t x, y;
        epi_point((uint8_t)(i * EPI_GATE_STRIDE), &x, &y);
        h = epi_fold(h, x);
        h = epi_fold(h, y);
    }
    return h;
}

#endif /* EPICYCLES_H */
