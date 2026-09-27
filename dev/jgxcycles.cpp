// Measure an executed ROM region using bsnes-jg's master-clock counter.
// The instrumented core calls these hooks around each CPU instruction. ROM
// reads retain their normal bus timing; DRAM refresh and DMA stalls are included.
// STOP=0 measures a native near-call return. STOP=0xffffffff ends after the
// instruction that writes EXPECT to WRAM. Other STOP values end before that PC.
#include <bsnes.hpp>
#include "settings.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

static std::vector<uint8_t> game;
static std::string gamepath, datapath;
static std::vector<uint32_t> video(256 * 248 * 4);
static float audio[3200];
static uint32_t startPC, endPC, stopPC, entryClock, instructionClock, instructionPC;
static uint16_t entrySP;
static bool active;
static unsigned wantedSamples, resultOffset, resultLength;
static uint32_t expectedResult;
static const uint8_t *wram;
static uint64_t exclusive, instructions;
static std::vector<uint32_t> samples;
static std::map<uint32_t, std::pair<uint64_t, uint64_t>> profile;

extern "C" void cycle_probe_before(uint32_t pc, uint16_t sp, uint32_t clock) {
  if (active && pc == stopPC) {
    samples.push_back(clock - entryClock);
    active = false;
  }
  if (!active && samples.size() < wantedSamples && pc == startPC) {
    active = true;
    entryClock = clock;
    entrySP = sp;
  }
  instructionClock = clock;
  instructionPC = pc;
}

extern "C" void cycle_probe_after(uint16_t sp, uint32_t clock) {
  if (!active) return;
  if (instructionPC >= startPC && instructionPC < endPC) {
    uint32_t elapsed = clock - instructionClock;
    exclusive += elapsed;
    ++instructions;
    auto &row = profile[instructionPC];
    ++row.first;
    row.second += elapsed;
  }
  // Native near calls push two return-address bytes. Nested calls and local
  // pushes keep SP below the outer caller's value until its RTS completes.
  uint32_t result = 0;
  if (stopPC == UINT32_MAX)
    for (unsigned k = 0; k < resultLength; ++k)
      result |= uint32_t(wram[resultOffset + k]) << (8 * k);
  if ((stopPC == 0 && sp == uint16_t(entrySP + 2)) ||
      (stopPC == UINT32_MAX && result == expectedResult)) {
    samples.push_back(clock - entryClock);
    active = false;
  }
}

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
  if (argc != 11) {
    fprintf(stderr, "Usage: %s ROM DATABASE START END STOP_OR_0 WRAM_OFF LEN EXPECT FRAMES SAMPLES\n", argv[0]);
    return 2;
  }
  gamepath = argv[1]; datapath = argv[2];
  startPC = strtoul(argv[3], nullptr, 0);
  endPC = strtoul(argv[4], nullptr, 0);
  stopPC = strtoul(argv[5], nullptr, 0);
  unsigned offset = strtoul(argv[6], nullptr, 0);
  unsigned length = strtoul(argv[7], nullptr, 0);
  uint32_t expected = strtoul(argv[8], nullptr, 0);
  unsigned frames = strtoul(argv[9], nullptr, 0);
  unsigned wanted = strtoul(argv[10], nullptr, 0);
  wantedSamples = wanted;
  resultOffset = offset;
  resultLength = length;
  expectedResult = expected;
  if (!wanted || !frames || length < 1 || length > 4 || startPC >= endPC) return 2;
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
  if (!mem.first || offset + length > mem.second) return 2;
  wram = static_cast<uint8_t*>(mem.first);
  uint32_t got = 0;
  for (unsigned i = 0; i < frames; ++i) {
    Bsnes::run();
    got = 0;
    for (unsigned k = 0; k < length; ++k)
      got |= uint32_t(static_cast<uint8_t*>(mem.first)[offset + k]) << (8 * k);
    if (samples.size() >= wanted && got == expected) break;
  }
  bool pass = got == expected && samples.size() == wanted && !active;
  printf("{\"pass\":%s,\"got\":%u,\"expected\":%u,\"exclusive_master_clocks\":%llu,\"instructions\":%llu,\"samples\":[",
         pass ? "true" : "false", got, expected,
         (unsigned long long)exclusive, (unsigned long long)instructions);
  for (unsigned i = 0; i < samples.size(); ++i) printf("%s%u", i ? "," : "", samples[i]);
  printf("],\"profile\":[");
  bool comma = false;
  for (const auto &row : profile) {
    printf("%s[%u,%llu,%llu]", comma ? "," : "", row.first,
           (unsigned long long)row.second.first, (unsigned long long)row.second.second);
    comma = true;
  }
  printf("]}\n");
  return pass ? 0 : 1;
}
