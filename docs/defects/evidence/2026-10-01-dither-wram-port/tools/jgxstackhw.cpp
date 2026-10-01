// jgxstackhw: soft-stack high-water mark of a SNES ROM under bsnes-jg.
//
// Derived from jgxlatch.cpp (same core and cycle_probe_before hook). The first time the soft stack
// pointer (__rc0/__rc1, WRAM $0000-$0001) equals TOP, which crt0 sets before any C code runs, the
// tool fills WRAM [LOW, TOP) with a canary byte. After FRAMES frames it scans upward from LOW for the
// first byte that is not the canary: everything below it was never written, everything from it to TOP
// may have been. LOW is the end of static data (__heap_start). A byte that the program wrote with the
// canary's own value is not noticed, so the reported depth is a lower bound by at most that byte.
//
//   jgxstackhw ROM DATABASE FRAMES LOW TOP
//
// Build: g++ -O2 -std=c++11 -I<probe>/bsnes/src jgxstackhw.cpp <probe>/bsnes/objs/libbsnes.a \
//            -lsamplerate -lm -o jgxstackhw
#include <bsnes.hpp>
#include "settings.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static std::vector<uint8_t> game;
static std::string gamepath, datapath;
static std::vector<uint32_t> video(256 * 248 * 4);
static float audio[3200];
static unsigned low, top;
static bool armed;
static uint8_t *wramw;

extern "C" void cycle_probe_before(uint32_t, uint16_t, uint32_t) {
  if (armed || !wramw) return;
  if ((unsigned)(wramw[0] | (wramw[1] << 8)) != top) return;
  armed = true;
  for (unsigned a = low; a < top; ++a) wramw[a] = 0xA5;
}
extern "C" void cycle_probe_after(uint16_t, uint32_t) {}

static bool openStream(void*, std::string name, std::stringstream& out) {
  std::ifstream f(datapath + "/" + name, std::ios::binary);
  if (!f) return false;
  out << f.rdbuf();
  return true;
}
static bool openFile(void*, std::string, std::vector<uint8_t>&) { return false; }
static bool openMsu(void*, std::string, std::istream**) { return false; }
static void writeFile(void*, std::string, const uint8_t*, unsigned) {}
static void logMessage(void*, int level, std::string& text) {
  if (level) fprintf(stderr, "bsnes: %s\n", text.c_str());
}
static bool loadRom(void*, unsigned id) {
  if (id != Bsnes::GameType::SuperFamicom) return false;
  Bsnes::setRomSuperFamicom(game, gamepath);
  return true;
}
static void videoFrame(const void*, unsigned, unsigned, unsigned) {}
static void audioFrame(const void*, size_t) {}
static int pollInput(const void*, unsigned, unsigned) { return 0; }

int main(int argc, char** argv) {
  if (argc != 6) {
    fprintf(stderr, "Usage: %s ROM DATABASE FRAMES LOW TOP\n", argv[0]);
    return 2;
  }
  gamepath = argv[1]; datapath = argv[2];
  unsigned frames = strtoul(argv[3], nullptr, 0);
  low = strtoul(argv[4], nullptr, 0);
  top = strtoul(argv[5], nullptr, 0);
  std::ifstream f(gamepath, std::ios::binary);
  if (!f) return 2;
  game.assign(std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>());
  Bsnes::setOpenFileCallback(nullptr, openFile);
  Bsnes::setOpenStreamCallback(nullptr, openStream);
  Bsnes::setOpenMsuCallback(nullptr, openMsu);
  Bsnes::setWriteCallback(nullptr, writeFile);
  Bsnes::setRomLoadCallback(nullptr, loadRom);
  Bsnes::setLogCallback(nullptr, logMessage);
  Bsnes::setAudioSpec({48000.0, 1600, 0, audio, nullptr, audioFrame});
  Bsnes::setVideoSpec({video.data(), nullptr, videoFrame});
  SuperFamicom::configuration.entropy = 0;
  if (!Bsnes::load()) return 2;
  Bsnes::power();
  Bsnes::setInputSpec({0, Bsnes::Input::Device::Gamepad, nullptr, pollInput});
  Bsnes::setInputSpec({1, Bsnes::Input::Device::Gamepad, nullptr, pollInput});
  auto mem = Bsnes::getMemoryRaw(Bsnes::Memory::MainRAM);
  wramw = static_cast<uint8_t*>(mem.first);
  for (unsigned i = 0; i < frames; ++i) Bsnes::run();
  if (!armed) { printf("never armed: soft SP never equalled %#x\n", top); return 1; }
  unsigned a = low;
  while (a < top && wramw[a] == 0xA5) ++a;
  printf("soft-stack high-water: lowest written byte %#06x, %u of %u bytes (%u B untouched above static data)\n",
         a, top - a, top - low, a - low);
  return 0;
}
