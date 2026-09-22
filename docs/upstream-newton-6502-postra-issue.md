# [MOS] Post-RA expansion produces an undefined Y read at -O0 on mos6502

Compiling the C function below with `--target=mos -mcpu=mos6502 -O0
-mllvm -verify-machineinstrs` fails after post-RA pseudo instruction expansion.
It succeeds without MachineVerifier, and with MachineVerifier at `-O1`, `-O2`,
`-O3`, `-Os`, and `-Oz`.

The function is the Newton-step calculation from a C torture test packaged as
the [Newton Fractal SNES demo](https://biohack.net/snes/newton/). This reproduction
uses ordinary 6502 compilation with no native-width feature flags, inline
assembly, or downstream compiler patches. The function body is retained from
the standalone demo-derived compiler input; it is not a constructed MIR test.

## Reproducer

Save as `newton-step.c`:

```c
#include <stdint.h>

__attribute__((noinline)) void newton_step(int16_t *zr, int16_t *zi) {
    int16_t r = *zr, i = *zi;
    /* z² = (r²−i², 2ri) in Q8.8 */
    int16_t z2r = (int16_t)(((int32_t)r * (int32_t)r - (int32_t)i * (int32_t)i) >> 8);
    int16_t z2i = (int16_t)(((int32_t)r * (int32_t)i) >> 7);
    /* z³ = z²·z in Q8.8 */
    int16_t z3r = (int16_t)(((int32_t)z2r * (int32_t)r - (int32_t)z2i * (int32_t)i) >> 8);
    int16_t z3i = (int16_t)(((int32_t)z2r * (int32_t)i + (int32_t)z2i * (int32_t)r) >> 8);
    int16_t nr = (int16_t)(z3r - 256);
    int16_t ni = z3i;
    int16_t dr = (int16_t)(3 * (int32_t)z2r);
    int16_t di = (int16_t)(3 * (int32_t)z2i);
    int32_t snr = (int32_t)nr >> 1, sni = (int32_t)ni >> 1;
    int32_t sdr = (int32_t)dr >> 1, sdi = (int32_t)di >> 1;
    int32_t den = sdr * sdr + sdi * sdi;
    if (den == 0) return;   /* degenerate: z ≈ 0, skip */
    int32_t qr = ((snr * sdr + sni * sdi) << 8) / den;
    int32_t qi = ((sni * sdr - snr * sdi) << 8) / den;
    if (qr >  512) qr =  512;
    if (qr < -512) qr = -512;
    if (qi >  512) qi =  512;
    if (qi < -512) qi = -512;
    *zr = (int16_t)(r - (int16_t)qr);
    *zi = (int16_t)(i - (int16_t)qi);
}
```

```sh
clang --target=mos -mcpu=mos6502 -O0 -mllvm -verify-machineinstrs \
  -c newton-step.c -o newton-step.o
```

Expected: generated machine instructions pass verification.

Observed diagnostic:

```text
# After Post-RA pseudo instruction expansion pass
*** Bad machine code: Using an undefined physical register ***
- function:    newton_step
- instruction: $rc6 = STImag8 $y
- operand 1:   $y
fatal error: error in backend: Found 1 machine code errors.
```

## Validation and limits

Reproduced September 22, 2026, with Clang and the backend built from unmodified
[`742d554bf08042b8df93d791c335260fadd16643`](https://github.com/llvm-mos/llvm-mos/commit/742d554bf08042b8df93d791c335260fadd16643),
which was upstream `main` when checked that day. The compiler reports Clang
`24.0.0git`; this is a Release build with assertions disabled and MOS enabled.
The C input passes through the stock frontend, backend, and integrated assembler;
no intermediate IR or MIR edits are needed.

| Optimization | Normal compilation | With MachineVerifier |
|---|---|---|
| `-O0` | Pass | Undefined `$y` after post-RA expansion |
| `-O1`, `-O2`, `-O3`, `-Os`, `-Oz` | Pass | Pass |

The failure stage and instruction above are observations, not a root-cause
diagnosis. No compiler fix or runtime-miscompile claim is included. The input
is not claimed to be minimal.
