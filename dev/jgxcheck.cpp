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
#include <climits>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <bsnes.hpp>
#include "png_write.h"   // dependency-free RGB8 PNG writer (shared with tools/mandel-render.c)

#if defined(JGX_VIEW) || defined(JGX_ZOOM) || defined(JGX_BLOSSOM) || defined(JGX_NAV)
// Interactive-demo input differential (built only by dev/mandel-interactive.sh / dev/mandel-zoom.sh
// as a separate `jgxcheck-view` / `jgxcheck-zoom` binary, so the plain jgxcheck used by other
// scripts is unaffected). Drive a scripted controller sequence into pollInput, then replay the
// SHARED pure view math (examples/snes/view.h or zoom.h) over the ROM's ground-truth pad log and
// assert an identical rolling CRC. The NO_IMG guards keep the baked image arrays out of this host
// TU (we only need the SINCOS table + the per-level reference hashes).
#ifdef JGX_VIEW
#define MANDEL_IMAGE_NO_IMG
#include "view.h"
#endif
#ifdef JGX_ZOOM
#define PYRAMID_NO_IMG
#include "zoom.h"
#endif
#ifdef JGX_BLOSSOM
#include "blossom.h"
#endif
#ifdef JGX_NAV
#define JOY_B 0x8000
#define JOY_Y 0x4000
#define JOY_SELECT 0x2000
#define JOY_START 0x1000
#define JOY_UP 0x0800
#define JOY_DOWN 0x0400
#define JOY_LEFT 0x0200
#define JOY_RIGHT 0x0100
#define JOY_A 0x0080
#define JOY_X 0x0040
#define JOY_L 0x0020
#define JOY_R 0x0010
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
// ---- force-blank bleed scan (JGX_BLANKSCAN) --------------------------------------------------
//
// A force-blank released LATE — asserted in v-blank for a DMA that then overruns into active
// display — blanks the TOP N scanlines of the picture for that one frame. Nothing in the bench
// caught that class of bug; it only shows as a brief flicker to a human watching the ROM boot.
//
// Metric per frame: how many leading rows of the ACTIVE picture are entirely black. A demo whose
// artwork happens to be black at the top gives a steady high count, which is fine — the signature
// of bleed is a one-frame SPIKE against its neighbours, so blank_scan_report looks for spikes, not
// for absolute blackness.
//
// yoff mirrors the web player (public/play/app.js): the 240-line buffer carries the 224-line
// picture at an 8-line offset, so the active picture starts at row 8. jgxcheck's PNG dump defaults
// to yoff=0 and is therefore shifted 8 lines from what a browser shows — do not confuse the two.
static int leading_black_rows(void) {
  if (!g_pitch || !vbuf || !g_h) return -1;
  const int yoff = (g_h >= 232) ? 8 : 0;
  const int rows = ((int)g_h - yoff) < 224 ? ((int)g_h - yoff) : 224;
  const int step = (g_w >= 512) ? 2 : 1;
  const int cols = (int)g_w / step;
  int n = 0;
  for (int y = 0; y < rows; y++) {
    bool black = true;
    for (int x = 0; x < cols && black; x++)
      if (vbuf[(size_t)(y + yoff) * g_pitch + (size_t)x * step] & 0x00FFFFFFu) black = false;
    if (!black) break;
    n++;
  }
  return n;
}

