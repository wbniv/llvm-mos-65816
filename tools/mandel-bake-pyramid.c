// Host-side "bake" tool for the interactive SNES Mandelbrot ZOOM PYRAMID (#321 M2).
//
// Computes a STACK of L Mandelbrot images, each at 2x finer zoom than the last, all centered on
// one iconic deep-zoom point, and bakes them into a generated C header (examples/snes/
// pyramid_image.h). On the SNES, Mode 7 hardware-zooms the current level; when zoom crosses a 2x
// threshold the ROM DMAs the next (finer) level and resets the Mode 7 scale — so zooming dives
// into GENUINELY NEW fractal structure (not just magnified pixels), INSTANTLY (a DMA swap), with
// the SNES doing ZERO fractal math. See docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md.
//
// Why host-baked (ruled out on-console by measurement, Lesson 1):
//   * Speed — a 128x128 escape buffer is ~4 min of emulated compute; a multi-second stall per
//     zoom step is not real-time.
//   * Precision — the on-console kernel is Q5.10; a few zoom levels in, adjacent pixels are
//     < 1/1024 apart and the fixed-point math runs out of bits. The SNES simply CANNOT compute
//     deep detail. The host renders in `double` (this file), arbitrarily deep.
//
// The on-target +mos-a16 codegen this demo exercises is NOT the fractal (baked) but the per-frame
// view->matrix math + the level-swap threshold arithmetic in examples/snes/zoom.h, gated by a
// host==target differential (the ROM folds (lvl, scale, matrix) into a rolling CRC; the host
// replays zoom.h over the ROM's ground-truth pad log).
//
// Emits pyramid_image.h:
//   * MANDEL_PYR_L / _W / _H / MANDEL_NCOL          dimensions
//   * SINCOS[256]                                    8.8 sine, drives the Mode 7 rotate/zoom matrix
//   * MANDEL_PAL[NCOL]                               ONE shared BGR555 palette (normalized indices)
//   * LEVEL_0[..] .. LEVEL_{L-1}[..]                 each WxH tiled into Mode 7 character order
//   * MANDEL_PYR[L]                                  near pointer table -> each level (DMA source)
//   * MANDEL_PYR_HASH[L]                             per-level host-reference img_hash16 (gate value)
// + a host PNG per level (4x nearest-neighbour) for the increasing-detail montage.
//
// Normalized palette indices, one shared palette: each level's iteration cap N_k differs (deeper
// boundaries need more iterations), so the bake stores chr bytes as a palette INDEX 0..NCOL-1
// (interior -> 0/black, escape n -> 1 + n*(NCOL-2)/(N_k-1)), letting ALL levels share one
// MANDEL_PAL in CGRAM regardless of N_k. (The interactive demo stored raw escape counts; the
// pyramid normalizes so the palette is level-independent.)
//
// Build (host): cc -O2 -I examples/65816 tools/mandel-bake-pyramid.c -o build/mandel-bake-pyramid -lm
// Usage: mandel-bake-pyramid <out.h> [W H L NCOL] [png_prefix]
//   defaults: 64 64 6 32   (Phase 1: 64x64 x 6 levels = 32x deep, fits one 32 KiB LoROM bank)
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "mandel.h"      // shared: mandel_palette (colour ramp), img_hash16 (gate hash) — -I examples/65816
#include "png_write.h"   // dependency-free RGB8 PNG writer (-I tools)

