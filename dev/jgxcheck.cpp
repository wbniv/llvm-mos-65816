// jgxcheck — headless bsnes-jg cross-check harness for the llvm-mos 65816 bench.
//
// Boots a .sfc, runs N frames, and reads SNES Main RAM (WRAM) directly via the
// Bsnes C++ API (getMemoryRaw), asserting LEN little-endian bytes at OFFSET ==
// WANT. No SDL / no X — links only the bsnes-jg core + libsamplerate. This is the
// independent-emulator fidelity cross-check mirroring the MAME smoke assert.
//
//   jgxcheck <rom.sfc> <datadir> <wram_offset_hex> <len> <want_hex> [frames]
// datadir holds the bsnes game database (boards.bml, SuperFamicom.bml, ...).
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <bsnes.hpp>
#include "png_write.h"   // dependency-free RGB8 PNG writer (shared with tools/mandel-render.c)

static std::vector<uint8_t> game;
static std::string gamepath, datapath;
static uint32_t *vbuf = nullptr;
static float inbuf[3200];

static void logCallback(void*, int level, std::string& t) {
  if (level) fprintf(stderr, "bsnes: %s\n", t.c_str());
}
static bool fileOpenS(void*, std::string name, std::stringstream& ss) {
  std::ifstream fs(datapath + "/" + name, std::ios::in | std::ios::binary);
  if (!fs.is_open()) { fprintf(stderr, "jgxcheck: missing data file %s\n", name.c_str()); return false; }
  ss << fs.rdbuf();
  return true;
}
static bool fileOpenV(void*, std::string, std::vector<uint8_t>&) { return false; }  // no save.ram/rtc
static bool fileOpenMsu(void*, std::string, std::istream**) { return false; }
static void fileWrite(void*, std::string, const uint8_t*, unsigned) {}             // discard SRAM writes
static bool loadRom(void*, unsigned id) {
  if (id == Bsnes::GameType::SuperFamicom && game.size() >= 0x8000) {
    Bsnes::setRomSuperFamicom(game, gamepath);
    return true;
  }
  return false;
}
// bsnes-jg renders each frame (in software) into our vbuf; PPU::refresh calls this
// as videoFrame(userptr, width, height, pitch) — the first arg is the user ptr (null
// here), NOT the pixels. The pixels are in vbuf, row-stride = pitch (in uint32 px).
// Record the geometry of the last presented frame so we can dump it to a PNG.
static unsigned g_w = 0, g_h = 0, g_pitch = 0;
static void videoFrame(const void*, unsigned width, unsigned height, unsigned pitch) {
  g_w = width; g_h = height; g_pitch = pitch;
}

// Dump the last rendered frame (vbuf) to a PNG. Pixel format is 0x00RRGGBB: the PPU
// lightTable output is `ab<<16|ag<<8|ar` indexed by (r<<10)|(g<<5)|b, and the SNES
// CGRAM word is BGR555 (R low), so the byte at bits 16-23 carries RED. bsnes outputs
// 512-wide (lores pixels doubled) x 240 (NTSC). With
// JGX_FULLFRAME=1, dump the raw native frame (512 x g_h, no crop/downsample) — useful
// for diagnosing crop/offset; otherwise downsample to the true 256 px and crop to the
// `rows` visible scanlines starting at JGX_YOFF (default 0).
static int dump_png(const char *path, int rows) {
  if (!g_pitch || !vbuf) { fprintf(stderr, "jgxcheck: no video frame to dump\n"); return 1; }
  bool full = getenv("JGX_FULLFRAME") != nullptr;
  int yoff = getenv("JGX_YOFF") ? atoi(getenv("JGX_YOFF")) : 0;
  int step = full ? 1 : 2;
  int out_w = (int)g_w / step;
  int out_h = full ? (int)g_h : rows;
  if (yoff + out_h > (int)g_h) out_h = (int)g_h - yoff;
  std::vector<uint8_t> rgb((size_t)out_w * out_h * 3);
  for (int y = 0; y < out_h; y++) {
    for (int x = 0; x < out_w; x++) {
      uint32_t px = vbuf[(size_t)(y + yoff) * g_pitch + (size_t)x * step];
      uint8_t *o = &rgb[((size_t)y * out_w + x) * 3];
      o[0] = (uint8_t)((px >> 16) & 0xFF);  // R
      o[1] = (uint8_t)((px >> 8) & 0xFF);   // G
      o[2] = (uint8_t)(px & 0xFF);          // B
    }
  }
  if (png_write_rgb(path, rgb.data(), out_w, out_h) != 0) {
    fprintf(stderr, "jgxcheck: PNG write failed: %s\n", path); return 1;
  }
  fprintf(stderr, "jgxcheck: wrote %s (%dx%d from native %ux%u, yoff=%d)\n",
          path, out_w, out_h, g_w, g_h, yoff);
  return 0;
}

