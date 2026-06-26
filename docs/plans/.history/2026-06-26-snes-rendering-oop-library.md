| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/d5c1448) | docs(snesgfx): plan an OOP-in-C SNES rendering library + improve oop-in-c |

<!--history-meta v1
d5c1448	author	Will Norris
d5c1448	added	349
d5c1448	deleted	0
d5c1448	files	1
d5c1448	body	Re-imagine the proven SNES rendering mechanics (force-blank/v-blank access\nwindow, DMA uploads, VRAM layout, Mode 7) as a header-only OOP-in-C library\n`snesgfx`, per the rendering handoff's "Recommended library shape" and the\noop-in-c HOWTO's grammar:\n\n- UploadQueue (the access-window rule in ONE place), VramAlloc bump allocator,\n  a Drawable vtable + heterogeneous Scene (the *justified* per-object vtable:\n  coarse dispatch, one call/drawable/frame, never per-tile), concrete\n  Mode7Layer/SpriteSet/BgLayer, and a selector-table joypad dispatch.\n- Header-only because dev/build.sh compiles every examples/snes/**/*.c as a\n  standalone program (matches mode7.h / the HAL).\n- Verified by a parallel client mandel-oop.c reproducing mandel-display.c's\n  CRC 0x204F (host==a16@MAME==a16@bsnes-jg), then MEASURED (disasm dispatch\n  count, OOP-vs-procedural size delta, JSR (abs,X) lowering) with the numbers\n  written back into oop-in-c.md SS4-5 (measure, don't assume).\n\noop-in-c.md gains: a dispatch-budget rule (one virtual call per drawable per\nframe, grounded in the already-measured SS4 cost) and a "heterogeneous scene of\ndrawables" recipe (the canonical justified-vtable case). TODO M2 entry added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
