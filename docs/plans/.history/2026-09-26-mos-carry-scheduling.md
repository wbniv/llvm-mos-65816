| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/2871caab) | Validate carry scheduling through rebuilt upstream Clang |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/f7a1e06e) | Record carry-scheduling PR receipt and submission status |
| [2026-09-26](https://github.com/wbniv/llvm-mos-65816/commit/cbd1cd5b) | Publish computed-carry scheduler implementation and upstream PR packet |

<!--history-meta v1
2871caab	author	Will Norris
2871caab	added	37
2871caab	deleted	3
2871caab	files	1
2871caab	body	Build Clang at the exact PR parent and head, then retain 117 direct\nC-to-object comparisons across 6502, 65C02 and stock 65816. All machine\nverification passes; paired disassembly and objects excluding compiler\nversion metadata are identical. Archive commands, inputs, IR, logs,\nobjects, compiler identities and artifact hashes.\n\nCorrect the earlier fixed-IR census: its function CPU attributes pin\nall 117 paired invocations to 39 distinct 6502 configurations. Preserve\nthe original receipts and baseline evidence. Update current summaries,\nthe canonical observation, dependent views and substantive review receipts.\n\nPrepare the user-authorized PR body update with this full-pipeline result\nand remove public session IDs and unexplained internal follow-up names.\nIndependent review remains pending; no cycle or compile-time claim is made.\nPreserve the compact curation JSON layout.\n\nValidation and documentation: OpenAI Codex CLI 0.157.1,\nmodel gpt-6-astra, xhigh reasoning effort.
f7a1e06e	author	Will Norris
f7a1e06e	added	13
f7a1e06e	deleted	4
f7a1e06e	files	1
f7a1e06e	body	Commit the remaining 0064 publication records, exact destination delta,\nsubmitted description, plan and current trackers. Refresh generated views,\ndependency receipts and the document inventory. Preserve the tested\n7bd67c0ae4e8 baseline and identify 26d7c2c1eebf as a source recheck,\nwithout claiming a new-base rebuild or independent review.\n\nRecord that PR creation was unauthorized and that the user subsequently\ndirected leaving it open for review. This commit does not modify the PR.\nThe user has authorized committing and pushing these repository leftovers.\n\nDocumentation, receipt review and integration: OpenAI Codex CLI 0.157.1\n(codex-tui), model gpt-6-astra, xhigh reasoning effort; session metadata\nverified. Preserve the earlier recorded implementation and discovery credits.
cbd1cd5b	author	Will Norris
cbd1cd5b	added	449
cbd1cd5b	deleted	0
cbd1cd5b	files	1
cbd1cd5b	body	Retain downstream 0064, its canonical qualified pressure record, separate\ninherited farblit observation, corpus costs and immutable validation evidence.\nAdd only the carry patch/test to toolchain application and regeneration.\n\nInclude the standalone 7bd67c0ae4e8 upstream extraction and author review:\nten focused commands, 132 MOS suite passes and one unsupported test,\n512 Python-oracle vectors per compiler, and 117 neutral ordinary-MOS\ncomparisons. The targeted MIR kernel shrinks from 133 to 59 bytes.\nThe compiler commit 155e209c4cee is pushed to the llvm-mos fork branch.\nNo PR is opened; cycle and compiler-time claims remain unmeasured.\n\nPrepare this commit in an isolated worktree from b3938bda so the shared\ncheckout, other staged changes and unrelated PR packets are preserved.\nRefresh the scoped plans, original reports, current summaries and document\ndependency receipts. Preserve existing attribution and failing baselines.\n\nImplementation, extraction, author review, validation and publication:\nOpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning\neffort; verified session 01a0dd01-d72e-76f2-bf27-a796e0f7d994.\nOriginal downstream sum/rotate inputs and measurements: Claude Code\n2.1.278, model claude-opus-5, high reasoning effort; session\n65695418-7e9b-45bd-92e3-2ecfd88ecf0b, agent a35017d73ff4d881d.
-->
