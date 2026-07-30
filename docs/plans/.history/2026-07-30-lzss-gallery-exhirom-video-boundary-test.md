| Date | Change |
|------|--------|
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/1d48bb4) | docs(plan): ExHiROM video boundary test — review fixes, hud.h HUD amendment, mockups |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/97b1ce3) | docs: link ExHiROM video clip candidates |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/1ae32f8) | docs: plan ExHiROM video boundary test |

<!--history-meta v1
1d48bb4	author	Will Norris
1d48bb4	added	73
1d48bb4	deleted	23
1d48bb4	files	1
1d48bb4	body	Review-driven revision of the ExHiROM 48 Mbit video plan:\n\n- Mode 7 mechanics (normative): high-byte-only tile DMA ($2119, VMAIN=$80),\n  buffer flip as 70-entry tilemap rewrite (no Mode 7 tilemap base register),\n  index-0 transparency, write-twice register ordering, VBlank margin arithmetic.\n- Live UI per house practice: hud.h HDMA BGMODE/TM split bars (Mode 1 BG3 text)\n  in the letterbox bands; OBJ sprite badges only in stretch mode. Sprite CGRAM\n  moved to 224-255 (OBJ palettes 6-7, gallery convention), restoring the\n  contiguous 1-223 video palette; entry 1 pinned white as BG3 ink.\n- VRAM budget: BG3 map $4000 / font $5000 / OBJ $6000+.\n- Presentation: NTSC slip-never-tear lag policy, consumer CPU budget (fixture\n  frames only), end-of-reel loop + first-pass oracle latch, seek restricted to\n  raw slate boundaries.\n- Scope: canary matrix split into milestone-gating rows (HiROM 4 MiB, ExHiROM\n  6/8 MiB) vs deferred follow-up (LoROM matrix, SRAM, copier header, PAL);\n  5 MiB demoted to stretch fixture.\n- Verification converted to numbered command-anchored gates; exact CPU bank\n  ranges in the address-model diagram; mockup bundle added (boundary-slate\n  player states).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
97b1ce3	author	Will Norris
97b1ce3	added	182
97b1ce3	deleted	86
97b1ce3	files	1
1ae32f8	author	Will Norris
1ae32f8	added	608
1ae32f8	deleted	0
1ae32f8	files	1
-->
