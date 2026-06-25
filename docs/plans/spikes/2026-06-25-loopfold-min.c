// MINIMAL repro of the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile, produced by cvise from the
// full examples/snes/mandel-zoom.c (151 -> 51 lines raw; hand-cleaned + de-UB'd to 43 lines here).
// See docs/plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md (Verification) and
// docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md. Reproduce the reduction:
// dev/reduce-loopfold.sh reduce. Reproduce the bug from THIS file:
//
//   # loop form (this fold loop in zoom.h) MISCOMPILES; the byte-identical unrolled form does not.
//   mos-clang --config build/install/bin/mos-snes.cfg -mcpu=mosw65816 -Os \
//     -I<snes-loop> -I<h65816> -Wl,-Map=z.map -o z.sfc 2026-06-25-loopfold-min.c   # this .c, renamed
//   # then the ZOOM host==target differential (dev/reduce-loopfold.sh wraps this):
//   #   loop   -> ZOOM: FAIL ... host=0xF56C rom=0xE60E     (the miscompile)
//   #   unroll -> ZOOM: PASS ... zoom_crc=0xF56C            (the control)
//
// THE BUG (target=mosw65816, default-8bit, post-LTO): zoom_fold's `for (i<4) m[i]` matrix-fold loop
// (examples/snes/zoom.h) folds a WRONG m[] byte under this register pressure, so the rolling CRC
// diverges (rom 0xE60E vs the correct host/unrolled 0xF56C). The unrolled form (constant-offset m[]
// access) is correct. ROOT-CAUSE LEAD (confirmed by --lto-emit-asm diff, loop vs unroll): only the
// loop form sources m[i] via X-INDEXED stack loads
//     ldy  mos8(.Lmain_zp_stk+1),x        ; m[i] high byte
//     eor  mos8(.Lmain_zp_stk),x          ; m[i] low byte
// and then immediately reuses X as the inner CRC bit-counter (`ldx #8`). The unroll asm has NO
// `.Lmain_zp_stk,x` indexed loads. A wrong/stale X at the indexed load folds the wrong m[] byte.
//
// MINIMAL by ablation: removing ANY of the four pressure sources below — snes_ppu_reset_blank(), the
// inline palette REG_CGDATA loop, apply_zoom()'s REG_CGDATA loop, or the img_hash16 boot loop —
// makes the bug vanish (loop then matches unroll). That delicate simultaneity is why the earlier
// standalone-minimization attempts (see ../spikes/2026-06-25-default8-loopfold-miscompile-attempt.c)
// could not reproduce it. zoom.h is held FIXED across host and target so the differential isolates
// codegen; the reduction shrank only this pressure context.
#include "mandel.h"
#include "mode7.h"
#include "zoom.h"
volatile uint16_t level_hash[MANDEL_PYR_L];
volatile uint16_t zoom_crc;
volatile uint8_t nframes;
volatile uint8_t cur_level;
volatile uint16_t pad_log[64];
void apply_zoom(void) {
  for (uint8_t i = 0; i < MANDEL_NCOL; i++) {
    uint16_t c = MANDEL_PAL[i];
    REG_CGDATA = c;
  }
}
int main(void) {
  snes_ppu_reset_blank();
  zoom_t z;
  zoom_reset(&z);
  int16_t m[4];
  for (uint8_t i = 0; i < MANDEL_NCOL; i++) {
    uint16_t c = MANDEL_PAL[i];
    REG_CGDATA = c;
  }
  for (uint8_t k = 0; k < MANDEL_PYR_L; k++)
    level_hash[k] = img_hash16(MANDEL_PYR[k], MANDEL_PYR_W * MANDEL_PYR_H);
  uint16_t vc = 65535;
  uint8_t nf = 0;
  for (;;) {
    snes_wait_vblank();
    uint16_t pad = snes_read_pad1();
    if (zoom_step(&z, pad))
      cur_level = z.lvl;
    zoom_matrix(&z, m);
    apply_zoom();
    if (nf < 64) {
      pad_log[nf] = pad;
      vc = zoom_fold(vc, &z, m);
      nf++;
      zoom_crc = vc;
      nframes = nf;
    }
  }
}
