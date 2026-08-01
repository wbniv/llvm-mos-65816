/* Freestanding result adapter for Csmith on the WDC 65816 / llvm-mos SNES target.
 *
 * Force-included BEFORE the generated TU:
 *   mos-clang ... -include .../csmith_snes.h -I vendor/csmith/include gen.c
 *
 * Csmith's generated main() ends with platform_main_end(crc32_context ^ 0xFFFFFFFF, flag).
 * The default runtime (random_inc.h -> platform_generic.h) reports that checksum via printf
 * and pulls in <stdio.h> — neither exists on the freestanding SNES. We instead SUPPRESS the
 * vendored platform_generic.h (by pre-defining its include guard) and supply our own no-stdio
 * platform_main_end that writes the 16-bit-folded checksum into `corpus_result`, the volatile
 * WRAM cell the MAME/bsnes-jg harness reads back. We keep the default <stdint.h> path (16-bit
 * int -> int16_t=int, int32_t=long, matching the target) and Csmith's type-parametric safe_math
 * wrappers, so — paired with examples/65816/csmith/platform.info (integer size = 2) — the
 * generated program is UB-free AT THE TARGET'S 16-bit width. That is what makes the
 * default-build-as-oracle differential (default == +mos-a16 == +mos-xy16) sound.
 * See docs/plans/2026-06-19-321-csmith-differential-fuzzer.md.
 */
#ifndef CSMITH_SNES_H
#define CSMITH_SNES_H

#include <stdint.h>

volatile unsigned short corpus_result;

/* Suppress vendor platform_generic.h (random_inc.h includes it on the non-AVR/MSP430 path)
 * and replace everything it would have provided: the two hooks, <stdio.h>, and MB. */
#define PLATFORM_GENERIC_H
#define MB (1 << 20)
#define printf(...)  ((void)0)
#define fprintf(...) ((void)0)

static void platform_main_begin(void) { }

static void platform_main_end(uint32_t crc, int flag) {
  (void)flag;
  corpus_result = (unsigned short)(crc ^ (crc >> 16)); /* 16-bit fold of the 32-bit CRC */
  for (;;) __asm__ volatile("wai");                                         /* halt; harness samples corpus_result */
}

#endif /* CSMITH_SNES_H */
