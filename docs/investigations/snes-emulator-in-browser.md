# INVESTIGATION — running a SNES emulator on a web page

**Question (user, 2026-06-25):** *Can we run a Super Nintendo emulator on a web page?*

**Verdict: Yes — unambiguously, and with a path that reuses *this project's exact reference
emulator*.** SNES emulation in the browser is mature: the standard SNES cores (snes9x, bsnes /
bsnes-jg) compile to **WebAssembly via Emscripten** and run at full 60 fps on any modern
laptop or phone. The 32 KiB LoROM `.sfc` files this toolchain produces load directly — drag-drop
or a `data-rom` attribute — with no conversion.

The project-specific payoff: **`bsnes-jg`, the cycle-accurate core we already run as the second
leg of the differential gate, is itself a libretro core** ([`libretro/bsnes-jg`](https://github.com/libretro/bsnes-jg)),
and libretro cores are exactly what the browser ports build. So a browser demo can run **the same
PPU/CPU core the gate verifies against**, not a lookalike.

---

## TL;DR

| | What | Effort | Accuracy vs our gate | License |
|---|------|--------|----------------------|---------|
| **Quick demo** | [EmulatorJS](https://emulatorjs.org) embed, `snes9x` core | ~5 lines HTML + host the ROM | High compat, **not** cycle-accurate | snes9x = **non-commercial** (not OSI-free) |
| **Gate-matched demo** | EmulatorJS `bsnes` core, or [`libretro/bsnes-jg`](https://github.com/libretro/bsnes-jg) built with Emscripten | + one Emscripten core build | **Cycle-accurate — same family as our `bsnes-jg` leg** | bsnes-jg = **GPLv3** (clean for us) |
| **Full frontend** | [webretro](https://github.com/BinBashBanana/webretro) (RetroArch-in-browser, ships Snes9x) | drop-in, heavier UI | snes9x | RetroArch GPLv3 + snes9x core |
| **CI third leg** | run a wasm core headless under Node | medium | **same cores we already run natively** → no new coverage | — |

**Recommendation:** for a public showcase of the `+mos-a16` homebrew ROMs (the Mandelbrot
zoom/Mode-7 demos), use **EmulatorJS** — minimal embed, host on the project's Cloudflare static
stack, point it at a `.sfc`. If "what you run in the browser is byte-for-byte the core the gate
trusts" matters for credibility, spend the extra step to ship a **bsnes-jg** WASM build instead
of snes9x (also the cleaner license — see below). **Do *not*** add a web emulator as a CI
differential leg: it runs the *same* cores we already test natively (MAME + bsnes-jg), only
slower and harder to drive headless — zero new coverage (Lesson 3: redundant infra is not a gain).

---

## How browser SNES emulation works

Three layered approaches, easiest → most control:

1. **EmulatorJS** — a thin web frontend that loads prebuilt libretro cores (RetroArch compiled to
   WASM). SNES is a first-class system; it exposes **two cores: `snes9x` (default) and `bsnes`**
   ([systems/snes](https://emulatorjs.org/docs/systems/snes)). Minimal embed:

   ```html
   <div id="game"></div>
   <script>
     EJS_player    = '#game';
     EJS_core      = 'snes';              // snes9x; or set per-core to bsnes
     EJS_gameUrl   = 'mandel-zoom.sfc';   // our 32 KiB LoROM, served as-is
     EJS_pathtodata = 'data/';
   </script>
   <script src="data/loader.js"></script>
   ```

   Real keyboard/gamepad input comes free — directly useful for the **interactive** demos
   (`examples/snes/mandel-interactive.c`), which today only get *scripted* input through the gate.

2. **webretro** — full RetroArch UI in the browser; ships a prebuilt **Snes9x** core
   ([BinBashBanana/webretro](https://github.com/BinBashBanana/webretro), live at
   [binbashbanana.github.io/webretro](https://binbashbanana.github.io/webretro/)). More UI than a
   showcase needs, but a working reference for how the cores are packaged.

3. **Raw libretro core + your own loader** — build any libretro core with the Emscripten SDK
   (RetroArch documents the toolchain: [`pkg/emscripten`](https://github.com/libretro/RetroArch/tree/master/pkg/emscripten),
   EmulatorJS documents [building raw cores](https://emulatorjs.org/docs4devs/buildingraw/)). This
   is the route to a **bsnes-jg** WASM build — see below.

---

## Why bsnes-jg-in-browser is the interesting option *for us*

Our vendored `vendor/bsnes-jg` is the **Jolly Good fork** ([gitlab.com/jgemu/bsnes](https://gitlab.com/jgemu/bsnes),
GPLv3 — `vendor/bsnes-jg/COPYING`), wrapped for libretro as
[`libretro/bsnes-jg`](https://github.com/libretro/bsnes-jg). Because the browser ports *are*
libretro-core ports, the same core that backs the gate's second leg (`build/jgxcheck` →
`vendor/bsnes-jg`) can be compiled to WASM with Emscripten and run on a web page.

Consequence: a "run the demo in your browser" page backed by bsnes-jg-wasm would be displaying the
output of **the same cycle-accurate core whose WRAM/framebuffer the differential gate already
asserts against** (`docs/investigations/snes-emulator-screenshots.md` documents how we read its
framebuffer headless). snes9x, by contrast, is high-compatibility but *not* cycle-accurate
([Emulation General](https://emulation.gametechwiki.com/index.php/Snes9x)) — fine for a casual
demo, but it is not the thing the gate trusts.

The bsnes-jg WASM build is not turnkey (no prebuilt bsnes-jg core in webretro/EmulatorJS today —
both ship snes9x; EmulatorJS's `bsnes` slot is the mainline bsnes core, a close cousin). It's an
Emscripten build of `libretro/bsnes-jg`, then loaded via EmulatorJS's custom-core mechanism or a
hand-rolled loader. A bounded, one-time job — not research.

---

## Licensing — clean for an open-source project, with one trap

| Core | License | Implication for a public demo page |
|------|---------|-----------------------------------|
| **bsnes / bsnes-jg** | **GPLv3** (`vendor/bsnes-jg/COPYING`) | Fine. Publish the WASM build's source (we already vendor the C++). Aligns with the gate. |
| **EmulatorJS** | GPLv3 | Fine, same terms. |
| **snes9x** | **Non-commercial** — *"commercial users should seek permission"*, **GPL-incompatible** ([snes9x LICENSE](https://github.com/snes9xgit/snes9x/blob/master/LICENSE), [Emulation General](https://emulation.gametechwiki.com/index.php/Snes9x)) | Usable for a non-commercial project demo, but it is **not OSI-free** and won't combine with GPL cores. |

For this project — open-source, GPL-comfortable, and wanting "the browser shows what the gate
verified" — **bsnes-jg (GPLv3) is both the accuracy-matched *and* the license-clean choice.** It's
a point in favour of spending the extra Emscripten-build step rather than defaulting to snes9x.

(Note: bsnes-jg is only ever a *test/demo harness* here — it is never linked into the compiler, so
its GPLv3 does not touch the LLVM tree's Apache-2.0-with-LLVM-exception licensing.)

---

## Hosting requirements (the one real gotcha)

- **Single-threaded WASM works on any plain static host** (Cloudflare Pages, GitHub Pages, S3).
  SNES is light enough that single-threaded runs full speed — no special server config needed.
- **Multithreaded WASM** (used by some core builds for a perf margin) needs the page to be
  **cross-origin isolated**: serve the two headers
  `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`
  ([web.dev: WASM threads](https://web.dev/articles/webassembly-threads),
  [Emscripten pthreads](https://emscripten.org/docs/porting/pthreads.html)). Emscripten builds
  **fall back to single-threaded automatically** when the headers are absent — graceful
  degradation, not a hard failure. On Cloudflare Pages this is a two-line `_headers` file; the
  project already uses the Cloudflare static stack (`cloudflare-static-site` skill), so it's trivial
  if we ever want threads.
- **HTTPS** is required for threaded/SharedArrayBuffer builds; a CDN-served static site already
  satisfies this.

---

## What this is good for here (and what it isn't)

**Good for — a showcase.** A page where anyone runs the `+mos-a16` demos (Mandelbrot zoom pyramid,
Mode-7 DMA, the interactive viewer) **with no install**, real input, on desktop or phone. That is a
genuinely compelling way to demonstrate the toolchain on the project site, and the ROMs are already
the right artifact (32 KiB LoROM `.sfc`, load as-is).

**Not good for — a fourth differential leg.** The browser cores *are* snes9x and bsnes(-jg) — the
exact emulators we already run natively in the gate (MAME + bsnes-jg), which are faster and far
easier to drive headless for byte-level WRAM assertions. A web leg adds latency and flakiness for
**no new coverage**. Keep the correctness gate native; keep the browser strictly for show.

---

## Status — became a standalone project (2026-06-25)

The showcase was wanted. It now lives as its own repo, **`~/bsnes-jg-wasm`** (named for the
artifact: the WASM build of the gate's cycle-accurate core). Kept separate from this LLVM tree so
its GPLv3 publish story doesn't entangle the Apache-2.0-w/-LLVM-exception compiler. Scaffolded with
a reproducible Emscripten build pipeline (`build.sh`), an EmulatorJS loader page (showcase mode
serves today), `serve.py`, the demo ROMs, GPLv3 `LICENSE`/`NOTICE`, and its own
plan + TODO. See `~/bsnes-jg-wasm/docs/plans/2026-06-25-bsnes-jg-wasm.md`.

Remaining headline work (in that repo's TODO): build the `bsnes-jg` core pinned to *our*
`vendor/bsnes-jg` revision, wire the page to it, and prove the in-browser framebuffer CRC ==
this gate's headless `jgxcheck` CRC (`0x9103` for `mandel-display`) — i.e. literally "the same
core the gate trusts."

---

## Sources

- [EmulatorJS — supported systems / SNES](https://emulatorjs.org/docs/systems/snes) · [building raw cores](https://emulatorjs.org/docs4devs/buildingraw/)
- [webretro — RetroArch in the browser](https://github.com/BinBashBanana/webretro) · [live instance](https://binbashbanana.github.io/webretro/)
- [`libretro/bsnes-jg` core](https://github.com/libretro/bsnes-jg) · upstream [gitlab.com/jgemu/bsnes](https://gitlab.com/jgemu/bsnes)
- [RetroArch Emscripten packaging](https://github.com/libretro/RetroArch/tree/master/pkg/emscripten)
- [Emscripten pthreads / cross-origin isolation](https://emscripten.org/docs/porting/pthreads.html) · [web.dev: using WASM threads](https://web.dev/articles/webassembly-threads)
- [snes9x LICENSE (non-commercial)](https://github.com/snes9xgit/snes9x/blob/master/LICENSE) · [Emulation General: Snes9x accuracy/license](https://emulation.gametechwiki.com/index.php/Snes9x)
- [Emulation General: emulators in browsers](https://emulation.gametechwiki.com/index.php/Emulators_on_browsers)
- Local: `vendor/bsnes-jg/COPYING` (GPLv3), `vendor/bsnes-jg/README` (Jolly Good fork of bsnes v115), `docs/investigations/snes-emulator-screenshots.md` (headless framebuffer capture)
