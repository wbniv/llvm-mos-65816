// Host-side renderer + gate-value oracle for the #321 fixed-point Mandelbrot demo.
//
// Two modes:
//   mandel-render --gate              compute the CRC16 over the GATE grid (the exact
//                                     GATE_W/GATE_H/GATE_N that examples/65816/k_mandel.c
//                                     uses) and print it. This is the INDEPENDENT host
//                                     reference baked as dev/k_mandel.sh's --expected.
//   mandel-render [out.png] [W H N]   render the full-resolution image to a PNG
//                                     (default build/mandel.png at 96x64, N=32).
//
// The escape math comes from examples/65816/mandel.h — the SAME code the SNES target
// compiles — so the host CRC is a true cross-platform oracle, not a re-derivation.
//
// Build (host): cc -O2 -I examples/65816 tools/mandel-render.c -o build/mandel-render
// (no -lz: the PNG is emitted with stored/uncompressed DEFLATE blocks + a hand-rolled
//  CRC32/Adler32, so the tool is dependency-free and reproducible.)
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mandel.h"

// Must match examples/65816/k_mandel.c exactly (the gate slice).
#define GATE_W 16
#define GATE_H 10
#define GATE_N 12

// ---- escape-count -> RGB palette: the shared 5-bit ramp (mandel.h) scaled 5->8 bit,
// so the host PNG matches the on-console CGRAM colours exactly. ----
static void palette(uint8_t n, uint8_t maxiter, uint8_t *r, uint8_t *g, uint8_t *b) {
  uint8_t r5, g5, b5;
  mandel_palette(n, maxiter, &r5, &g5, &b5);
  *r = (uint8_t)(r5 << 3); *g = (uint8_t)(g5 << 3); *b = (uint8_t)(b5 << 3);
}

// PNG output: shared, dependency-free encoder.
#include "png_write.h"

int main(int argc, char **argv) {
  if (argc >= 2 && strcmp(argv[1], "--gate") == 0) {
    uint8_t fb[GATE_W * GATE_H];
    mandel_fill(fb, GATE_W, GATE_H, GATE_N);
    uint16_t crc = mandel_crc(fb, (uint16_t)(GATE_W * GATE_H));
    printf("gate %dx%d N=%d  CRC16=0x%04X\n", GATE_W, GATE_H, GATE_N, crc);
    return 0;
  }

  const char *out = (argc >= 2) ? argv[1] : "build/mandel.png";
  int W = (argc >= 4) ? atoi(argv[2]) : 96;
  int H = (argc >= 4) ? atoi(argv[3]) : 64;
  int N = (argc >= 5) ? atoi(argv[4]) : 32;
  if (W < 1 || H < 1 || N < 1 || N > 255) { fprintf(stderr, "bad W/H/N\n"); return 2; }
  // The shared kernel API (mandel.h) takes uint8_t w/h for the tiny SNES gate grid,
  // so a host render wider/taller than 255 would wrap to 0 and silently produce a
  // blank image. Fail loudly instead. (Widen mandel_fill's w/h to uint16_t in Track 2
  // when the on-console compare wants a full 256x224 host reference.)
  if (W > 255 || H > 255) {
    fprintf(stderr, "W/H must be <= 255 (kernel API is uint8_t); got %dx%d\n", W, H);
    return 2;
  }

  uint8_t *fb = (uint8_t *)malloc((size_t)W * H);
  mandel_fill(fb, (uint8_t)W, (uint8_t)H, (uint8_t)N);

  uint8_t *rgb = (uint8_t *)malloc((size_t)W * H * 3);
  for (int p = 0; p < W * H; p++)
    palette(fb[p], (uint8_t)N, &rgb[p * 3], &rgb[p * 3 + 1], &rgb[p * 3 + 2]);

  if (png_write_rgb(out, rgb, W, H) != 0) { fprintf(stderr, "write %s failed\n", out); return 1; }
  uint16_t crc = mandel_crc(fb, (uint16_t)(W * H));   /* note: W*H may exceed 16-bit; host-only */
  printf("wrote %s  (%dx%d N=%d)  full-grid CRC16=0x%04X\n", out, W, H, N, crc);
  free(rgb); free(fb);
  return 0;
}