// --- The deep-zoom target. One iconic point every level homes on; level k covers complex window
// width W0/2^k centered here. We home on the prominent MINI-MANDELBROT on the negative-real-axis
// antenna (c ~= -1.7548776662): across Phase 1's shallow 32x range it gives the clearest
// "increasing detail" story — level 0 is the whole set, the dive runs down the needle past the
// period bulbs, and the deepest level resolves a complete tiny copy of the set (a striking,
// universally legible payoff that the seahorse-valley spirals only reveal at much deeper zoom than
// 6 levels reach). cim = 0 makes the image cleanly top-bottom symmetric. Finalized from the host
// PNG montage (Lesson 1: measure, don't assume — several centres were rendered and compared).
// Overridable at bake time via env PYR_CRE / PYR_CIM / PYR_W0 (used to tune the target). ---
#define CRE_DEFAULT  (-1.7548776662)  // real part of the centre (real-axis mini-Mandelbrot)
#define CIM_DEFAULT  ( 0.0)           // imag part of the centre (on the axis of symmetry)
#define W0_DEFAULT    3.0             // level-0 complex window width (~the whole set at 2x SNES zoom)

static double env_d(const char *name, double dflt) {
  const char *s = getenv(name);
  return (s && *s) ? atof(s) : dflt;
}

// Per-level iteration cap: deeper levels need more iterations to resolve the boundary. Free (host
// compute only). N_k = N_BASE + k*N_STEP.
#define N_BASE 64
#define N_STEP 48

// Escape count for one cell at host `double` precision (the on-target Q5.10 kernel is NOT used
// here — the pyramid is entirely host-computed). |z|^2 > 4 escapes.
static int escape_double(double cr, double ci, int maxiter) {
  double zr = 0.0, zi = 0.0;
  int n;
  for (n = 0; n < maxiter; n++) {
    double zr2 = zr * zr, zi2 = zi * zi;
    if (zr2 + zi2 > 4.0) break;
    double t = zr2 - zi2 + cr;
    zi = 2.0 * zr * zi + ci;
    zr = t;
  }
  return n;
}

