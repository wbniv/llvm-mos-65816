# Investigation — open-source SNES development libraries (the landscape, June 2026)

**Question:** what open-source libraries / SDKs / frameworks exist for developing *for* the SNES (code you
link into a ROM), and how do they relate to this project (`llvm-mos-65816` — a modern LLVM C compiler for the
65816, currently growing a SNES rendering library)?

**Method:** web survey + per-repo verification on GitHub (license, last activity, language, what each provides),
cross-checked against the community-maintained [NESdev SNES "Tools" wiki](https://snes.nesdev.org/wiki/Tools).
Sources are linked inline and listed at the end. Where a repo's license/date couldn't be read directly it's
flagged "unconfirmed". Out of scope: emulators, ROM hacking/patching tools, and games.

---

## TL;DR

- **Want C today?** [**PVSnesLib**](https://github.com/alekmaul/pvsneslib) (MIT) is the de-facto open C SDK —
  a full HAL (backgrounds, sprites, pads, sound, Mode 7, fonts, math) + toolchain, actively maintained
  (v4.5.0, Dec 2025, ~1.1k★). But it rides the *old* `816-tcc` Tiny-C backend, **not** LLVM.
- **Want assembly?** [**libSFX**](https://github.com/Optiroc/libSFX) (MIT, ca65) is the cleanest framework —
  runtime/IRQ, register-size tracking, DMA/memcpy, SPC playback.
- **Modern LLVM (C/C++/Rust)?** Almost nobody. [**SNES-Dev**](https://github.com/chorman0773/SNES-Dev) is the
  only other LLVM+GNU C/C++/Rust attempt, and it's early WIP (~35★, no releases). **This project
  (`llvm-mos-65816`) is, as far as this survey found, the most actively-developed modern-LLVM C path for the
  65816/SNES** — there is no established LLVM SNES C SDK to reuse; the value in the others is their *library
  code, asset tools, and API designs*, not their compilers.
- **Audio is a solved, separable problem:** drop in [**Terrific Audio Driver**](https://github.com/undisbeliever/terrific-audio-driver)
  (active), SNESMOD, or SNESGSS — they're standalone SPC700 drivers + a data format, toolchain-agnostic.

---

## 1. C / C++ / Rust SDKs & toolchains  *(the category that matters most here)*

| Project | License | Lang | Activity | Toolchain | What it gives you |
|---|---|---|---|---|---|
| [PVSnesLib](https://github.com/alekmaul/pvsneslib) | MIT | C + asm | **Active** — v4.5.0, Dec 2025, ~1.1k★ | bundles `816-tcc` + `wla-dx` + `bass` | Full HAL: backgrounds, sprites, pads, sound/music, Mode 7, fonts, math; asset tools; examples; VS Code + Docker |
| [SNES-Dev](https://github.com/chorman0773/SNES-Dev) | LGPL/GPL/MIT | C, C++, **Rust** | WIP, ~35★, no releases | **LLVM + GNU** | libc, Rust API, linker scripts, ABI extensions — early-stage |
| snes-sdk (Ulrich Hecht / Mic_) + [`816-tcc`](https://github.com/nArnoSNES/tcc-65816) | open (varies) | C | legacy; superseded | `816-tcc` + `wla-dx` + `816-opt` | The original SNES C toolchain PVSnesLib was built on; mostly of historical interest |
| [llvm-to-snes](https://github.com/luizperes/llvm-to-snes) | open | (LLVM IR) | experimental/academic | LLVM IR → `wla-dx` | Proof-of-concept: compile LLVM IR to a SNES ROM; unoptimized, research-grade |
| `WDCTools` | proprietary (free dl) | C + asm | vendor-maintained | WDC's own | The chip vendor's official 65c02/65c816 C compiler + assembler |
| `Calypsi`, `vbcc` | **commercial use needs a license** | C | maintained | own backends | Capable 65816 C compilers, but **not** fully open-source for commercial use — note before depending on them |

**Reading for this project:** PVSnesLib is the closest analog to what we're building — a C SDK with a
PPU/sprite/sound HAL — but its compiler (`816-tcc`) is exactly the kind of old, unoptimizing 65816 C backend
that `llvm-mos` exists to replace. Its **library routines** (asm PPU/DMA/sprite/sound helpers), **asset
converters**, and **API shape** are the reusable parts; its compiler is not the thing to adopt. SNES-Dev is the
only philosophical peer (modern LLVM, C/C++/Rust) and is worth watching/coordinating with, but it's far less
mature than llvm-mos.

## 2. Assembly frameworks

| Project | License | Activity | What it gives you |
|---|---|---|---|
| [libSFX](https://github.com/Optiroc/libSFX) | MIT | ~230★, asm-only (ca65) | System runtime + IRQ handling; **65816 register-size tracking** (minimizes `rep`/`sep`); memcpy/memset + DMA helpers; S-SMP/SPC playback; LZ4 decompression; mouse driver; bundles SuperFamiconv + BRRtools |

libSFX is the best-organized open SNES *assembly* framework and a strong **reference** for our HAL: its DMA
upload patterns, its rep/sep discipline, and its SPC handshake are exactly the problems we hit in Tracks 2–3.
(There are many smaller ca65/asar "skeleton" repos; libSFX is the one with real reusable runtime.)

## 3. Audio / sound drivers  *(standalone SPC700 code + a data format — toolchain-agnostic)*

| Project | License | Activity | What it is |
|---|---|---|---|
| [Terrific Audio Driver](https://github.com/undisbeliever/terrific-audio-driver) | zlib (driver) + MIT (tools) | **Active** (2023→), Rust GUI | MML-based music + SFX driver with a live-preview editor; ca65 + 6502/generic integration APIs. The current community recommendation. |
| [SNESMOD](https://github.com/mukunda-/snesmod) | MIT *(per nesdoug; see repo LICENSING.txt)* | legacy/dormant, ~19★ | Plays Impulse Tracker modules + SFX streaming; SPC700 driver + `smconv` converter |
| [SNESGSS](https://github.com/nathancassano/snesgss) | open (unconfirmed) | dormant since 2017, ~121★ | Self-contained tracker + SPC700 driver; MIDI import; exports WLA-DX data. Fork: [snesgss-extended](https://github.com/NovaSquirrel/snesgss-extended) (Python exporter) |
| [Furnace](https://github.com/tildearrow/furnace) | GPL | active | Multi-system chiptune tracker that includes SNES/SPC700 export |

Because these are **driver-blob + data-format**, they integrate regardless of compiler: you `incbin` the SPC700
driver, ship the converted song/sample data, and poke the APU I/O ports to play. Our project hasn't touched
audio yet (flagged as future in the demo plan) — when it does, **integrating an existing driver beats writing
one**, and TAD is the modern pick.

## 4. Assemblers & asset tools  *(adjacent, but you'll use them)*

- **Assemblers:** [WLA-DX](https://github.com/vhelin/wla-dx) (multi-CPU, 65816 + SPC700), **ca65** (from
  [cc65](https://github.com/cc65/cc65); also a 6502 C compiler), [asar](https://github.com/RPGHacker/asar)
  (patch-oriented, popular in the SMW scene), [bass](https://github.com/ARM9/bass) (table-based, 65816 +
  SPC700), `64tass`, `xkas-plus`, Bisqwit's "Free SNES Assembler", `TASM`.
- **Asset converters:** [SuperFamiconv](https://github.com/Optiroc/SuperFamiconv) (tiles/palettes/tilemaps →
  binary), **BRRtools** (PCM → BRR samples). These emit raw binary and are **fully reusable by us** — they
  don't care that our compiler is llvm-mos; we'd `incbin`/DMA their output. (We hand-rolled tile/palette data
  in the Mandelbrot demo; SuperFamiconv is what a real asset pipeline would use.)
- **Engine example:** [unnamed-snes-engine](https://github.com/undisbeliever/unnamed-snes-engine) — a small
  top-down SNES game engine, useful as a structural reference.

## 5. The modern-LLVM corner (where this project sits)

| Effort | Status | Note |
|---|---|---|
| **`llvm-mos` (this project's base)** | active, production-ish | Real LLVM backend for the 6502 family; we add 65816 16-bit-accum (`+mos-a16`) + a SNES platform. The most mature modern-LLVM 65816 C path found. |
| [SNES-Dev](https://github.com/chorman0773/SNES-Dev) | early WIP | The only other LLVM+GNU C/C++/Rust SNES toolchain; libc + Rust API; no releases yet. |
| [llvm-to-snes](https://github.com/luizperes/llvm-to-snes) | research | LLVM IR → WLA-DX; demonstrates the idea, not a usable SDK. |
| `llvm-65816` (various) | experimental | Assorted attempts to teach upstream LLVM the 65816; none established. |

**Conclusion for the question "what should we reuse?":** there is **no open-source LLVM-based SNES C *library*
to adopt** — that gap is precisely what this project fills. What's worth borrowing from the ecosystem:
1. **API design & scope** from PVSnesLib (what a SNES C HAL should expose) for our rendering library.
2. **Runtime/DMA/SPC patterns** from libSFX as a correctness reference (rep/sep tracking, DMA upload, APU
   handshake) — it independently confirms the mechanics in our
   [rendering handoff](../handoffs/2026-06-24-snes-graphics-rendering.md).
3. **Asset tools** (SuperFamiconv, BRRtools) — directly usable now; they produce binary we DMA.
4. **An audio driver** (Terrific Audio Driver / SNESMOD) — drop-in for the sound side we haven't built.
5. **Keep an eye on SNES-Dev** — the only other modern-LLVM peer; possible cross-pollination on libc/ABI.

What is **not** worth adopting: the old C backends (`816-tcc`, `vbcc`, Calypsi) — replacing them with an
optimizing LLVM backend is the entire point of `llvm-mos-65816`.

---

## Sources
- [PVSnesLib (alekmaul/pvsneslib)](https://github.com/alekmaul/pvsneslib) · [docs](https://alekmaul.github.io/pvsneslib/)
- [libSFX (Optiroc/libSFX)](https://github.com/Optiroc/libSFX)
- [SNES-Dev (chorman0773/SNES-Dev)](https://github.com/chorman0773/SNES-Dev)
- [snes-sdk / tcc-65816 (nArnoSNES)](https://github.com/nArnoSNES/tcc-65816) · [optixx/snes-sdk](https://github.com/optixx/snes-sdk)
- [llvm-to-snes (luizperes)](https://github.com/luizperes/llvm-to-snes)
- [SNESMOD (mukunda-/snesmod)](https://github.com/mukunda-/snesmod) · [nesdoug SNESMOD writeup](https://nesdoug.com/2022/03/02/snesmod/)
- [SNESGSS (nathancassano/snesgss)](https://github.com/nathancassano/snesgss) · [snesgss-extended (NovaSquirrel)](https://github.com/NovaSquirrel/snesgss-extended)
- [Terrific Audio Driver (undisbeliever)](https://github.com/undisbeliever/terrific-audio-driver) · [author writeup](https://undisbeliever.net/blog/20231231-terrific-audio-driver.html)
- [NESdev SNES "Tools" wiki](https://snes.nesdev.org/wiki/Tools) · [NESdev "Audio drivers" wiki](https://snes.nesdev.org/wiki/Audio_drivers)
- [SuperFamiconv (Optiroc)](https://github.com/Optiroc/SuperFamiconv) · [WLA-DX (vhelin)](https://github.com/vhelin/wla-dx) · [cc65/ca65](https://github.com/cc65/cc65) · [asar (RPGHacker)](https://github.com/RPGHacker/asar)
