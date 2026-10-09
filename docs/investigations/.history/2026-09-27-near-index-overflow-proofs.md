| Date | Change |
|------|--------|
| [2026-09-30](https://github.com/wbniv/llvm-mos-65816/commit/5dc63f4d) | Fix the near no-wrap pass option collision in 0002 |
| [2026-09-29](https://github.com/wbniv/llvm-mos-65816/commit/ad83cdcf) | Prepare near-index proof recovery for upstream review |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/6c5907b4) | Recover near-index proofs and record the null-output streamer repair |

<!--history-meta v1
5dc63f4d	author	Will Norris
5dc63f4d	added	1
5dc63f4d	deleted	1
5dc63f4d	files	1
5dc63f4d	body	MOSRecoverNearNoWrap registered its legacy pass argument under the same name as its -mos-recover-near-nowrap switch, so any opt containing the MOS target aborted at startup and five opt-based MOS lit tests failed. 0002 now carries the reviewed upstream extraction's pass: argument mos-near-nowrap-recovery via DEBUG_TYPE, ID-based insertion after LSR, a header for the ID, a data-layout index width and a proof-path debug line. The test gains an opt startup RUN line, and near-index-proofs-debug.ll pins each proof path in assertion builds.\n\nBefore the edit, a baseline regeneration from vendor reproduced the committed 0002 section for section; the regenerated patch changes only these files and round-trips. The preserved downstream opt exits 134 on verify.ll and the rebuilt one exits 0; downstream MOS suites pass 186 with 3 unsupported and no failures. The canonical record is closed as fixed.\n\nClaude Code 2.1.283, model Claude Opus 5.5 (claude-opus-5-5), xhigh reasoning effort; session f79adc39-72b4-4dc5-abc1-849c14c5ce96.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk
ad83cdcf	author	Will Norris
ad83cdcf	added	12
ad83cdcf	deleted	0
ad83cdcf	files	1
ad83cdcf	body	Extract the downstream MOSRecoverNearNoWrap pass onto llvm-mos/llvm-mos main 06bc967d2668. The series is the rebased #321 prerequisite, with changed lines identical to the reviewed 0065 patch 1, plus the pass and near-only tests. The packet records destination reconciliation, suites, red/green replay, a 412-input frozen-IR replay (1,045 pairs, net -69,616 B, 39 growths retained), 394/394 extracted-backend runtime checks on MAME and bsnes-jg, and independent review with its fixes.\n\nTwo new canonical defects: the pass argument in 0002 collides with its cl::opt so opt aborts at startup (repaired in the extraction, 0002 pending), and the #321 prerequisite's preserveX saves $p as defined after a call clobbered its flags. Update trackers, dashboard curation and generated views; remove the completed TODO item.\n\nExtraction, validation and records: Claude Code 2.1.283, model Claude Opus 5.5 (claude-opus-5-5), xhigh reasoning effort; session f79adc39-72b4-4dc5-abc1-849c14c5ce96. Independent review: Claude Code 2.1.283 subagent, model Claude Opus 5.5 (claude-opus-5-5), high reasoning effort.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01HAKZG571yi9zqmAeWQZVtk
6c5907b4	author	Will Norris
6c5907b4	added	52
6c5907b4	deleted	0
6c5907b4	files	1
6c5907b4	body	Preserve sound unsigned no-wrap facts immediately after LSR, allowing\nnear indexed accesses while retaining the bank-wrap guard. Carry the\npass and regressions in 0002, with baseline/candidate evidence, census\nrunners, current summaries, and regenerated documentation.\n\nThe census saves 33,159 bytes across 1,197 successful pairs; nine\nconfigurations grow and 39 fail in both arms. The preserved final\ncompiler matches all 1,236 census outcomes. Validation passes 183 MOS\ntests (two unsupported), 48 affected-program runtime checks, twelve\nnear-address checks, and the original gallery benchmark.\n\nInclude the previously staged 0068 null-output streamer patch and its\nmatching-input evidence, submission preview, and qualified downstream\nvalidation. Retain the staged document-dependency lookup cache and\nrelated documentation updates.\n\nNear-index implementation, validation, and commit preparation:\nOpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, high reasoning\neffort; verified session 01a0e315-89ed-7e70-b7dc-fcc2940366d9.\n\nEarlier null-output implementation attribution is preserved as recorded:\nOpenAI Codex agent via API; tool version, exact model name/ID and version,\nand reasoning effort unknown from its accessible session metadata.
-->
