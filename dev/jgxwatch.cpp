// jgxwatch — headless bsnes-jg frame-watcher for the llvm-mos 65816 bench.
//
// Like dev/jgxcheck.cpp, but instead of checking WRAM once after a FIXED frame
// count, it runs frame-by-frame and reports the FIRST frame at which LEN
// little-endian WRAM bytes at OFFSET == WANT (then exits). One emulation run —
// used to measure when a deterministic on-console computation SETTLES (e.g. the
// frame mandel-display's corpus_result first reaches its final CRC), which
// jgxcheck can't do without a bisection sweep.
//
//   jgxwatch <rom.sfc> <datadir> <off_hex> <len> <want_hex> <maxframes>
// datadir holds the bsnes game database (boards.bml, SuperFamicom.bml, ...).
// Prints "FRAME <n>" + exit 0 on match, or "NOMATCH (after <maxframes>)" + exit 1.
//
// Build (same as jgxcheck — links the bsnes-jg core + libsamplerate):
//   g++ -O2 -std=c++11 -I vendor/bsnes-jg/src -c dev/jgxwatch.cpp -o jgxwatch.o
//   g++ jgxwatch.o vendor/bsnes-jg/objs/libbsnes.a -lsamplerate -lm -o jgxwatch
//
// See docs/investigations/2026-06-26-mandel-display-render-timing-8bit-vs-16bit.md.
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <bsnes.hpp>

static std::vector<uint8_t> game;
static std::string gamepath, datapath;
static uint32_t *vbuf = nullptr;
static float inbuf[3200];

static void logCallback(void*, int level, std::string& t) { if (level) fprintf(stderr, "bsnes: %s\n", t.c_str()); }
static bool fileOpenS(void*, std::string name, std::stringstream& ss) {
  std::ifstream fs(datapath + "/" + name, std::ios::in | std::ios::binary);
  if (!fs.is_open()) { fprintf(stderr, "jgxwatch: missing data file %s\n", name.c_str()); return false; }
  ss << fs.rdbuf(); return true;
}
static bool fileOpenV(void*, std::string, std::vector<uint8_t>&) { return false; }
static bool fileOpenMsu(void*, std::string, std::istream**) { return false; }
static void fileWrite(void*, std::string, const uint8_t*, unsigned) {}
static bool loadRom(void*, unsigned id) {
  if (id == Bsnes::GameType::SuperFamicom && game.size() >= 0x8000) { Bsnes::setRomSuperFamicom(game, gamepath); return true; }
  return false;
}
static void videoFrame(const void*, unsigned, unsigned, unsigned) {}
static void audioFrame(const void*, size_t) {}
static int pollInput(const void*, unsigned, unsigned) { return 0; }

int main(int argc, char **argv) {
  if (argc < 7) { fprintf(stderr, "Usage: %s <rom> <datadir> <off_hex> <len> <want_hex> <maxframes>\n", argv[0]); return 2; }
  const char *rompath = argv[1];
  datapath = argv[2];
  unsigned off  = (unsigned)strtoul(argv[3], nullptr, 16);
  unsigned len  = (unsigned)strtoul(argv[4], nullptr, 0);
  unsigned want = (unsigned)strtoul(argv[5], nullptr, 16);
  int maxframes = atoi(argv[6]);
  if (len < 1) len = 1;

  std::ifstream fs(rompath, std::ios::in | std::ios::binary);
  if (!fs.is_open()) { fprintf(stderr, "jgxwatch: cannot open %s\n", rompath); return 2; }
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
  if (!Bsnes::load()) { printf("NOMATCH (load failed)\n"); return 1; }
  Bsnes::power();
  Bsnes::setInputSpec({0, Bsnes::Input::Device::Gamepad, nullptr, pollInput});
  Bsnes::setInputSpec({1, Bsnes::Input::Device::Gamepad, nullptr, pollInput});

  std::pair<void*, unsigned> mem = Bsnes::getMemoryRaw(Bsnes::Memory::MainRAM);
  if (!mem.first || mem.second < off + len) { printf("NOMATCH (no MainRAM / out of range)\n"); return 1; }
  const uint8_t *wram = (const uint8_t*)mem.first;

  for (int i = 1; i <= maxframes; ++i) {
    Bsnes::run();
    unsigned got = 0;
    for (unsigned k = 0; k < len; ++k) got |= (unsigned)wram[off + k] << (8 * k);
    if (got == want) { printf("FRAME %d\n", i); return 0; }
  }
  printf("NOMATCH (after %d frames)\n", maxframes);
  return 1;
}
