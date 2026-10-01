// stackguard.h — soft-stack overlap check for the bsnes-jg runtime probe (dev/jgxcheck.cpp).
//
// The SNES platform keeps static data (.data/.bss/.noinit) and the C soft stack in the same low-WRAM
// region: static data grows up from $0200, the soft stack grows down from __stack ($2000), and
// nothing links the two. A program whose frames reach below the end of static data silently
// overwrites its own variables (docs/defects/snes-soft-stack-static-data-collision.json; the
// dither -O3 hang, and rdiff e3bb5a62 before it).
//
// The soft-stack pointer is the imaginary-register pair __rc0/__rc1. MOSFrameLowering::offsetSP
// adjusts it low byte first, then high byte, so an instruction-boundary sample can see a torn pair
// (an epilogue's low-byte carry makes (new low, old high) up to 255 B BELOW the true SP). The patched
// bsnes-jg core (dev/bsnes-jg-wramwatch.patch) therefore reports each WRAM write to __rc0/__rc1 and
// the guard commits a new SP only when the high byte lands, which is always the last store.
//
// Bounds come from the build's own metadata, never hard-coded: <rom>.elf (preferred) or the lld map
// (<rom stem>.map). min_sp is compared with the end of static data = max(__heap_start, end of any
// allocated section in [$0100, __stack)). Margin = min_sp - static_end; negative is a violation.
//
//   JGX_STACKGUARD         unset/1: check when metadata is found; 0: off; require: a ROM with no
//                          metadata, or a core without the write watch, is itself a failure.
//   JGX_STACKGUARD_ONLY=1  run the frames and report the guard verdict only (the value assert is not
//                          evaluated); used by the corpus engine for the ROMs it does not value-check.
//   JGX_STACKGUARD_LOG=F   append one TSV record per run to F (rom, program, config, status, min_sp,
//                          static_end, stack_top, margin, pc, function, bounds source).
//   JGX_PROGRAM, JGX_CONFIG  labels for the message (default: ROM stem; config inferred from the path).
#ifndef STACKGUARD_H
#define STACKGUARD_H

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <regex>
#include <sstream>
#include <string>
#include <vector>

// The write watch lives in the patched core. Weak, so a stale (unpatched) core still links and the
// guard reports "unavailable" instead of the harness failing to build.
extern "C" {
extern unsigned jgx_wram_watch_lo __attribute__((weak));
extern unsigned jgx_wram_watch_len __attribute__((weak));
extern void (*jgx_wram_watch_cb)(unsigned, uint8_t, uint32_t) __attribute__((weak));
}

