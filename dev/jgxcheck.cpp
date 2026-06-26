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

#ifdef JGX_VIEW
// Interactive-demo input differential (built only by dev/mandel-interactive.sh
// as a separate `jgxcheck-view` binary, so the plain jgxcheck used by other
// scripts is unaffected). Drive a scripted controller sequence into pollInput, then replay the
// SHARED pure view math (examples/snes/view.h) over the ROM's ground-truth pad log and
// assert an identical rolling CRC. The NO_IMG guards keep the baked image arrays out of this host
// TU (we only need the SINCOS table + the per-level reference hashes).
#ifdef JGX_VIEW
#define MANDEL_IMAGE_NO_IMG
#include "view.h"
#endif

static std::vector<uint16_t> g_script;   // per-frame button mask (frame -> JOY_* bits)
static unsigned g_frame = 0;

// Parse "RIGHT:24,R:24,A:24,..." into g_script (one button per segment, held for N frames).
static void parseScript(const char *s) {
  struct { const char *n; uint16_t m; } BTN[] = {
    {"B", JOY_B}, {"Y", JOY_Y}, {"SELECT", JOY_SELECT}, {"START", JOY_START},
    {"UP", JOY_UP}, {"DOWN", JOY_DOWN}, {"LEFT", JOY_LEFT}, {"RIGHT", JOY_RIGHT},
    {"A", JOY_A}, {"X", JOY_X}, {"L", JOY_L}, {"R", JOY_R}, {"NONE", 0},
  };
  std::string str(s);
  size_t i = 0;
  while (i < str.size()) {
    size_t comma = str.find(',', i);
    std::string seg = str.substr(i, comma == std::string::npos ? std::string::npos : comma - i);
    i = (comma == std::string::npos) ? str.size() : comma + 1;
    size_t colon = seg.find(':');
    if (colon == std::string::npos) continue;
    std::string name = seg.substr(0, colon);
    int cnt = atoi(seg.c_str() + colon + 1);
    uint16_t mask = 0;
    for (auto &b : BTN) if (name == b.n) { mask = b.m; break; }
    for (int k = 0; k < cnt; k++) g_script.push_back(mask);
  }
}
#endif

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
#ifdef JGX_VIEW
// bsnes calls poll(udata, port, 0) on the controller latch and uses the full 16-bit return as
// the button word (B in bit15 … R in bit4 — the JOY_* layout). Return the scripted mask for the
// current frame; held past the script end. Exact frame alignment is irrelevant: the differential
// replays the ROM's ground-truth pad log, not this script (this only has to make input non-trivial).
static int pollInput(const void*, unsigned port, unsigned /*id*/) {
  if (port != 0 || g_script.empty()) return 0;
  unsigned f = (g_frame < g_script.size()) ? g_frame : (unsigned)(g_script.size() - 1);
  return (int)g_script[f];
}
#else
static int pollInput(const void*, unsigned, unsigned) { return 0; }
#endif

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

#ifdef JGX_VIEW
  if (getenv("JGX_SCRIPT")) parseScript(getenv("JGX_SCRIPT"));
#endif

  for (int i = 0; i < frames; ++i) {
    Bsnes::run();
#ifdef JGX_VIEW
    g_frame++;
#endif
  }

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

  int rc = 0;
  if (got == want) {
    printf("SMOKE: PASS off=0x%X len=%u got=0x%0*X (ran %d frames, bsnes-jg)\n", off, len, 2 * len, got, frames);
  } else {
    printf("SMOKE: FAIL off=0x%X len=%u got=0x%0*X want=0x%0*X\n", off, len, 2 * len, got, 2 * len, want);
    rc = 1;
  }

#ifdef JGX_VIEW
  // Input differential: replay view.h over the ROM's ground-truth pad log; assert host == ROM.
  if (getenv("JGX_SCRIPT") && getenv("JGX_VIEWCRC") && getenv("JGX_PADLOG") && getenv("JGX_NFRAMES")) {
    unsigned padlog_off = (unsigned)strtoul(getenv("JGX_PADLOG"), nullptr, 16);
    unsigned vc_off     = (unsigned)strtoul(getenv("JGX_VIEWCRC"), nullptr, 16);
    unsigned nf_off     = (unsigned)strtoul(getenv("JGX_NFRAMES"), nullptr, 16);
    unsigned padlog_n   = getenv("JGX_PADLOG_N") ? (unsigned)atoi(getenv("JGX_PADLOG_N")) : 64;
    if (nf_off < mem.second && vc_off + 1 < mem.second) {
      unsigned nf = wram[nf_off];
      if (nf > padlog_n) nf = padlog_n;
      uint16_t rom_vc = (uint16_t)(wram[vc_off] | (wram[vc_off + 1] << 8));
      view_t v; view_reset(&v);
      uint16_t crc = 0xFFFF; unsigned nonzero = 0;
      for (unsigned i = 0; i < nf; i++) {
        unsigned a = padlog_off + 2 * i;
        uint16_t pad = (a + 1 < mem.second) ? (uint16_t)(wram[a] | (wram[a + 1] << 8)) : 0;
        if (pad) nonzero++;
        view_step(&v, pad);
        int16_t m[4]; view_matrix(&v, m);
        crc = view_fold(crc, &v, m);
      }
      if (nf > 0 && nonzero > 0 && crc == rom_vc) {
        printf("VIEW: PASS frames=%u nonzero=%u view_crc=0x%04X (host replay == ROM, bsnes-jg)\n",
               nf, nonzero, crc);
      } else {
        printf("VIEW: FAIL frames=%u nonzero=%u host=0x%04X rom=0x%04X\n", nf, nonzero, crc, rom_vc);
        rc = 1;
      }
    } else {
      printf("VIEW: FAIL (WRAM offsets out of range)\n"); rc = 1;
    }
  }
#endif

  return rc;
}
