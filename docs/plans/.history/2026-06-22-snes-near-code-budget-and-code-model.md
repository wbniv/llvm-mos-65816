| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/5d682b0) | docs(plans): SNES near-code budget assertion + #320 near/far code-model framing (planned) |

<!--history-meta v1
5d682b0	author	Will Norris
5d682b0	added	145
5d682b0	deleted	0
5d682b0	files	1
5d682b0	body	Answers 'should we add a compiler mode that limits codegen to 64k (32k on SNES)?':\nnear is already the default + far is per-symbol opt-in, so no -mcmodel mode; the\nreal gap is link-time enforcement of the LoROM near window. Plan + TODO entry; no\ncode/linker change yet (implementation is a gated later step).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
