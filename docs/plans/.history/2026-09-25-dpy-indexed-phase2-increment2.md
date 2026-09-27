| Date | Change |
|------|--------|
| [2026-09-26](https://github.com/wbniv/llvm-mos-65816/commit/cbd1cd5b) | Publish computed-carry scheduler implementation and upstream PR packet |
| [2026-09-26](https://github.com/wbniv/llvm-mos-65816/commit/a4eb416c) | MOS: fold range-proven runtime offsets into far [dp],Y |

<!--history-meta v1
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