// Flag frames whose leading-black-row count is a LOCAL MAXIMUM exceeding both neighbours by
// >= threshold. Comparing against the HIGHER neighbour is what makes this specific: the title
// card's gravity exit walks the black top band monotonically from 0 to 224 over ~40 frames, and
// every frame of that ramp beats its predecessor — but none is a local max, so none is flagged.
// Force-blank bleed is a one-frame excursion, which is.
// ...and require the spike to sit on a QUIESCENT baseline. Bleed is a one-frame excursion on an
// otherwise stable picture; a local max inside an active transition is not evidence of it.
//
// The case that forced this: lsystem holds a grown plant, then canvas_clear() dirties all 256 tiles
// while bitmap_canvas caps the flush at CANVAS_FLUSH_TILES(64)/frame, so the clear reaches VRAM over
// 4 frames sweeping top-down while the regrowth restarts from the trunk at the bottom. The frame
// where the descending clear front crosses the ascending regrowth is a local maximum BY
// CONSTRUCTION (measured: 47,79,111,143,[149],142,135,128 with total ink 189->11->26 — a wholesale
// content change, the opposite of bleed). Locally it is indistinguishable from real bleed: its
// neighbours are 143 and 142, a textbook 6-row excursion between near-equal shoulders. Only the
// wider window reveals the sweep, so no threshold on the 3-point comparison can separate them.
//
// TRADE-OFF, deliberately accepted: a genuine bleed landing inside a wipe/fade/scene change is now
// MISSED. Bleed is a DMA/v-blank-overrun artifact that shows on otherwise stable frames, and a
// standing false FAIL is worse — it trains us to ignore the gate, which is how a black truncstair
// shipped for weeks. Skips are reported, never silent.
static int blank_scan_report(const std::vector<int> &v, int threshold, int win, int quiet) {
  int flagged = 0, skipped = 0;
  for (size_t i = 1; i + 1 < v.size(); i++) {
    int nb = v[i - 1] > v[i + 1] ? v[i - 1] : v[i + 1];   // the HIGHER neighbour
    if (v[i] - nb < threshold) continue;
    // Spread of the surrounding window, EXCLUDING the candidate itself.
    size_t lo = (i > (size_t)win) ? i - (size_t)win : 0;
    size_t hi = i + (size_t)win + 1 < v.size() ? i + (size_t)win : v.size() - 1;
    int wmin = INT_MAX, wmax = INT_MIN;
    for (size_t j = lo; j <= hi; j++) {
      if (j == i) continue;
      if (v[j] < wmin) wmin = v[j];
      if (v[j] > wmax) wmax = v[j];
    }
    const int spread = (wmax >= wmin) ? wmax - wmin : 0;
    if (spread >= quiet) {
      if (skipped < 20)
        printf("BLANKSCAN: frame %zu spike %d ignored — window spread %d >= %d "
               "(picture in transition, not force-blank bleed)\n", i, v[i], spread, quiet);
      skipped++;
      continue;
    }
    if (flagged < 20)
      printf("BLANKSCAN: frame %zu has %d black rows at top (neighbours %d / %d, window spread %d)\n",
             i, v[i], v[i - 1], v[i + 1], spread);
    flagged++;
  }
  if (flagged == 0)
    printf("BLANKSCAN: PASS %zu frames, no force-blank bleed (threshold %d rows, %d transition spike(s) ignored)\n",
           v.size(), threshold, skipped);
  else
    printf("BLANKSCAN: FAIL %d frame(s) with a transient black band at the top\n", flagged);
  return flagged;
}

