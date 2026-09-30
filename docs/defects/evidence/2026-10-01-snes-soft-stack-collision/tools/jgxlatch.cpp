// jgxlatch: print soft-stack spill slots each time the CPU reaches one PC.
//
// Derived from dev/jgxcycles.cpp (same bsnes-jg core with the cycle_probe_before/after hooks,
// built by build/pressure-sets/opt-levels/probe). At every execution of WATCH_PC it reads the
// soft stack pointer __rc0/__rc1 (WRAM $0000-$0001) and prints the bytes that main's -O3 frame
// keeps at SP+44 (y*11 accumulator), SP+46 (row counter y) and SP+47..48 (out[] row pointer),
// the slots named in main's post-PEI MIR (%stack.9, %stack.7, %stack.6).
//
//   jgxlatch ROM DATABASE WATCH_PC FRAMES MAX_HITS
//
// Build: g++ -O2 -std=c++11 -I<probe>/bsnes/src jgxlatch.cpp <probe>/bsnes/objs/libbsnes.a \
//            -lsamplerate -lm -o jgxlatch
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
static const uint8_t *wram;
static unsigned hits, maxHits;
static uint32_t watchPC;

extern "C" void cycle_probe_before(uint32_t pc, uint16_t, uint32_t) {
  if (pc != watchPC || !wram || hits >= maxHits) return;
  unsigned ssp = wram[0] | (wram[1] << 8);
  printf("hit %u pc=%06x softSP=%04x y@SP+46=%02x rowptr@SP+47=%04x h@SP+44=%02x\n", hits, pc, ssp,
         wram[ssp + 46], wram[ssp + 47] | (wram[ssp + 48] << 8), wram[ssp + 44]);
  ++hits;
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
    fprintf(stderr, "Usage: %s ROM DATABASE WATCH_PC FRAMES MAX_HITS\n", argv[0]);
    return 2;
  }
  gamepath = argv[1]; datapath = argv[2];
  watchPC = strtoul(argv[3], nullptr, 0);
  unsigned frames = strtoul(argv[4], nullptr, 0);
  maxHits = strtoul(argv[5], nullptr, 0);
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
  wram = static_cast<uint8_t*>(mem.first);
  for (unsigned i = 0; i < frames && hits < maxHits; ++i) Bsnes::run();
  printf("hits=%u\n", hits);
  return 0;
}