// Normalize an escape count to a shared-palette index 0..NCOL-1: interior (n>=N_k) -> 0 (black);
// escape n -> 1 + n*(NCOL-2)/(N_k-1), clamped to [1, NCOL-1]. Level-independent: a fast escape is
// always index 1, a slow escape always near NCOL-1, whatever N_k is.
static uint8_t pal_index(int n, int Nk, int NCOL) {
  if (n >= Nk) return 0;
  long idx = 1 + (long)n * (NCOL - 2) / (Nk > 1 ? Nk - 1 : 1);
  if (idx < 1) idx = 1;
  if (idx > NCOL - 1) idx = NCOL - 1;
  return (uint8_t)idx;
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: %s <out.h> [W H L NCOL] [png_prefix]\n", argv[0]); return 2; }
  const char *out = argv[1];
  int W    = (argc >= 6) ? atoi(argv[2]) : 64;
  int H    = (argc >= 6) ? atoi(argv[3]) : 64;
  int L    = (argc >= 6) ? atoi(argv[4]) : 6;
  int NCOL = (argc >= 6) ? atoi(argv[5]) : 32;
  const char *png_prefix = (argc >= 7) ? argv[6] : NULL;
  double cre = env_d("PYR_CRE", CRE_DEFAULT);
  double cim = env_d("PYR_CIM", CIM_DEFAULT);
  double w0  = env_d("PYR_W0",  W0_DEFAULT);
  // Multi-bank (Phase 2): tag LEVEL_k (k>=1) into a per-level bank section (.rodata_levelK -> bank k
  // on the snes-zoom platform) + emit MANDEL_PYR_BANK[k]=k, so each 128x128 level lives in its own
  // ROM bank and the runtime DMAs it from (bank k : $8000). Single-bank (default, Phase 1): all
  // levels are near in bank 0 and MANDEL_PYR_BANK[]=0. Set PYR_MULTIBANK=1 to enable.
  int multibank = getenv("PYR_MULTIBANK") && atoi(getenv("PYR_MULTIBANK"));

  // Mode 7 character data is linear 8bpp with a 256-tile cap, and a palette index must fit a byte.
  if (W < 8 || H < 8 || (W % 8) || (H % 8)) { fprintf(stderr, "W,H must be multiples of 8 (>=8)\n"); return 2; }
  if ((W / 8) * (H / 8) > 256) { fprintf(stderr, "W*H exceeds the Mode 7 256-tile cap\n"); return 2; }
  if (L < 1 || L > 64) { fprintf(stderr, "L must be 1..64\n"); return 2; }
  if (NCOL < 3 || NCOL > 256) { fprintf(stderr, "NCOL must be 3..256 (8bpp palette)\n"); return 2; }
  // Multi-bank uses one bank per level k>=1 (.rodata_level1..7 -> banks $01..$07 on snes-zoom), so
  // L-1 far levels must fit the 7 far banks => L <= 8.
  if (multibank && L > 8) { fprintf(stderr, "PYR_MULTIBANK supports L<=8 (snes-zoom has banks $00..$07)\n"); return 2; }

  int tw = W / 8, th = H / 8;     // tiles per row / column
  size_t npix = (size_t)W * H;
  uint8_t *idx = malloc(npix);    // per-pixel palette index (raster order)
  uint8_t *chr = malloc(npix);    // tiled into Mode 7 character order
  uint16_t *hash = malloc((size_t)L * sizeof(uint16_t));
  if (!idx || !chr || !hash) { fprintf(stderr, "oom\n"); return 1; }

  FILE *f = fopen(out, "w");
  if (!f) { fprintf(stderr, "cannot write %s\n", out); return 1; }

  fprintf(f,
    "// AUTO-GENERATED by tools/mandel-bake-pyramid.c — DO NOT EDIT.\n"
    "// Regenerated by dev/mandel-zoom.sh / dev/build.sh. A %dx%d Mandelbrot ZOOM PYRAMID: %d levels,\n"
    "// each 2x finer zoom centered on (%.6f, %.6f), tiled into Mode 7 character order and baked\n"
    "// into ROM for the instant-boot interactive zoom demo (examples/snes/mandel-zoom.c).\n"
    "//\n"
    "// Host includers that only need the tables (SINCOS, hashes, dimensions) can #define\n"
    "// PYRAMID_NO_IMG before including this header to skip the per-level character arrays.\n"
    "#ifndef PYRAMID_IMAGE_H\n"
    "#define PYRAMID_IMAGE_H\n"
    "#include <stdint.h>\n\n"
    "#define MANDEL_PYR_L   %d\n"
    "#define MANDEL_PYR_W   %d\n"
    "#define MANDEL_PYR_H   %d\n"
    "#define MANDEL_NCOL    %d\n"
    "#define MANDEL_PYR_MULTIBANK %d   // 1 = levels 1.. in their own ROM banks (snes-zoom); 0 = single bank\n\n",
    W, H, L, cre, cim, L, W, H, NCOL, multibank);

  // SINCOS: 8.8 signed sine, full circle = 256 entries. cos(a) = SINCOS[(a+64)&255]. Drives the
  // per-frame Mode 7 rotate/zoom matrix (zoom.h). Emitted first so PYRAMID_NO_IMG includers get it.
  fprintf(f, "// 8.8 signed sine, 256 steps/circle; cos(a) = SINCOS[(a+64)&255].\n");
  fprintf(f, "static const int16_t SINCOS[256] = {\n  ");
  for (int a = 0; a < 256; a++) {
    int v = (int)lround(256.0 * sin(2.0 * M_PI * (double)a / 256.0));
    fprintf(f, "%d,%s", v, ((a & 15) == 15) ? "\n  " : " ");
  }
  fprintf(f, "\n};\n\n");

  // ONE shared BGR555 palette: index 0 = interior (black); 1..NCOL-1 = the escape gradient (the
  // same blue->yellow ramp as mandel_palette, so the pyramid matches the other demos' look).
  fprintf(f, "// Shared BGR555 CGRAM palette (normalized indices): 0 = interior (black),\n");
  fprintf(f, "// 1..%d = escape gradient. ALL levels index into this one palette.\n", NCOL - 1);
  fprintf(f, "static const uint16_t MANDEL_PAL[MANDEL_NCOL] = {\n  ");
  for (int i = 0; i < NCOL; i++) {
    uint16_t c;
    if (i == 0) {
      c = 0;   // interior — black
    } else {
      uint8_t r5, g5, b5;
      mandel_palette((uint8_t)(i - 1), (uint8_t)(NCOL - 1), &r5, &g5, &b5);   // escape ramp 0..NCOL-2
      c = (uint16_t)(((b5 & 0x1F) << 10) | ((g5 & 0x1F) << 5) | (r5 & 0x1F)); // SNES_RGB
    }
    fprintf(f, "0x%04X,%s", c, ((i & 7) == 7) ? "\n  " : " ");
  }
  fprintf(f, "\n};\n\n");

  fprintf(f, "#ifndef PYRAMID_NO_IMG\n");

  // Each level: render at `double` precision, normalize to palette indices, tile into Mode 7
  // character order, emit the array + its reference hash.
  for (int k = 0; k < L; k++) {
    int Nk = N_BASE + k * N_STEP;
    double w_k = w0 / pow(2.0, (double)k);   // complex window width at level k (2x finer each step)

    for (int py = 0; py < H; py++) {
      double ci = cim + (((double)py + 0.5) / (double)H - 0.5) * w_k;
      for (int px = 0; px < W; px++) {
        double cr = cre + (((double)px + 0.5) / (double)W - 0.5) * w_k;
        idx[(size_t)py * W + px] = pal_index(escape_double(cr, ci, Nk), Nk, NCOL);
      }
    }

    // Raster -> Mode 7 character order: tile t = trow*tw + tcol holds the 8x8 block at
    // (tcol*8, trow*8); chr[t*64 + r*8 + c] = idx[(trow*8+r)*W + (tcol*8+c)].
    for (int t = 0; t < tw * th; t++) {
      int trow = t / tw, tcol = t % tw;
      for (int r = 0; r < 8; r++)
        for (int c = 0; c < 8; c++)
          chr[(size_t)t * 64 + r * 8 + c] = idx[(size_t)(trow * 8 + r) * W + (tcol * 8 + c)];
    }

    hash[k] = img_hash16(chr, (uint16_t)npix);

    fprintf(f, "// Level %d: window width %.6g (2^%d x deeper than level 0), N=%d, hash 0x%04X.\n",
            k, w_k, k, Nk, hash[k]);
    // Multi-bank: levels 1.. go to a per-level section (.rodata_levelK -> bank k on snes-zoom);
    // level 0 stays in .rodata (bank 0, so it is near-readable for the on-console boot hash).
    if (multibank && k >= 1)
      fprintf(f, "__attribute__((section(\".rodata_level%d\")))\n", k);
    fprintf(f, "static const uint8_t LEVEL_%d[MANDEL_PYR_W * MANDEL_PYR_H] = {\n  ", k);
    for (size_t p = 0; p < npix; p++)
      fprintf(f, "%u,%s", chr[p], ((p & 31) == 31) ? "\n  " : " ");
    fprintf(f, "\n};\n\n");

    // Per-level PNG (4x nearest-neighbour) for the increasing-detail montage. Reads the RASTER
    // index buffer (idx), maps through the palette to RGB888 (BGR555 channels << 3).
    if (png_prefix) {
      int scale = 4, ow = W * scale, oh = H * scale;
      uint8_t *rgb = malloc((size_t)ow * oh * 3);
      if (rgb) {
        for (int y = 0; y < oh; y++)
          for (int x = 0; x < ow; x++) {
            uint8_t pi = idx[(size_t)(y / scale) * W + (x / scale)];
            uint16_t c;
            if (pi == 0) c = 0;
            else { uint8_t r5, g5, b5; mandel_palette((uint8_t)(pi - 1), (uint8_t)(NCOL - 1), &r5, &g5, &b5);
                   c = (uint16_t)(((b5 & 0x1F) << 10) | ((g5 & 0x1F) << 5) | (r5 & 0x1F)); }
            uint8_t *o = &rgb[((size_t)y * ow + x) * 3];
            o[0] = (uint8_t)((c & 0x1F) << 3);          // R (bits 0-4)
            o[1] = (uint8_t)(((c >> 5) & 0x1F) << 3);   // G (bits 5-9)
            o[2] = (uint8_t)(((c >> 10) & 0x1F) << 3);  // B (bits 10-14)
          }
        char path[1024];
        snprintf(path, sizeof path, "%s-level%02d.png", png_prefix, k);
        png_write_rgb(path, rgb, ow, oh);
        free(rgb);
      }
    }
  }

  // DMA-source ADDRESS table: a NEAR pointer per level. `(uint16_t)MANDEL_PYR[lvl]` is the DMA
  // addr16 (the symbol's low 16 bits — for a bank-placed level that is its in-bank $8000 offset).
  // Works in BOTH the default and +mos-a16 builds (a 16-bit pointer; no far deref). Multi-bank
  // levels 1.. live in higher banks, so these pointers are NOT dereferenceable on-console for k>=1
  // (they would read bank $00) — they are used ONLY as the DMA addr16, paired with MANDEL_PYR_BANK.
  fprintf(f, "// DMA-source addr16 table: (uint16_t)MANDEL_PYR[lvl] -> level lvl's in-bank chr address.\n");
  fprintf(f, "static const uint8_t *const MANDEL_PYR[MANDEL_PYR_L] = {\n  ");
  for (int k = 0; k < L; k++) fprintf(f, "LEVEL_%d,%s", k, ((k & 7) == 7) ? "\n  " : " ");
  fprintf(f, "\n};\n");

  // DMA-source BANK table: the A-bus bank byte (A1B0) for each level. Multi-bank: level k -> bank k.
  // Single-bank: all 0 (every level in bank $00). The runtime DMAs from (MANDEL_PYR_BANK[lvl] :
  // (uint16_t)MANDEL_PYR[lvl]) — uniform across both modes.
  fprintf(f, "// DMA-source bank table: MANDEL_PYR_BANK[lvl] -> the ROM bank holding level lvl's chr.\n");
  fprintf(f, "static const uint8_t MANDEL_PYR_BANK[MANDEL_PYR_L] = {\n  ");
  for (int k = 0; k < L; k++) fprintf(f, "0x%02X,%s", multibank ? k : 0, ((k & 7) == 7) ? "\n  " : " ");
  fprintf(f, "\n};\n");

  fprintf(f, "#endif /* PYRAMID_NO_IMG */\n\n");

  // Per-level reference hashes (the gate values) — outside PYRAMID_NO_IMG so the host verifier gets
  // them without the level arrays.
  fprintf(f, "// Per-level host-reference img_hash16 (the differential gate value per level).\n");
  fprintf(f, "static const uint16_t MANDEL_PYR_HASH[MANDEL_PYR_L] = {\n  ");
  for (int k = 0; k < L; k++) fprintf(f, "0x%04X,%s", hash[k], ((k & 7) == 7) ? "\n  " : " ");
  fprintf(f, "\n};\n");

  fprintf(f, "\n#endif /* PYRAMID_IMAGE_H */\n");
  fclose(f);

  printf("baked %s  %dx%d  L=%d NCOL=%d  centre=(%.6f,%.6f) W0=%.3f\n",
         out, W, H, L, NCOL, cre, cim, w0);
  for (int k = 0; k < L; k++)
    printf("  level %d: N=%d width=%.6g hash=0x%04X\n", k, N_BASE + k * N_STEP, w0 / pow(2.0, k), hash[k]);
  free(idx); free(chr); free(hash);
  return 0;
}
