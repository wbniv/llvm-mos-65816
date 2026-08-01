| Date | Change |
|------|--------|
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/d71d298) | Add animated SVX2 video cartridge |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/ac773f4) | docs(plan): record Phase 0-1 verification — host structural gates 1 and 2 PASS |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/6d50fd3) | docs(plan+todo): reframe extended-cartridge work — general mapper testing, standalone ROMs; rename plan |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/e5dcc03) | docs(plan): ExHiROM video — codec selection: interframe block codec over LZSS-by-default |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/1d48bb4) | docs(plan): ExHiROM video boundary test — review fixes, hud.h HUD amendment, mockups |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/97b1ce3) | docs: link ExHiROM video clip candidates |
| [2026-07-30](https://github.com/wbniv/llvm-mos-65816/commit/1ae32f8) | docs: plan ExHiROM video boundary test |

<!--history-meta v1
d71d298	author	Will Norris
d71d298	added	102
d71d298	deleted	8
d71d298	files	1
ac773f4	author	Will Norris
ac773f4	added	101
ac773f4	deleted	0
ac773f4	files	1
ac773f4	body	Gate 1 (implemented as `dev/run.sh cartsize-canary`; the video script is Phase 2\nand the plan permits refining gate names) and gate 2 (`snes-checksum.py\n--inspect`) recorded in the house format: original step text kept verbatim, raw\noutput beneath, PASS/FAIL note.\n\nAll three milestone configurations pass on bsnes-jg — HiROM 4 MiB (oracle\n$48EE), ExHiROM 6 MiB ($A274) and ExHiROM 8 MiB ($29B9) — with canary_status\n$0000 in each. Gate 2 confirms the 6 MiB image is exactly 6,291,456 bytes,\ndecomposes as exactly 32 Mbit + 16 Mbit, carries its header only at $40FFB0\n(bsnes-jg heuristic scores exhirom=16 and lorom/hirom/exlorom 0, so there is no\ndecoy header), maps mode $25, resets into linked code at file $408000 (first\nopcode $78 = sei), and checksums identically under two independent computations.\n\nTwo limits are recorded rather than glossed: MAME could not run at all on this\nmachine (no SPC700 IPL at dev/roms/s_smp — the gate falls back to JG_ONLY, so\nthe emulator evidence is bsnes-jg only), and coprocessor-cartridge rejection is\nproven by host fixtures rather than generated ROMs.\n\nImplementation is on branch feature/exhirom-canaries (a2355fb, 3e80748), rebased\nonto this commit's parent and not yet merged.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
6d50fd3	author	Will Norris
6d50fd3	added	810
6d50fd3	deleted	0
6d50fd3	files	1
6d50fd3	body	The ExHiROM work is general cartridge/mapper test coverage via three\nstandalone size-test ROMs (HiROM 4 MiB; ExHiROM 6/8 MiB), not driven by\ngallery size — gallery integration is a later optional phase. Rename the\nplan (and its mockup bundle) from 2026-07-30-lzss-gallery-exhirom-video-\nboundary-test to 2026-07-30-exhirom-video-boundary-test; retitle; update\nall live references (TODO links incl. the Inbox fingerprint bullet, in-plan\nbundle links, planned fixture filenames exhirom-video.c / exhirom-video.sh).\nAlso record the lsystem detector-fix adoption commit (5587462) in its TODO\nbullet.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
e5dcc03	author	Will Norris
e5dcc03	added	0
e5dcc03	deleted	0
e5dcc03	files	0
e5dcc03	body	Review follow-up: LZSS is intraframe-only and ignores temporal redundancy,\nthe dominant compression opportunity in this footage. Add a Codec selection\nsection: 7-candidate benchmark ladder (raw / RLE / XOR+RLE / changed-block\nvariants / LZSS as comparison only), the expected-winner interframe 8x8\nblock codec (skip / motion copy / solid / two-color / XOR-RLE / raw),\ndouble-buffered WRAM framebuffer decode, and the constraint that the\nWRAM->VRAM path must not displace the raw-from-ROM segmented DMA mapping\ngates. The reel's LZSS-refill consumer is a mapping fixture, not a codec\nendorsement.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
1d48bb4	author	Will Norris
1d48bb4	added	0
1d48bb4	deleted	0
1d48bb4	files	0
1d48bb4	body	Review-driven revision of the ExHiROM 48 Mbit video plan:\n\n- Mode 7 mechanics (normative): high-byte-only tile DMA ($2119, VMAIN=$80),\n  buffer flip as 70-entry tilemap rewrite (no Mode 7 tilemap base register),\n  index-0 transparency, write-twice register ordering, VBlank margin arithmetic.\n- Live UI per house practice: hud.h HDMA BGMODE/TM split bars (Mode 1 BG3 text)\n  in the letterbox bands; OBJ sprite badges only in stretch mode. Sprite CGRAM\n  moved to 224-255 (OBJ palettes 6-7, gallery convention), restoring the\n  contiguous 1-223 video palette; entry 1 pinned white as BG3 ink.\n- VRAM budget: BG3 map $4000 / font $5000 / OBJ $6000+.\n- Presentation: NTSC slip-never-tear lag policy, consumer CPU budget (fixture\n  frames only), end-of-reel loop + first-pass oracle latch, seek restricted to\n  raw slate boundaries.\n- Scope: canary matrix split into milestone-gating rows (HiROM 4 MiB, ExHiROM\n  6/8 MiB) vs deferred follow-up (LoROM matrix, SRAM, copier header, PAL);\n  5 MiB demoted to stretch fixture.\n- Verification converted to numbered command-anchored gates; exact CPU bank\n  ranges in the address-model diagram; mockup bundle added (boundary-slate\n  player states).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
97b1ce3	author	Will Norris
97b1ce3	added	0
97b1ce3	deleted	0
97b1ce3	files	0
1ae32f8	author	Will Norris
1ae32f8	added	0
1ae32f8	deleted	0
1ae32f8	files	0
-->
