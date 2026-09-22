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
