| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/c9cfa6a) | SNES near-code budget: enforce the near window as a link-time contract |
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/5d682b0) | docs(plans): SNES near-code budget assertion + #320 near/far code-model framing (planned) |

<!--history-meta v1
c9cfa6a	author	Will Norris
c9cfa6a	added	29
c9cfa6a	deleted	5
c9cfa6a	files	1
c9cfa6a	body	Answers "should there be a -mcmodel-style mode that limits codegen to 64k/32k?"\n-> no: near (JSR/RTS, CodeModel::Small, 2-byte fn ptr) is already the default\nand far is per-symbol opt-in, so such a mode describes the status quo and buys\nno codegen win. The real gap was the *guarantee*.\n\nPart A (linker-script only, no vendor/ rebuild): platforms/snes/link.ld and\nsnes-far/link.ld carve the fixed cartridge header + vectors into their own\n`romhdr` MEMORY region ($FFB0-$FFFF) so the `rom` region's LENGTH IS the true\nnear-code budget ($8000-$FFAF = 0x7FB0 = 32688 B). An over-budget link now fails\nwith a clear "section '.rodata' will not fit in region 'rom': overflowed by N\nbytes" instead of an obscure .snes_header overlap.\n\nVerified:\n- Output-neutral: 7 snes corpus ROMs + 5 snes-far ROMs byte-identical pre/post\n  carve (0 diffs); 0x7FB0 + 0x0050 = 0x8000 reproduces the bytes via FULL().\n- corpus 7/7; far suite PASS (far-bank1/far-run/far_call/far_store/far_arith ==\n  0xF3, byte-identical).\n- Overflow probe (0x8000-byte const array via a volatile index so -Os can't\n  fold/gc it) -> "region 'rom' overflowed by 206 bytes".\n- far_near_call FAILS but is PRE-EXISTING on clean main HEAD (proven by stashing\n  the carve + rebuilding -> identical jsr near_helper, not jsl\n  __call_near_from_far; a link script can't change instruction selection).\n  Unrelated codegen issue, out of scope.\n\nPart B (docs): a "Code model: near vs far" section in the #320 upstream note\n(near=small/default, far=medium/large/per-symbol -> no -mcmodel; the near window\nis bank geometry enforced at link time) + a pointer in\nupstream-contribution-status. TODO item closed.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
5d682b0	author	Will Norris
5d682b0	added	145
5d682b0	deleted	0
5d682b0	files	1
5d682b0	body	Answers 'should we add a compiler mode that limits codegen to 64k (32k on SNES)?':\nnear is already the default + far is per-symbol opt-in, so no -mcmodel mode; the\nreal gap is link-time enforcement of the LoROM near window. Plan + TODO entry; no\ncode/linker change yet (implementation is a gated later step).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
