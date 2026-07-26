| Date | Change |
|------|--------|
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/d473127) | docs(upstream): 0017 is series content, not a postable artifact — state the fold principle |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/f71ecd3) | docs(upstream): 0016 issue+PR bodies drafted; PRs link live SNES proof demos (standing rule) |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/9596038) | docs(upstream): submission campaign plan + status refresh — NOTHING posted |

<!--history-meta v1
d473127	author	Will Norris
d473127	added	1
d473127	deleted	1
d473127	files	1
d473127	body	User question exposed the smell: fixes to our OWN fork features (0017 s64 glue,\n0009, 0014, zp-alloc Imag32, the xy16 REP/SEP fix already inside 0002) must\nnever be presented upstream as separate introduce-then-fix patches. They exist\nas separate numbered files only for fork-workflow reasons (append-only stack,\nper-patch provenance/bisection); the 2026-07-26 regen already folded their\ncontent into 0002, so the Wave-5 series presents finished features. Status-doc\nrow 14 reclassified out of the postable set; campaign plan states the principle.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f71ecd3	author	Will Norris
f71ecd3	added	16
f71ecd3	deleted	1
f71ecd3	files	1
f71ecd3	body	User-directed: every PR body now links the playable biohack.net demo(s) that\nexercise its fix — the in-browser bsnes-jg pages re-run the WRAM self-check\nlive, so a maintainer can poke the 'soak-tested' claim in seconds. Campaign\nplan protocol gains the standing step + the full artifact->demo URL map\n(verified live; the four newest demos are top-level, not /snes/).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
9596038	author	Will Norris
9596038	added	134
9596038	deleted	0
9596038	files	1
9596038	body	The user wants to start pushing the upstream queue (2 PRs already merged:\n#562, #563 — our first two, landed essentially as submitted). This is the\ndocs-only groundwork for their review; per the explicit instruction, NO PRs,\nissues, or branch pushes happen until each item is individually green-lit.\n\nNew: docs/plans/2026-07-26-upstream-submission-campaign.md — wave-ordered\nposting sequence (standalone PRs -> issues -> a16-reachable judgment calls ->\nABI design notes -> the #320/#321 series) + the per-submission mechanical\nprotocol that replaces the retired regen scripts, + hard guardrails. Folds in\nthe pre-existing presentation layer (review guide, LLVM primer,\ndev/upstream-status.sh — 2026-06-24 plan) and marks the superseded scavenger\nissue doc + the retracted LTO-bitmask issue as do-not-post.\n\nFresh verified state (git ls-remote — gh unauthenticated here):\n  - llvm-mos/main tip is STILL 8be054612 == our rebase base, so the stack is\n    verified against the CURRENT tip;\n  - per-artifact `git apply --check` vs pristine tip: 0010/0011/0012/0015/0016\n    ALL clean (the stale-base concern is moot for every Wave-1/3 artifact;\n    only 0017 needs 0002 context and rides #321);\n  - fork branches: merged-PR branches deleted post-merge (normal); main stale\n    at c798c3141 (optional FF at posting time); mos-dwarf-65816-test-docs\n    active.\n\nupstream-contribution-status.md: new Last-updated lead, TL;DR recounted by\nwave, hygiene bullet re-verified, ls-remote snapshot appended.\nReview guide Appendix D: #562/#563 rows flipped POSTED->MERGED with their\nupstream commits and the on-merge action recorded as executed; last-verified\nnote updated with the apply-check results + campaign pointer.\nTODO: campaign item added at the head of Upstream / Contribution, marked\nAWAITING USER REVIEW.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