// Debug: print a slice of VRAM as hex words (word addr WA, N words). VRAM from
// getMemoryRaw is byte-addressed; word w = lo | hi<<8.
static void dump_vram_hex(const char *label, unsigned wa, unsigned n) {
  std::pair<void*, unsigned> v = Bsnes::getMemoryRaw(Bsnes::Memory::VideoRAM);
  if (!v.first) { fprintf(stderr, "  (no VRAM)\n"); return; }
  const uint8_t *vram = (const uint8_t*)v.first;
  fprintf(stderr, "  %s @word $%04X:", label, wa);
  for (unsigned i = 0; i < n; i++) {
    unsigned b = (wa + i) * 2;
    if (b + 1 < v.second) fprintf(stderr, " %04X", vram[b] | (vram[b+1] << 8));
  }
  fprintf(stderr, "\n");
}
static void audioFrame(const void*, size_t) {}                                     // headless: discard
static int pollInput(const void*, unsigned, unsigned) { return 0; }

int main(int argc, char **argv) {
  if (argc < 6) {
    fprintf(stderr, "Usage: %s <rom.sfc> <datadir> <offset_hex> <len> <want_hex> [frames] [out.png]\n", argv[0]);
    return 2;
  }
  const char *rompath = argv[1];
  datapath = argv[2];
  unsigned off  = (unsigned)strtoul(argv[3], nullptr, 16);
  unsigned len  = (unsigned)strtoul(argv[4], nullptr, 0);
  unsigned want = (unsigned)strtoul(argv[5], nullptr, 16);
  int frames = argc > 6 ? atoi(argv[6]) : 120;
  const char *png_out = argc > 7 ? argv[7] : nullptr;
  if (len < 1) len = 1;

  std::ifstream fs(rompath, std::ios::in | std::ios::binary);
  if (!fs.is_open()) { fprintf(stderr, "jgxcheck: cannot open %s\n", rompath); return 2; }
  game = std::vector<uint8_t>((std::istreambuf_iterator<char>(fs)), std::istreambuf_iterator<char>());
  gamepath = rompath;

  vbuf = (uint32_t*)calloc(256 * (240 + 8) * 4, sizeof(uint32_t));

  Bsnes::setOpenFileCallback(nullptr, fileOpenV);
  Bsnes::setOpenStreamCallback(nullptr, fileOpenS);
  Bsnes::setOpenMsuCallback(nullptr, fileOpenMsu);
  Bsnes::setRomLoadCallback(nullptr, loadRom);
  Bsnes::setWriteCallback(nullptr, fileWrite);
  Bsnes::setLogCallback(nullptr, logCallback);
  Bsnes::setAudioSpec({48000.0, (48000 / 60) << 1, 0, inbuf, nullptr, &audioFrame});
  Bsnes::setVideoSpec({vbuf, nullptr, &videoFrame});

  if (!Bsnes::load()) { printf("SMOKE: FAIL (bsnes-jg load failed)\n"); return 1; }
  Bsnes::power();
  Bsnes::setInputSpec({0, Bsnes::Input::Device::Gamepad, nullptr, pollInput});
  Bsnes::setInputSpec({1, Bsnes::Input::Device::Gamepad, nullptr, pollInput});

  for (int i = 0; i < frames; ++i) Bsnes::run();

  if (png_out) dump_png(png_out, 224);
  if (getenv("JGX_VRAM")) {
    fprintf(stderr, "jgxcheck: VRAM dump --\n");
    dump_vram_hex("tile0..3 (word0)", 0x0000, 32);   // 16 words/tile; first 2 tiles
    dump_vram_hex("tilemap row0",     0x1000, 32);    // 32 entries (top screen row)
    dump_vram_hex("tilemap row13",    0x1000 + 13*32, 32);
  }

  std::pair<void*, unsigned> mem = Bsnes::getMemoryRaw(Bsnes::Memory::MainRAM);
  if (!mem.first || mem.second < off + len) { printf("SMOKE: FAIL (no MainRAM / out of range)\n"); return 1; }
  const uint8_t *wram = (const uint8_t*)mem.first;
  unsigned got = 0;
  for (unsigned i = 0; i < len; ++i) got |= (unsigned)wram[off + i] << (8 * i);

  if (got == want) {
    printf("SMOKE: PASS off=0x%X len=%u got=0x%0*X (ran %d frames, bsnes-jg)\n", off, len, 2 * len, got, frames);
    return 0;
  }
  printf("SMOKE: FAIL off=0x%X len=%u got=0x%0*X want=0x%0*X\n", off, len, 2 * len, got, 2 * len, want);
  return 1;
}
