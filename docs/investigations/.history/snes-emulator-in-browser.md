| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/61ce671) | investigation: can we run a SNES emulator on a web page? (yes — bsnes-jg is a libretro core → WASM) |

<!--history-meta v1
61ce671	author	Will Norris
61ce671	added	164
61ce671	deleted	0
61ce671	files	1
61ce671	body	Verdict report. Browser SNES emulation is mature (snes9x/bsnes-jg compile to WASM\nvia Emscripten, run our 32 KiB LoROM .sfc as-is). Key project angle: our exact\nsecond-leg gate emulator bsnes-jg is itself a libretro core, so a browser demo can\nrun the same cycle-accurate core the differential gate trusts. Recommends EmulatorJS\nfor a public showcase of the +mos-a16 demos (bsnes-jg core for accuracy + clean\nGPLv3 license vs snes9x's non-commercial terms); explicitly rejects a web emulator\nas a CI differential leg (same cores we already run natively → no new coverage).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
