| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/5167af8) | #321 native-mode crt0: SNES platform boots 65816 native mode |

<!--history-meta v1
5167af8	author	Will Norris
5167af8	added	188
5167af8	deleted	0
5167af8	files	1
5167af8	body	The snes crt0 .init.50 now does clc; xce + a 16-bit ldx #$01ff; txs\n(page-1 stack) + sep #$30 (8-bit A/X default), so every program runs in\n65816 native mode with the existing 8-bit code generator unchanged. The\nfour 65816-only opcodes are emitted as .byte (the SDK assembles crt0 for\nthe 6502). a16.c drops its 1a test-local clc; xce and still reads 0x0042\non both MAME and bsnes-jg, driven solely by the crt0.\n\nNon-breaking: corpus 7/7, far-run/far-bank1/xcheck all green in native\n8-bit mode. Platform-only change (no backend/patch). Enables all future\n16-bit codegen to run on the emulators without per-test mode entry.\n\nAlso update ROADMAP finding (a): native-mode crt0 landed, no longer\ndeferred.\n\nPlan: docs/plans/2026-06-14-321-native-mode-crt0.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