// Synthetic self-test (JGX_BLANKSCAN_SELFTEST=1). The real signal costs ~15 s of emulation per
// frame to reproduce, so the discrimination logic is pinned here instead.
static int blank_scan_selftest(int threshold, int win, int quiet) {
  struct Case { const char *name; std::vector<int> v; bool expect_flag; };
  const std::vector<Case> cases = {
    // Force-blank bleed on a static scene: one 12-row excursion, flat shoulders. MUST flag.
    {"bleed on quiescent baseline",
     {40,40,40,40,40,40,52,40,40,40,40,40,40}, true},
    // The measured lsystem clear-and-regrow V-apex. MUST NOT flag.
    {"lsystem clear/regrow apex",
     {47,47,47,47,47,79,111,143,149,142,135,128,123,115,112,108}, false},
    // The title's gravity exit: monotonic ramp, no local max. MUST NOT flag.
    {"title gravity ramp (monotonic)",
     {0,6,12,24,40,60,84,110,140,170,196,212,224}, false},
  };
  int bad = 0;
  for (const Case &c : cases) {
    printf("SELFTEST: %s\n", c.name);
    const bool got = blank_scan_report(c.v, threshold, win, quiet) > 0;
    const bool ok = (got == c.expect_flag);
    printf("SELFTEST: %-32s expect %-8s got %-8s %s\n\n", c.name,
           c.expect_flag ? "FLAG" : "no-flag", got ? "FLAG" : "no-flag", ok ? "PASS" : "FAIL");
    if (!ok) bad++;
  }
  printf("SELFTEST: %s (%zu cases, %d failed)\n", bad ? "FAIL" : "PASS", cases.size(), bad);
  return bad;
}

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
#if defined(JGX_VIEW) || defined(JGX_ZOOM) || defined(JGX_BLOSSOM) || defined(JGX_NAV)
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
  // JGX_BLANKSCAN_SELFTEST=1 — exercise the bleed-vs-transition discrimination on synthetic
  // series. Needs no ROM, so it runs before argument checking.
  if (getenv("JGX_BLANKSCAN_SELFTEST")) {
    int thr = getenv("JGX_BLANKSCAN_ROWS") ? atoi(getenv("JGX_BLANKSCAN_ROWS")) : 4;
    int win = getenv("JGX_BLANKSCAN_WIN") ? atoi(getenv("JGX_BLANKSCAN_WIN")) : 5;
    int quiet = getenv("JGX_BLANKSCAN_QUIET") ? atoi(getenv("JGX_BLANKSCAN_QUIET")) : 8;
    return blank_scan_selftest(thr, win, quiet) ? 1 : 0;
  }
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

#if defined(JGX_VIEW) || defined(JGX_ZOOM) || defined(JGX_BLOSSOM) || defined(JGX_NAV)
  if (getenv("JGX_SCRIPT")) parseScript(getenv("JGX_SCRIPT"));
