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
static void videoFrame(const void*, unsigned, unsigned, unsigned) {}               // headless: ignore
static void audioFrame(const void*, size_t) {}                                     // headless: discard
static int pollInput(const void*, unsigned, unsigned) { return 0; }

int main(int argc, char **argv) {
  if (argc < 6) {
    fprintf(stderr, "Usage: %s <rom.sfc> <datadir> <offset_hex> <len> <want_hex> [frames]\n", argv[0]);
    return 2;
  }
  const char *rompath = argv[1];
  datapath = argv[2];
  unsigned off  = (unsigned)strtoul(argv[3], nullptr, 16);
  unsigned len  = (unsigned)strtoul(argv[4], nullptr, 0);
  unsigned want = (unsigned)strtoul(argv[5], nullptr, 16);
  int frames = argc > 6 ? atoi(argv[6]) : 120;
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
