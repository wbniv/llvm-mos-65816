/* Runtime-harness hook shared by dither_run.c, mvscrl_run.c and packrec_run.c.

   Each harness compiles a whole demo translation unit (examples/snes/<demo>.c) unchanged, with one
   substitution: display_frame's snes_wait_vblank() becomes harness_vblank(d), where d is
   display_frame's own Display* parameter (the first member of every demo's App). The hook
     - switches NMI and HDMA off, so no time-proportional interrupt or HDMA stall enters the region;
     - returns at once (no v-blank wait), so the demo's frame loop runs back to back and the measured
       master clocks are CPU work (plus the fixed-size, budgeted upload DMA, identical per variant);
     - once the demo's own state reaches the harness's end frame, folds the demo's WRAM output
       (algorithm state, canvas chr shadow, HUD text shadow, gate CRC) into one 16-bit value and
       writes it to corpus_result. The cycle probe stops on that write.
   The same source is the host oracle: tools/host-oracle.sh builds it with the host cc, with the
   SNES MMIO mapped onto a host array, and prints the fold instead of spinning.
   Include this before the demo source (it includes <snes.h> first so the SDK's own
   snes_wait_vblank definition is untouched; the macro only rewrites the later call site). */
#ifndef HARNESS_HOOK_H
#define HARNESS_HOOK_H
#include <snes.h>
#ifdef HARNESS_HOST
#include <stdio.h>
#include <stdlib.h>
#endif

void harness_vblank(void *d);
#define snes_wait_vblank() harness_vblank(d)

static uint16_t harness_h = 0x1D0Fu, harness_s = 0u;

/* Rotate-xor with a running sum: cheap on the 65816 (one-shot at the end frame), position-sensitive
   through the sum, and identical on the host. Not a CRC; it only has to expose any difference. */
static void harness_byte(uint8_t b) {
  harness_h = (uint16_t)((uint16_t)((harness_h << 3) | (harness_h >> 13)) ^ b);
  harness_s = (uint16_t)(harness_s + harness_h);
}
static void harness_bytes(const uint8_t *p, uint16_t n) {
  for (uint16_t i = 0; i < n; i++) harness_byte(p[i]);
}
static void harness_word(uint16_t w) {
  harness_byte((uint8_t)w);
  harness_byte((uint8_t)(w >> 8));
}
static void harness_words(const uint16_t *p, uint16_t n) {
  for (uint16_t i = 0; i < n; i++) harness_word(p[i]);
}
/* The value written to corpus_result; never equal to the demo's own gate write, so the probe
   cannot stop early on it. */
static uint16_t harness_result(uint16_t gate) {
  uint16_t r = (uint16_t)(harness_h ^ harness_s);
  if (r == gate) r = (uint16_t)(r ^ 0x5A5Au);
  return r;
}

#ifdef HARNESS_HOST
#define HARNESS_STOP(r) do { printf("0x%04X\n", (unsigned)(r)); exit(0); } while (0)
#else
#define HARNESS_STOP(r) do { for (;;) __asm__ volatile("wai"); } while (0)
#endif

#endif /* HARNESS_HOOK_H */
