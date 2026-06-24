// png_write.h — minimal, dependency-free RGB8 PNG writer (header-only, C/C++).
//
// Emits a valid PNG using stored/uncompressed DEFLATE blocks + a hand-rolled
// CRC32/Adler32 — no -lz, no libpng. Used by tools/mandel-render.c (host render of
// the Mandelbrot) and dev/jgxcheck.cpp (dump bsnes-jg's rendered framebuffer).
//
//   png_write_rgb(path, rgb, w, h)  // rgb = w*h*3 bytes, row-major R,G,B
#ifndef PNG_WRITE_H
#define PNG_WRITE_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t pw__crc32(const uint8_t *p, size_t n, uint32_t crc) {
  crc = ~crc;
  for (size_t i = 0; i < n; i++) {
    crc ^= p[i];
    for (int k = 0; k < 8; k++)
      crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1)));
  }
  return ~crc;
}
static void pw__be32(FILE *f, uint32_t v) {
  fputc((v >> 24) & 0xFF, f); fputc((v >> 16) & 0xFF, f);
  fputc((v >> 8) & 0xFF, f);  fputc(v & 0xFF, f);
}
static void pw__chunk(FILE *f, const char *type, const uint8_t *data, uint32_t len) {
  pw__be32(f, len);
  fwrite(type, 1, 4, f);
  if (len) fwrite(data, 1, len, f);
  uint8_t *tmp = (uint8_t *)malloc((size_t)4 + len);
  memcpy(tmp, type, 4);
  if (len) memcpy(tmp + 4, data, len);
  pw__be32(f, pw__crc32(tmp, (size_t)4 + len, 0));
  free(tmp);
}
static uint32_t pw__adler32(const uint8_t *p, size_t n) {
  uint32_t a = 1, b = 0;
  for (size_t i = 0; i < n; i++) { a = (a + p[i]) % 65521; b = (b + a) % 65521; }
  return (b << 16) | a;
}

// Write w*h RGB (3 bytes/pixel, row-major) to a PNG. Returns 0 on success.
static int png_write_rgb(const char *path, const uint8_t *rgb, int w, int h) {
  FILE *f = fopen(path, "wb");
  if (!f) return -1;
  static const uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
  fwrite(sig, 1, 8, f);

  uint8_t ihdr[13];
  ihdr[0] = (uint8_t)(w >> 24); ihdr[1] = (uint8_t)(w >> 16); ihdr[2] = (uint8_t)(w >> 8); ihdr[3] = (uint8_t)w;
  ihdr[4] = (uint8_t)(h >> 24); ihdr[5] = (uint8_t)(h >> 16); ihdr[6] = (uint8_t)(h >> 8); ihdr[7] = (uint8_t)h;
  ihdr[8] = 8;   /* bit depth */
  ihdr[9] = 2;   /* color type RGB */
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  pw__chunk(f, "IHDR", ihdr, 13);

  size_t raw_len = (size_t)h * (1 + (size_t)w * 3);
  uint8_t *raw = (uint8_t *)malloc(raw_len);
  size_t o = 0;
  for (int y = 0; y < h; y++) {
    raw[o++] = 0;                                  /* filter: none */
    for (int x = 0; x < w; x++) {
      const uint8_t *px = rgb + ((size_t)y * w + x) * 3;
      raw[o++] = px[0]; raw[o++] = px[1]; raw[o++] = px[2];
    }
  }
  size_t zcap = 2 + raw_len + ((raw_len / 65535) + 1) * 5 + 4;
  uint8_t *z = (uint8_t *)malloc(zcap);
  size_t zo = 0;
  z[zo++] = 0x78; z[zo++] = 0x01;                  /* zlib header */
  size_t left = raw_len, pos = 0;
  while (left || raw_len == 0) {
    size_t blk = left > 65535 ? 65535 : left;
    int final = (blk == left);
    z[zo++] = (uint8_t)(final ? 1 : 0);            /* BFINAL, BTYPE=00 (stored) */
    z[zo++] = (uint8_t)(blk & 0xFF); z[zo++] = (uint8_t)((blk >> 8) & 0xFF);
    z[zo++] = (uint8_t)(~blk & 0xFF); z[zo++] = (uint8_t)((~blk >> 8) & 0xFF);
    if (blk) { memcpy(z + zo, raw + pos, blk); zo += blk; }
    pos += blk; left -= blk;
    if (raw_len == 0) break;
  }
  uint32_t ad = pw__adler32(raw, raw_len);
  z[zo++] = (uint8_t)(ad >> 24); z[zo++] = (uint8_t)(ad >> 16);
  z[zo++] = (uint8_t)(ad >> 8);  z[zo++] = (uint8_t)ad;
  pw__chunk(f, "IDAT", z, (uint32_t)zo);
  pw__chunk(f, "IEND", NULL, 0);

  free(z); free(raw);
  fclose(f);
  return 0;
}

#endif /* PNG_WRITE_H */