namespace stackguard {

struct Func { uint32_t addr, size; std::string name; };

struct Bounds {
  bool ok = false;
  std::string why;           // when !ok: why the check cannot run
  std::string source;        // file the bounds came from
  uint32_t rc0 = 0, stack_top = 0, heap_start = 0, static_end = 0;
  std::string static_end_src;
  std::vector<Func> funcs;   // ELF only
};

static inline bool read_file(const std::string &path, std::string &out) {
  std::ifstream f(path, std::ios::binary);
  if (!f.is_open()) return false;
  std::ostringstream ss; ss << f.rdbuf(); out = ss.str();
  return true;
}

template <class T> static inline bool rd(const std::string &b, size_t off, T &v) {
  if (off + sizeof(T) > b.size()) return false;
  memcpy(&v, b.data() + off, sizeof(T));   // ELF32 little-endian (llvm-mos); host is little-endian
  return true;
}

// ELF32 LE: symbols __rc0 / __stack / __heap_start, ALLOC section ends, FUNC symbols.
static inline Bounds from_elf(const std::string &path) {
  Bounds b; b.source = path;
  std::string d;
  if (!read_file(path, d)) { b.why = "cannot read " + path; return b; }
  if (d.size() < 52 || memcmp(d.data(), "\x7f" "ELF", 4) != 0 || d[4] != 1 || d[5] != 1) {
    b.why = path + " is not an ELF32 little-endian file"; return b;
  }
  uint32_t shoff = 0; uint16_t shentsize = 0, shnum = 0;
  rd(d, 32, shoff); rd(d, 46, shentsize); rd(d, 48, shnum);
  struct Sec { uint32_t type, flags, addr, off, size, link, entsize; };
  std::vector<Sec> secs;
  for (unsigned i = 0; i < shnum; ++i) {
    size_t o = shoff + (size_t)i * shentsize; Sec s{};
    if (!rd(d, o + 4, s.type) || !rd(d, o + 8, s.flags) || !rd(d, o + 12, s.addr) ||
        !rd(d, o + 16, s.off) || !rd(d, o + 20, s.size) || !rd(d, o + 24, s.link) ||
        !rd(d, o + 36, s.entsize)) { b.why = path + ": truncated section headers"; return b; }
    secs.push_back(s);
  }
  bool have_rc0 = false, have_stack = false, have_heap = false;
  for (const Sec &s : secs) {
    if (s.type != 2 /*SYMTAB*/ || s.link >= secs.size() || s.entsize < 16) continue;
    const Sec &str = secs[s.link];
    for (uint32_t o = 0; o + 16 <= s.size; o += s.entsize) {
      uint32_t name, value, size; uint8_t info; uint16_t shndx;
      if (!rd(d, s.off + o, name) || !rd(d, s.off + o + 4, value) || !rd(d, s.off + o + 8, size) ||
          !rd(d, s.off + o + 12, info) || !rd(d, s.off + o + 14, shndx) ||
          str.off + name >= d.size()) continue;
      std::string n(d.c_str() + str.off + name);
      if (n == "__rc0") { b.rc0 = value; have_rc0 = true; }
      else if (n == "__stack") { b.stack_top = value; have_stack = true; }
      else if (n == "__heap_start") { b.heap_start = value; have_heap = true; }
      // Code symbols: FUNC, or the NOTYPE labels of hand-written assembly (crt0), in an executable section.
      unsigned type = info & 0xF;
      if ((type == 2 || type == 0) && !n.empty() && n[0] != '$' && n[0] != '.' && shndx < secs.size() &&
          (secs[shndx].flags & 4 /*EXEC*/))
        b.funcs.push_back({value, size, n});
    }
  }
  if (!have_rc0 || !have_stack || !have_heap) {
    b.why = path + ": no __rc0/__stack/__heap_start symbols (not a llvm-mos soft-stack ELF)"; return b;
  }
  b.static_end = b.heap_start; b.static_end_src = "__heap_start";
  for (const Sec &s : secs) {
    if (!(s.flags & 2 /*ALLOC*/) || s.size == 0) continue;
    if (s.addr >= 0x100 && s.addr < b.stack_top && s.addr + s.size > b.static_end) {
      b.static_end = s.addr + s.size; b.static_end_src = "end of an allocated section";
    }
  }
  std::sort(b.funcs.begin(), b.funcs.end(), [](const Func &x, const Func &y) { return x.addr < y.addr; });
  b.ok = true;
  return b;
}

// lld -Map output: `__stack = 0x2000` / `__rc0 = 0x00` carry their value in the expression;
// `__heap_start = ALIGN(., 2)` carries its pre-alignment value in the VMA column (rounded up here to
// match the ELF symbol); section lines are `VMA LMA Size Align Out`.
static inline Bounds from_map(const std::string &path) {
  Bounds b; b.source = path;
  std::ifstream f(path);
  if (!f.is_open()) { b.why = "cannot read " + path; return b; }
  bool have_rc0 = false, have_stack = false, have_heap = false;
  struct Sec { uint32_t addr, size; };
  std::vector<Sec> secs;
  std::string line;
  while (std::getline(f, line)) {
    std::istringstream is(line); std::vector<std::string> t; std::string w;
    while (is >> w) t.push_back(w);
    if (t.size() < 5) continue;
    char *e = nullptr;
    uint32_t vma = (uint32_t)strtoul(t[0].c_str(), &e, 16);
    if (*e) continue;
    if (t.size() == 5 && t[4][0] == '.') {   // output-section line
      uint32_t size = (uint32_t)strtoul(t[2].c_str(), &e, 16);
      if (!*e) secs.push_back({vma, size});
      continue;
    }
    if (t[4] == "__heap_start" && t.size() > 5 && t[5] == "=") {
      // The VMA column is the location counter before `= ALIGN(., N)` is applied; the symbol is rounded up.
      if (t.size() > 7 && t[6].compare(0, 8, "ALIGN(.,") == 0) {
        uint32_t n = (uint32_t)strtoul(t[7].c_str(), nullptr, 0);
        if (n > 1 && (n & (n - 1)) == 0) vma = (vma + n - 1) & ~(n - 1);
      }
      b.heap_start = vma; have_heap = true;
    }
    else if ((t[4] == "__stack" || t[4] == "__rc0") && t.size() > 6 && t[5] == "=") {
      uint32_t v = (uint32_t)strtoul(t[6].c_str(), &e, 0);
      if (*e) continue;
      if (t[4] == "__stack") { b.stack_top = v; have_stack = true; } else { b.rc0 = v; have_rc0 = true; }
    }
  }
  if (!have_rc0 || !have_stack || !have_heap) {
    b.why = path + ": no __rc0/__stack/__heap_start in the map"; return b;
  }
  b.static_end = b.heap_start; b.static_end_src = "__heap_start";
  for (const Sec &s : secs)
    if (s.size && s.addr >= 0x100 && s.addr < b.stack_top && s.addr + s.size > b.static_end) {
      b.static_end = s.addr + s.size; b.static_end_src = "end of an allocated section";
    }
  b.ok = true;
  return b;
}

static inline bool exists(const std::string &p) { std::ifstream f(p); return f.is_open(); }

// <rom>.elf (the SDK driver leaves foo.sfc.elf beside foo.sfc), <stem>.elf, then <stem>.map.
static inline Bounds locate(const std::string &rom) {
  const char *ov = getenv("JGX_STACKGUARD_ELF");
  if (ov && *ov) return from_elf(ov);
  std::string stem = rom;
  size_t dot = stem.find_last_of('.'), slash = stem.find_last_of('/');
  if (dot != std::string::npos && (slash == std::string::npos || dot > slash)) stem.erase(dot);
  for (const std::string &p : {rom + ".elf", stem + ".elf"}) if (exists(p)) return from_elf(p);
  if (exists(stem + ".map")) return from_map(stem + ".map");
  Bounds b; b.why = "no " + rom + ".elf / " + stem + ".elf / " + stem + ".map beside the ROM";
  return b;
}

// Shared by the watch callback; one guard per process.
struct State {
  Bounds bounds;
  bool wanted = false, watching = false;
  bool have_lo = false, have_hi = false, have_sp = false;
  uint8_t lo = 0, hi = 0;
  uint32_t min_sp = 0, min_pc = 0, first_sp = 0, commits = 0;
  std::string program, config, rom, status_why;
};
static inline State &state() { static State s; return s; }

static inline void on_write(unsigned off, uint8_t data, uint32_t pc) {
  State &s = state();
  if (off == s.bounds.rc0) { s.lo = data; s.have_lo = true; return; }
  s.hi = data; s.have_hi = true;                       // __rc1: the last store of any SP adjustment
  if (!s.have_lo) return;
  uint32_t sp = ((uint32_t)s.hi << 8) | s.lo;
  if (!s.have_sp) s.first_sp = sp;
  s.commits++;
  if (!s.have_sp || sp < s.min_sp) { s.min_sp = sp; s.min_pc = pc; s.have_sp = true; }
}

// Only the ROM's own name and its directory are read (never the whole path: "llvm-mos" contains "os").
static inline std::string infer_config(const std::string &rom) {
  static const std::regex re("(^|[^A-Za-z0-9])(xy16|a16|default|O[0123sz])([^A-Za-z0-9]|$)");
  size_t slash = rom.find_last_of('/');
  std::string scope = slash == std::string::npos ? rom : rom.substr(slash + 1);
  if (slash != std::string::npos && slash > 0) {
    size_t prev = rom.find_last_of('/', slash - 1);
    scope = rom.substr(prev == std::string::npos ? 0 : prev + 1, slash - (prev == std::string::npos ? 0 : prev + 1)) + "/" + scope;
  }
  std::string found;
  for (auto it = std::sregex_iterator(scope.begin(), scope.end(), re); it != std::sregex_iterator(); ++it) {
    if (!found.empty()) found += " ";
    found += (*it)[2].str();
  }
  return found.empty() ? "unspecified" : found + " (inferred from the ROM path)";
}

static inline std::string stem_of(const std::string &rom) {
  size_t slash = rom.find_last_of('/');
  std::string n = slash == std::string::npos ? rom : rom.substr(slash + 1);
  size_t dot = n.find('.');
  return dot == std::string::npos ? n : n.substr(0, dot);
}

// Call before Bsnes::load(). Returns false only when the guard is `require`d and cannot run.
static inline bool init(const std::string &rom, std::string &err) {
  State &s = state();
  const char *mode = getenv("JGX_STACKGUARD");
  std::string m = mode ? mode : "";
  if (m == "0") return true;
  s.wanted = true; s.rom = rom;
  const char *p = getenv("JGX_PROGRAM"), *c = getenv("JGX_CONFIG");
  s.program = (p && *p) ? p : stem_of(rom);
  s.config = (c && *c) ? c : infer_config(rom);
  s.bounds = locate(rom);
  if (!s.bounds.ok) {
    s.status_why = s.bounds.why;
    if (m == "require") { err = "stackguard: cannot check " + s.program + ": " + s.status_why; return false; }
    return true;
  }
  if (&jgx_wram_watch_cb == nullptr || &jgx_wram_watch_lo == nullptr || &jgx_wram_watch_len == nullptr) {
    s.status_why = "bsnes-jg core lacks the WRAM write watch (apply dev/bsnes-jg-wramwatch.patch, "
                   "rebuild the core, rm build/jgxcheck and rebuild it)";
    if (m == "require") { err = "stackguard: cannot check " + s.program + ": " + s.status_why; return false; }
    fprintf(stderr, "jgxcheck: stackguard UNAVAILABLE for %s: %s\n", s.program.c_str(), s.status_why.c_str());
    return true;
  }
  jgx_wram_watch_lo = s.bounds.rc0;
  jgx_wram_watch_len = 2;
  jgx_wram_watch_cb = on_write;
  s.watching = true;
  return true;
}

struct Verdict {
  const char *status = "skipped";   // skipped | ok | overlap | nosp
  long margin = 0;
  uint32_t overlap = 0;
  std::string summary;              // one line, suitable for a SMOKE: suffix
  std::string detail;               // multi-line stderr block (overlap only)
};

static inline std::string function_at(const Bounds &b, uint32_t pc) {
  for (uint32_t cand : {pc, pc & 0xFFFFu}) {
    const Func *best = nullptr;
    for (const Func &f : b.funcs) if (f.addr <= cand && (!best || f.addr > best->addr)) best = &f;
    if (best && cand - best->addr <= std::max<uint32_t>(best->size, 1)) return best->name;
  }
  return "?";
}

static inline std::string hex(uint32_t v) {
  char buf[16]; snprintf(buf, sizeof buf, "$%04X", v); return buf;
}

// Call once, after the frames have run.
static inline Verdict finish() {
  State &s = state();
  Verdict v;
  std::string func = "?";
  if (s.watching && !s.have_sp) {
    v.status = "nosp";
    v.summary = "stackguard: " + s.program + " never initialised the soft-stack pointer in this run";
  } else if (s.watching) {
    const Bounds &b = s.bounds;
    func = function_at(b, s.min_pc);
    v.margin = (long)s.min_sp - (long)b.static_end;
    if (v.margin < 0) {
      v.status = "overlap"; v.overlap = (uint32_t)(-v.margin);
      char line[512];
      snprintf(line, sizeof line,
               "stackguard: soft stack overlaps static data by %u B (program=%s, config=%s)",
               v.overlap, s.program.c_str(), s.config.c_str());
      v.summary = line;
      std::ostringstream os;
      os << "jgxcheck: STACKGUARD FAIL: " << s.program << " [" << s.config << "] soft stack overlaps static data by "
         << v.overlap << " B\n"
         << "  min soft SP " << hex(s.min_sp) << " (first reached near pc " << hex(s.min_pc) << ", in " << func
         << ") < end of static data " << hex(b.static_end) << " (" << b.static_end_src << "); stack top "
         << hex(b.stack_top) << ", margin " << v.margin << " B\n"
         << "  rom=" << s.rom << "  bounds=" << b.source << "\n"
         << "  Frames in [" << hex(s.min_sp) << ", " << hex(b.static_end) << ") alias .bss/.noinit; see "
         << "docs/defects/snes-soft-stack-static-data-collision.json";
      v.detail = os.str();
    } else {
      v.status = "ok";
    }
  }
  if (const char *log = getenv("JGX_STACKGUARD_LOG")) {
    if (*log && s.wanted) {
      FILE *f = fopen(log, "a");
      if (f) {
        const Bounds &b = s.bounds;
        fprintf(f, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", s.rom.c_str(), s.program.c_str(),
                s.config.c_str(), v.status,
                s.have_sp ? hex(s.min_sp).c_str() : "-", b.ok ? hex(b.static_end).c_str() : "-",
                b.ok ? hex(b.stack_top).c_str() : "-", s.have_sp ? std::to_string(v.margin).c_str() : "-",
                s.have_sp ? hex(s.min_pc).c_str() : "-", func.c_str(),
                b.ok ? b.source.c_str() : s.status_why.c_str());
        fclose(f);
      }
    }
  }
  return v;
}

}  // namespace stackguard

#endif
