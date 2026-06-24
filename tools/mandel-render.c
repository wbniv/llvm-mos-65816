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

// ---- escape-count -> RGB palette (integer, so Track 2 can mirror it into CGRAM) ----
static void palette(uint8_t n, uint8_t maxiter, uint8_t *r, uint8_t *g, uint8_t *b) {
  if (n >= maxiter) { *r = *g = *b = 0; return; }          // interior: black
  unsigned t = (unsigned)n * 255u / (maxiter ? maxiter : 1);
  *r = (uint8_t)t;                                          // 0 -> high : dark -> bright
  *g = (uint8_t)((t < 128) ? (t * 2) : 255);
  *b = (uint8_t)(255 - t);                                  // blue low -> yellow/white high
}

// ---- minimal PNG (RGB8, stored DEFLATE) --------------------------------------------
static uint32_t crc32_buf(const uint8_t *p, size_t n, uint32_t crc) {
  crc = ~crc;
  for (size_t i = 0; i < n; i++) {
    crc ^= p[i];
    for (int k = 0; k < 8; k++)
      crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1)));
  }
  return ~crc;
}
static void put_be32(FILE *f, uint32_t v) {
  fputc((v >> 24) & 0xFF, f); fputc((v >> 16) & 0xFF, f);
  fputc((v >> 8) & 0xFF, f);  fputc(v & 0xFF, f);
}
// Write one PNG chunk (type + data) with its CRC32 (computed over type+data as one
// stream — the PNG spec's chunk CRC).
static void put_chunk(FILE *f, const char *type, const uint8_t *data, uint32_t len) {
  put_be32(f, len);
  fwrite(type, 1, 4, f);
  if (len) fwrite(data, 1, len, f);
  uint8_t *tmp = (uint8_t *)malloc((size_t)4 + len);
  memcpy(tmp, type, 4);
  if (len) memcpy(tmp + 4, data, len);
  put_be32(f, crc32_buf(tmp, (size_t)4 + len, 0));
  free(tmp);
}
static uint32_t adler32_buf(const uint8_t *p, size_t n) {
  uint32_t a = 1, b = 0;
  for (size_t i = 0; i < n; i++) { a = (a + p[i]) % 65521; b = (b + a) % 65521; }
  return (b << 16) | a;
}
static int write_png(const char *path, const uint8_t *rgb, int w, int h) {
  FILE *f = fopen(path, "wb");
  if (!f) return -1;
  static const uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
  fwrite(sig, 1, 8, f);

  uint8_t ihdr[13];
  ihdr[0] = (w >> 24) & 0xFF; ihdr[1] = (w >> 16) & 0xFF; ihdr[2] = (w >> 8) & 0xFF; ihdr[3] = w & 0xFF;
  ihdr[4] = (h >> 24) & 0xFF; ihdr[5] = (h >> 16) & 0xFF; ihdr[6] = (h >> 8) & 0xFF; ihdr[7] = h & 0xFF;
  ihdr[8] = 8;    // bit depth
  ihdr[9] = 2;    // color type RGB
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  put_chunk(f, "IHDR", ihdr, 13);

  // Raw image: each row = filter byte 0 + w*3 RGB bytes.
  size_t raw_len = (size_t)h * (1 + (size_t)w * 3);
  uint8_t *raw = (uint8_t *)malloc(raw_len);
  size_t o = 0;
  for (int y = 0; y < h; y++) {
    raw[o++] = 0;                                  // filter: none
    for (int x = 0; x < w; x++) {
      const uint8_t *px = rgb + ((size_t)y * w + x) * 3;
      raw[o++] = px[0]; raw[o++] = px[1]; raw[o++] = px[2];
    }
  }
  // zlib stream: header + stored DEFLATE blocks (<=65535 each) + adler32.
  size_t zcap = 2 + raw_len + ((raw_len / 65535) + 1) * 5 + 4;
  uint8_t *z = (uint8_t *)malloc(zcap);
  size_t zo = 0;
  z[zo++] = 0x78; z[zo++] = 0x01;                  // CMF, FLG
  size_t left = raw_len, pos = 0;
  while (left || raw_len == 0) {
    size_t blk = left > 65535 ? 65535 : left;
    int final = (blk == left);
    z[zo++] = final ? 1 : 0;                        // BFINAL, BTYPE=00 (stored)
    z[zo++] = blk & 0xFF; z[zo++] = (blk >> 8) & 0xFF;
    z[zo++] = (~blk) & 0xFF; z[zo++] = ((~blk) >> 8) & 0xFF;
    if (blk) { memcpy(z + zo, raw + pos, blk); zo += blk; }
    pos += blk; left -= blk;
    if (raw_len == 0) break;
  }
  uint32_t ad = adler32_buf(raw, raw_len);
  z[zo++] = (ad >> 24) & 0xFF; z[zo++] = (ad >> 16) & 0xFF;
  z[zo++] = (ad >> 8) & 0xFF;  z[zo++] = ad & 0xFF;
  put_chunk(f, "IDAT", z, (uint32_t)zo);
  put_chunk(f, "IEND", NULL, 0);

  free(z); free(raw);
  fclose(f);
  return 0;
}

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

  if (write_png(out, rgb, W, H) != 0) { fprintf(stderr, "write %s failed\n", out); return 1; }
  uint16_t crc = mandel_crc(fb, (uint16_t)(W * H));   /* note: W*H may exceed 16-bit; host-only */
  printf("wrote %s  (%dx%d N=%d)  full-grid CRC16=0x%04X\n", out, W, H, N, crc);
  free(rgb); free(fb);
  return 0;
}
