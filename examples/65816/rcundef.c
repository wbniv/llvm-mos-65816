/* examples/65816/rcundef.c — minimal repro + regression gate for the a16/xy16
 * "Using an undefined physical register" MachineVerifier failure (the long-standing
 * `a16-newton-step-rc-undef`, also independently witnessed by the #23 L-system demo).
 *
 * This is the `newton_step()` kernel from examples/65816/newton.h, lifted verbatim into
 * its own TU so the gate (dev/run.sh rcundef) is a tight, deterministic -verify check
 * that does NOT drag in the whole newton demo. Under +mos-a16 / +mos-xy16 at -O1/-Os the
 * function is high-register-pressure: it issues several sequential __mulsi3 libcalls, each
 * clobbering the imaginary $rcN return pair, whose results stay live into a later block.
 * The register coalescer used to join a value read out of $rcN back into that physical
 * pair across a *second* clobbering call, producing a def->use the MachineVerifier rightly
 * rejects (the value happened to survive in $rcN at runtime, so the code ran correctly —
 * it was a latent miscompile hazard, not a wrong answer). Fixed in
 * MOSRegisterInfo::shouldCoalesce (fork patch 0002; see
 * docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md).
 *
 * Gate (dev/run.sh rcundef): this TU + newton_sim.c + lsystem_sim.c must all
 * -verify-machineinstrs CLEAN under +mos-a16 AND +mos-xy16 at -O1 and -Os. A recurrence
 * (the COPY $rcN reappears with no reaching def) hard-FAILs.                            */
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
