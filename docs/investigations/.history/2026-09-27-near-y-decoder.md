| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/e370e031) | Fix near decoder Y lifetime and bank wrapping |

<!--history-meta v1
e370e031	author	Will Norris
e370e031	added	47
e370e031	deleted	0
e370e031	files	1
e370e031	body	Keep Imag16-indexed near byte and word accesses fused through register\nallocation and width insertion so an X8 reload cannot clear Y.high between\nthe index load and its use. Require proof that a near pointer addition\ncannot wrap before folding it into native indexed addressing, which can\notherwise carry a negative offset into DBR+1.\n\nPreserve the original gallery failure, isolate the two causal defects, and\nretain matching-input red/green evidence. Add permanent decoder and bank\nwrap runtime fixtures, refresh the installed compiler, and carry the source\nand focused tests in the round-tripped 0002 patch.\n\nRecord the user-requested withdrawal of PR #609 with its branch retained.\nUpdate current summaries and generated documentation while preserving dated\nevidence and the posted PR body. Compare compiler settings independently of\nthe observed result stored inside an immutable schema-1 baseline.\n\nValidation: original 62-work gallery returns 0x5CF0; all 12 width/LTO runtime\nconfigurations pass; MOS CodeGen/MC has 178 passes and two unsupported;\nindirect-word and X-index controls pass on MAME and bsnes-jg; 0002 source/test\nroundtrip passes; all 27 defect-evidence checker tests pass. Staged comment,\ndefect evidence, documentation dependency, and display checks pass.\n\nImplementation, investigation, validation and documentation: OpenAI Codex\nCLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified\nsession 01a0e061-3427-74a1-90ad-c0ee84b01b85. Earlier contributors retain their\nrecorded attribution in the preserved evidence.
-->