#endif

  // JGX_BLANKSCAN=1 — per-frame force-blank-bleed scan (see blank_scan_report). One emulator run
  // covers every frame, so this is O(frames), not the O(frames^2) of dumping a PNG per frame.
  const bool blankscan = getenv("JGX_BLANKSCAN") != nullptr;
  std::vector<int> blacktop;
  if (blankscan) blacktop.reserve((size_t)frames);

  for (int i = 0; i < frames; ++i) {
    Bsnes::run();
    if (blankscan) blacktop.push_back(leading_black_rows());
#if defined(JGX_VIEW) || defined(JGX_ZOOM) || defined(JGX_BLOSSOM) || defined(JGX_NAV)
    g_frame++;
#endif
  }

  if (blankscan) {
    int thr = getenv("JGX_BLANKSCAN_ROWS") ? atoi(getenv("JGX_BLANKSCAN_ROWS")) : 4;
    int win = getenv("JGX_BLANKSCAN_WIN") ? atoi(getenv("JGX_BLANKSCAN_WIN")) : 5;
    int quiet = getenv("JGX_BLANKSCAN_QUIET") ? atoi(getenv("JGX_BLANKSCAN_QUIET")) : 8;
    if (blank_scan_report(blacktop, thr, win, quiet) != 0) return 3;
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
  if (getenv("JGX_WRAM_DUMP")) {
    unsigned dump_off = (unsigned)strtoul(getenv("JGX_WRAM_DUMP"), nullptr, 16);
    unsigned dump_len = getenv("JGX_WRAM_DUMP_LEN")
                          ? (unsigned)strtoul(getenv("JGX_WRAM_DUMP_LEN"), nullptr, 0) : 32;
    fprintf(stderr, "jgxcheck: WRAM @0x%X:", dump_off);
    for (unsigned i = 0; i < dump_len && dump_off + i < mem.second; ++i)
      fprintf(stderr, " %02X", wram[dump_off + i]);
    fprintf(stderr, "\n");
  }
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

#ifdef JGX_BLOSSOM
  // Input differential: replay blossom.h over the ROM's ground-truth pad log; assert host == ROM.
  if (getenv("JGX_SCRIPT") && getenv("JGX_BLOSSOMCRC") && getenv("JGX_PADLOG") && getenv("JGX_NFRAMES")) {
    unsigned padlog_off = (unsigned)strtoul(getenv("JGX_PADLOG"), nullptr, 16);
    unsigned bc_off     = (unsigned)strtoul(getenv("JGX_BLOSSOMCRC"), nullptr, 16);
    unsigned nf_off     = (unsigned)strtoul(getenv("JGX_NFRAMES"), nullptr, 16);
    unsigned padlog_n   = getenv("JGX_PADLOG_N") ? (unsigned)atoi(getenv("JGX_PADLOG_N")) : 64;
    if (nf_off < mem.second && bc_off + 1 < mem.second) {
      unsigned nf = wram[nf_off];
      if (nf > padlog_n) nf = padlog_n;
      uint16_t rom_bc = (uint16_t)(wram[bc_off] | (wram[bc_off + 1] << 8));
      blossom_t v; blossom_reset(&v);
      uint16_t crc = 0xFFFF; unsigned nonzero = 0;
      for (unsigned i = 0; i < nf; i++) {
        unsigned a = padlog_off + 2 * i;
        uint16_t pad = (a + 1 < mem.second) ? (uint16_t)(wram[a] | (wram[a + 1] << 8)) : 0;
        if (pad) nonzero++;
        blossom_step(&v, pad);
        crc = blossom_fold(crc, &v);
      }
      if (nf > 0 && nonzero > 0 && crc == rom_bc) {
        printf("BLOSSOM: PASS frames=%u nonzero=%u blossom_crc=0x%04X (host replay == ROM, bsnes-jg)\n",
               nf, nonzero, crc);
      } else {
        printf("BLOSSOM: FAIL frames=%u nonzero=%u host=0x%04X rom=0x%04X\n", nf, nonzero, crc, rom_bc);
        rc = 1;
      }
    } else {
      printf("BLOSSOM: FAIL (WRAM offsets out of range)\n"); rc = 1;
    }
  }
#endif

#ifdef JGX_ZOOM
  // (1) Per-level image correctness: the ROM hashes every baked level at boot into level_hash[];
  // assert each == its host reference MANDEL_PYR_HASH[k] (so every displayed level IS the verified
  // deeper Mandelbrot). (2) Zoom-math differential: replay zoom.h over the ROM's ground-truth pad
  // log; assert host == ROM (gates the level-swap arithmetic + the Mode 7 matrix multiplies).
  if (getenv("JGX_LEVELHASH")) {
    unsigned lh_off = (unsigned)strtoul(getenv("JGX_LEVELHASH"), nullptr, 16);
    // Single-bank: the ROM hashed every level on-console (all near). Multi-bank: only level 0 is
    // near (bank $00) — levels 1.. are far and proved via the VRAM-readback gate below + a host-side
    // ROM-file hash. So check all L levels' on-console hashes, or just level 0, accordingly.
    int nlev = MANDEL_PYR_MULTIBANK ? 1 : MANDEL_PYR_L;
    int allok = 1;
    for (int k = 0; k < nlev; k++) {
      unsigned a = lh_off + 2 * k;
      uint16_t rom_h = (a + 1 < mem.second) ? (uint16_t)(wram[a] | (wram[a + 1] << 8)) : 0;
      if (rom_h != MANDEL_PYR_HASH[k]) {
        printf("HASH: FAIL level %d rom=0x%04X host=0x%04X\n", k, rom_h, MANDEL_PYR_HASH[k]);
        allok = 0;
      }
    }
    if (allok) printf("HASH: PASS %d on-console level%s (rom level_hash == host MANDEL_PYR_HASH, bsnes-jg)\n",
                      nlev, nlev == 1 ? "" : "s");
    else rc = 1;
  }
  // VRAM-readback gate: after the scripted dive, hash the chr actually IN VRAM (the displayed level)
  // and assert it == MANDEL_PYR_HASH[cur_level]. This is the proof that the level-swap DMA — including
  // a multi-bank DMA sourcing from a HIGH ROM bank — lands the correct level on screen. (img_hash16
  // over the VRAM high bytes, matching the bake's tiled-chr hash; same rotate-xor as mandel.h.)
  if (getenv("JGX_CURLEVEL")) {
    unsigned cl_off = (unsigned)strtoul(getenv("JGX_CURLEVEL"), nullptr, 16);
    unsigned nbytes = (unsigned)(MANDEL_PYR_W * MANDEL_PYR_H);
    std::pair<void*, unsigned> vr = Bsnes::getMemoryRaw(Bsnes::Memory::VideoRAM);
    if (cl_off < mem.second && vr.first && vr.second >= 2 * nbytes) {
      unsigned cur = wram[cl_off];
      const uint8_t *vram = (const uint8_t*)vr.first;
      uint16_t h = 0;                                  // img_hash16 over the VRAM high bytes (chr)
      for (unsigned i = 0; i < nbytes; i++) {
        unsigned hi = ((unsigned)h >> 15) & 1u;
        h = (uint16_t)((((unsigned)h << 1) | hi) ^ (unsigned)vram[2 * i + 1]);
      }
      if (getenv("JGX_VRAMOUT")) {                      // debug: write the nbytes high bytes to a file
        FILE *vf = fopen(getenv("JGX_VRAMOUT"), "wb");
        if (vf) { for (unsigned i = 0; i < nbytes; i++) fputc(vram[2 * i + 1], vf); fclose(vf); }
      }
      if (cur < (unsigned)MANDEL_PYR_L && h == MANDEL_PYR_HASH[cur]) {
        printf("VRAM: PASS displayed level %u chr hash=0x%04X == host (bsnes-jg)\n", cur, h);
      } else {
        printf("VRAM: FAIL displayed level %u chr hash=0x%04X host=0x%04X\n",
               cur, h, cur < (unsigned)MANDEL_PYR_L ? MANDEL_PYR_HASH[cur] : 0);
        rc = 1;
      }
    } else {
      printf("VRAM: FAIL (cur_level/VRAM out of range)\n"); rc = 1;
    }
  }
  if (getenv("JGX_SCRIPT") && getenv("JGX_ZOOMCRC") && getenv("JGX_PADLOG") && getenv("JGX_NFRAMES")) {
    unsigned padlog_off = (unsigned)strtoul(getenv("JGX_PADLOG"), nullptr, 16);
    unsigned zc_off     = (unsigned)strtoul(getenv("JGX_ZOOMCRC"), nullptr, 16);
    unsigned nf_off     = (unsigned)strtoul(getenv("JGX_NFRAMES"), nullptr, 16);
    unsigned padlog_n   = getenv("JGX_PADLOG_N") ? (unsigned)atoi(getenv("JGX_PADLOG_N")) : 64;
    if (nf_off < mem.second && zc_off + 1 < mem.second) {
      unsigned nf = wram[nf_off];
      if (nf > padlog_n) nf = padlog_n;
      uint16_t rom_zc = (uint16_t)(wram[zc_off] | (wram[zc_off + 1] << 8));
      zoom_t z; zoom_reset(&z);
      uint16_t crc = 0xFFFF; unsigned nonzero = 0, swaps = 0;
      for (unsigned i = 0; i < nf; i++) {
        unsigned a = padlog_off + 2 * i;
        uint16_t pad = (a + 1 < mem.second) ? (uint16_t)(wram[a] | (wram[a + 1] << 8)) : 0;
        if (pad) nonzero++;
        if (zoom_step(&z, pad)) swaps++;     // count level changes (input must exercise a swap)
        int16_t m[4]; zoom_matrix(&z, m);
        crc = zoom_fold(crc, &z, m);
      }
      if (nf > 0 && nonzero > 0 && swaps > 0 && crc == rom_zc) {
        printf("ZOOM: PASS frames=%u nonzero=%u swaps=%u zoom_crc=0x%04X (host replay == ROM, bsnes-jg)\n",
               nf, nonzero, swaps, crc);
      } else {
        printf("ZOOM: FAIL frames=%u nonzero=%u swaps=%u host=0x%04X rom=0x%04X\n",
               nf, nonzero, swaps, crc, rom_zc);
        rc = 1;
      }
    } else {
      printf("ZOOM: FAIL (WRAM offsets out of range)\n"); rc = 1;
    }
  }
#endif
  return rc;
}
