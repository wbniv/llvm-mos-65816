| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/e370e031) | Fix near decoder Y lifetime and bank wrapping |
| [2026-09-26](https://github.com/wbniv/llvm-mos-65816/commit/cbd1cd5b) | Publish computed-carry scheduler implementation and upstream PR packet |
| [2026-09-26](https://github.com/wbniv/llvm-mos-65816/commit/a4eb416c) | MOS: fold range-proven runtime offsets into far [dp],Y |

<!--history-meta v1
e370e031	author	Will Norris
e370e031	added	2
e370e031	deleted	0
e370e031	files	1
e370e031	body	Keep Imag16-indexed near byte and word accesses fused through register\nallocation and width insertion so an X8 reload cannot clear Y.high between\nthe index load and its use. Require proof that a near pointer addition\ncannot wrap before folding it into native indexed addressing, which can\notherwise carry a negative offset into DBR+1.\n\nPreserve the original gallery failure, isolate the two causal defects, and\nretain matching-input red/green evidence. Add permanent decoder and bank\nwrap runtime fixtures, refresh the installed compiler, and carry the source\nand focused tests in the round-tripped 0002 patch.\n\nRecord the user-requested withdrawal of PR #609 with its branch retained.\nUpdate current summaries and generated documentation while preserving dated\nevidence and the posted PR body. Compare compiler settings independently of\nthe observed result stored inside an immutable schema-1 baseline.\n\nValidation: original 62-work gallery returns 0x5CF0; all 12 width/LTO runtime\nconfigurations pass; MOS CodeGen/MC has 178 passes and two unsupported;\nindirect-word and X-index controls pass on MAME and bsnes-jg; 0002 source/test\nroundtrip passes; all 27 defect-evidence checker tests pass. Staged comment,\ndefect evidence, documentation dependency, and display checks pass.\n\nImplementation, investigation, validation and documentation: OpenAI Codex\nCLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified\nsession 01a0e061-3427-74a1-90ad-c0ee84b01b85. Earlier contributors retain their\nrecorded attribution in the preserved evidence.
cbd1cd5b	author	Will Norris
cbd1cd5b	added	10
cbd1cd5b	deleted	0
cbd1cd5b	files	1
cbd1cd5b	body	Retain downstream 0064, its canonical qualified pressure record, separate\ninherited farblit observation, corpus costs and immutable validation evidence.\nAdd only the carry patch/test to toolchain application and regeneration.\n\nInclude the standalone 7bd67c0ae4e8 upstream extraction and author review:\nten focused commands, 132 MOS suite passes and one unsupported test,\n512 Python-oracle vectors per compiler, and 117 neutral ordinary-MOS\ncomparisons. The targeted MIR kernel shrinks from 133 to 59 bytes.\nThe compiler commit 155e209c4cee is pushed to the llvm-mos fork branch.\nNo PR is opened; cycle and compiler-time claims remain unmeasured.\n\nPrepare this commit in an isolated worktree from b3938bda so the shared\ncheckout, other staged changes and unrelated PR packets are preserved.\nRefresh the scoped plans, original reports, current summaries and document\ndependency receipts. Preserve existing attribution and failing baselines.\n\nImplementation, extraction, author review, validation and publication:\nOpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning\neffort; verified session 01a0dd01-d72e-76f2-bf27-a796e0f7d994.\nOriginal downstream sum/rotate inputs and measurements: Claude Code\n2.1.278, model claude-opus-5, high reasoning effort; session\n65695418-7e9b-45bd-92e3-2ecfd88ecf0b, agent a35017d73ff4d881d.
a4eb416c	author	Will Norris
a4eb416c	added	572
a4eb416c	deleted	0
a4eb416c	files	1
-->
