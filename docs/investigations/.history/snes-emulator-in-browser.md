| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/6d1d88f) | investigation: link the SNES-in-browser verdict to its standalone project |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/61ce671) | investigation: can we run a SNES emulator on a web page? (yes — bsnes-jg is a libretro core → WASM) |

<!--history-meta v1
6d1d88f	author	Will Norris
6d1d88f	added	13
6d1d88f	deleted	10
6d1d88f	files	1
6d1d88f	body	The showcase was wanted: it became ~/SRC/bsnes-jg-wasm (the WASM build of the\ngate's cycle-accurate bsnes-jg core + an EmulatorJS loader for the +mos-a16 demos),\nkept a separate repo so its GPLv3 story stays out of the LLVM tree. Updated the\n'next step' section to point there + name the headline CRC-match verification.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
61ce671	author	Will Norris
61ce671	added	164
61ce671	deleted	0
61ce671	files	1
61ce671	body	Verdict report. Browser SNES emulation is mature (snes9x/bsnes-jg compile to WASM\nvia Emscripten, run our 32 KiB LoROM .sfc as-is). Key project angle: our exact\nsecond-leg gate emulator bsnes-jg is itself a libretro core, so a browser demo can\nrun the same cycle-accurate core the differential gate trusts. Recommends EmulatorJS\nfor a public showcase of the +mos-a16 demos (bsnes-jg core for accuracy + clean\nGPLv3 license vs snes9x's non-commercial terms); explicitly rejects a web emulator\nas a CI differential leg (same cores we already run natively → no new coverage).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
