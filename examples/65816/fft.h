// Radix-2 DIT Cooley-Tukey FFT — portable cipher for SNES demo #25.
//
// N=32 point DIT (decimation-in-time) FFT in Q8.8 fixed-point arithmetic.
// Hot path: butterfly twiddle multiply — each butterfly executes 4x __mulsi3:
//
//   t_re = ((int32_t)TW_RE[j*w] * x_re[bot] - (int32_t)TW_IM[j*w] * x_im[bot]) >> 8
//   t_im = ((int32_t)TW_RE[j*w] * x_im[bot] + (int32_t)TW_IM[j*w] * x_re[bot]) >> 8
//
// 5 stages × 16 butterflies × 4 __mulsi3 = 320 calls per FFT transform.
// The twiddle step `j*w` also uses __mulsi3 (j and w are runtime values).
// Gate runs the FFT on a fixed 32-sample sawtooth signal and folds the spectrum.
//
// Coverage map: "complex / 32-bit fixed-point multiply" (also covered by #1..#16)
// but in a NEW context (butterfly loop + bit-reversal permutation) — the
// "bit-reversal / interleave permutation" corner (#25 in the table).
//
// NO bare int — all widths explicit (uint32_t / int32_t). See CLAUDE.md §width rules.
#ifndef FFT_H
#define FFT_H

#include <stdint.h>

#define FFT_N        32u    /* DFT size — 5 stages, 16 twiddle factors            */
#define FFT_LOG2_N    5u    /* log2(32)                                            */

/* Q8.8 twiddle factors W_32^k = cos(-2πk/32)*256 + i*sin(-2πk/32)*256, k=0..15.
   Values computed from SPIRO_SIN_LUT (see tools/gen-fft-twiddles.py):
   cos(-2πk/32)*256 = SPIRO_SIN(k*8 + 64), sin(-2πk/32)*256 = -SPIRO_SIN(k*8).    */
static const int16_t FFT_TW_RE[FFT_N / 2u] = {
     256,  251,  237,  213,  181,  142,   98,   50,
       0,  -50,  -98, -142, -181, -213, -237, -251,
};
static const int16_t FFT_TW_IM[FFT_N / 2u] = {
       0,  -50,  -98, -142, -181, -213, -237, -251,
    -256, -251, -237, -213, -181, -142,  -98,  -50,
};

/* Bit-reversal permutation for N=32 (reverse 5 bits of the index).
   Precomputed table: FFT_BITREV[i] = bit-reverse of i (5-bit). */
static const uint8_t FFT_BITREV[FFT_N] = {
     0, 16,  8, 24,  4, 20, 12, 28,
     2, 18, 10, 26,  6, 22, 14, 30,
     1, 17,  9, 25,  5, 21, 13, 29,
     3, 19, 11, 27,  7, 23, 15, 31,
};

/* In-place N=32 DIT FFT. xr[] and xi[] are the real and imaginary input/output
   arrays in Q8.8 format (values = actual * 256).
   After return: xr[k] + i*xi[k] = DFT of (xr+i*xi) at frequency bin k.            */
static void fft_run(int16_t xr[FFT_N], int16_t xi[FFT_N]) {
    /* Bit-reversal permutation: rearrange input in bit-reversed order. */
    for (uint8_t i = 0u; i < (uint8_t)FFT_N; i++) {
        uint8_t j = FFT_BITREV[i];
        if (j > i) {
            int16_t tr = xr[i]; xr[i] = xr[j]; xr[j] = tr;
            int16_t ti = xi[i]; xi[i] = xi[j]; xi[j] = ti;
        }
    }
    /* Cooley-Tukey DIT butterfly stages. */
    for (uint8_t s = 1u; s <= (uint8_t)FFT_LOG2_N; s++) {
        uint8_t  h = (uint8_t)(1u << (uint8_t)(s - 1u));  /* butterfly half-size */
        uint16_t w = (uint16_t)(FFT_N >> s);               /* twiddle step        */
        for (uint8_t k = 0u; k < (uint8_t)FFT_N; k = (uint8_t)(k + 2u * h)) {
            for (uint8_t j = 0u; j < h; j++) {
                uint8_t  top = (uint8_t)(k + j);
                uint8_t  bot = (uint8_t)(k + j + h);
                uint8_t  ti  = (uint8_t)((uint16_t)j * w);  /* twiddle index — runtime! */
                /* Complex multiply: (TW_RE + i*TW_IM) × (xr[bot] + i*xi[bot]). */
                int32_t t_re = (int32_t)((int32_t)FFT_TW_RE[ti] * xr[bot]   /* __mulsi3 */
                                       - (int32_t)FFT_TW_IM[ti] * xi[bot])  /* __mulsi3 */
                               >> 8;
                int32_t t_im = (int32_t)((int32_t)FFT_TW_RE[ti] * xi[bot]   /* __mulsi3 */
                                       + (int32_t)FFT_TW_IM[ti] * xr[bot])  /* __mulsi3 */
                               >> 8;
                xr[bot] = (int16_t)(xr[top] - (int16_t)t_re);
                xi[bot] = (int16_t)(xi[top] - (int16_t)t_im);
                xr[top] = (int16_t)(xr[top] + (int16_t)t_re);
                xi[top] = (int16_t)(xi[top] + (int16_t)t_im);
            }
        }
    }
}

/* Gate CRC: run FFT on a fixed 32-sample sawtooth signal, fold output real/imag.
   The signal is x[i] = i - 16 (in Q8.8: values × 4 so the range is ±64*4=±256).
   A butterfly miscompile changes the spectrum → CRC mismatch.                        */
static inline uint16_t fft_gate_crc(void) {
    int16_t xr[FFT_N], xi[FFT_N];
    for (uint8_t i = 0u; i < (uint8_t)FFT_N; i++) {
        xr[i] = (int16_t)(((int16_t)i - 16) * 4);   /* sawtooth, Q8.8 scaled */
        xi[i] = 0;
    }
    fft_run(xr, xi);
    uint16_t h = 0u;
    for (uint8_t i = 0u; i < (uint8_t)(FFT_N / 2u); i++) {
        h = (uint16_t)((h << 1u) | (h >> 15u)) ^ (uint16_t)xr[i];
        h = (uint16_t)((h << 1u) | (h >> 15u)) ^ (uint16_t)xi[i];
    }
    return h;
}

#endif /* FFT_H */
