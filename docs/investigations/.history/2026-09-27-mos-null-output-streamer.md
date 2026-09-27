| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/6c5907b4) | Recover near-index proofs and record the null-output streamer repair |

<!--history-meta v1
6c5907b4	author	Will Norris
6c5907b4	added	13
6c5907b4	deleted	0
6c5907b4	files	1
6c5907b4	body	Preserve sound unsigned no-wrap facts immediately after LSR, allowing\nnear indexed accesses while retaining the bank-wrap guard. Carry the\npass and regressions in 0002, with baseline/candidate evidence, census\nrunners, current summaries, and regenerated documentation.\n\nThe census saves 33,159 bytes across 1,197 successful pairs; nine\nconfigurations grow and 39 fail in both arms. The preserved final\ncompiler matches all 1,236 census outcomes. Validation passes 183 MOS\ntests (two unsupported), 48 affected-program runtime checks, twelve\nnear-address checks, and the original gallery benchmark.\n\nInclude the previously staged 0068 null-output streamer patch and its\nmatching-input evidence, submission preview, and qualified downstream\nvalidation. Retain the staged document-dependency lookup cache and\nrelated documentation updates.\n\nNear-index implementation, validation, and commit preparation:\nOpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, high reasoning\neffort; verified session 01a0e315-89ed-7e70-b7dc-fcc2940366d9.\n\nEarlier null-output implementation attribution is preserved as recorded:\nOpenAI Codex agent via API; tool version, exact model name/ID and version,\nand reasoning effort unknown from its accessible session metadata.
-->
