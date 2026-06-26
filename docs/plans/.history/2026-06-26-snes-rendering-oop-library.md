| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/e9a8663) | docs(snesgfx): interface rule — objects + methods, no bare functions |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/d5c1448) | docs(snesgfx): plan an OOP-in-C SNES rendering library + improve oop-in-c |

<!--history-meta v1
e9a8663	author	Will Norris
e9a8663	added	121
e9a8663	deleted	57
e9a8663	files	1
e9a8663	body	Address review: snes_ppu_reset_blank() in the client is "not oop" — a\nreceiver-less HAL procedure. Rework the library so the public interface is\nobjects + methods only (no bare functions, except flagged application-content\ncompute + test-harness CRC):\n\n- New root Display object whose *constructor* owns the boot bracket\n  (snes_ppu_reset_blank + zero all PPU regs + release force-blank LAST — the\n  handoff's #1 determinism trap), and which owns the UploadQueue/VramAlloc/Scene\n  as private collaborators. The client holds one Display and calls methods;\n  display_frame() is the sole flush + force-blank-release site.\n- UploadQueue/VramAlloc demoted to INTERNAL collaborators; input.h -> a\n  Controller object (controller_poll) instead of a bare input_dispatch.\n- mandel-oop.c rewritten with zero bare graphics calls; P1 adds a\n  grep-for-snes_/REG_/upq_ "no bare functions" audit. Subsections renumbered\n  3a..3g; cross-refs fixed.\n- oop-in-c.md (Encapsulation): a clean object interface is constructors +\n  methods only — wrap a hardware bring-up invariant in the constructor so the\n  caller can't bypass the ordering. The principle behind the rework.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d5c1448	author	Will Norris
d5c1448	added	349
d5c1448	deleted	0
d5c1448	files	1
d5c1448	body	Re-imagine the proven SNES rendering mechanics (force-blank/v-blank access\nwindow, DMA uploads, VRAM layout, Mode 7) as a header-only OOP-in-C library\n`snesgfx`, per the rendering handoff's "Recommended library shape" and the\noop-in-c HOWTO's grammar:\n\n- UploadQueue (the access-window rule in ONE place), VramAlloc bump allocator,\n  a Drawable vtable + heterogeneous Scene (the *justified* per-object vtable:\n  coarse dispatch, one call/drawable/frame, never per-tile), concrete\n  Mode7Layer/SpriteSet/BgLayer, and a selector-table joypad dispatch.\n- Header-only because dev/build.sh compiles every examples/snes/**/*.c as a\n  standalone program (matches mode7.h / the HAL).\n- Verified by a parallel client mandel-oop.c reproducing mandel-display.c's\n  CRC 0x204F (host==a16@MAME==a16@bsnes-jg), then MEASURED (disasm dispatch\n  count, OOP-vs-procedural size delta, JSR (abs,X) lowering) with the numbers\n  written back into oop-in-c.md SS4-5 (measure, don't assume).\n\noop-in-c.md gains: a dispatch-budget rule (one virtual call per drawable per\nframe, grounded in the already-measured SS4 cost) and a "heterogeneous scene of\ndrawables" recipe (the canonical justified-vtable case). TODO M2 entry added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
