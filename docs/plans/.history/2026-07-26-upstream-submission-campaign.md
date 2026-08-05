| Date | Change |
|------|--------|
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/5994dab) | upstream(wave-1): COMPLETE — 0010 posted as PR #578, DWARF step-6 as PR #579 |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/efe7ef4) | upstream(0010): staged — red/green proven, mos-coalesce-rotate-ac minted locally |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/ff79af7) | upstream(0016): POSTED — G_SCMP/G_UCMP legalization live as issue #576 + PR #577 |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/3b105d6) | docs(upstream): DWARF branch cherry-picks clean onto 8b616af94 — Wave 1 item 3 unblocked |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/a460184) | docs(upstream): re-verify campaign against moved tip 8b616af94 (lld-only commit) |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/dc4be9a) | docs(campaign): canonicalize demo URLs to /snes/<slug>/; verify-at-posting rule |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/1ead2ab) | upstream(0016): red/green proven at tip, branch pushed, artifact gains the lit test |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/d473127) | docs(upstream): 0017 is series content, not a postable artifact — state the fold principle |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/f71ecd3) | docs(upstream): 0016 issue+PR bodies drafted; PRs link live SNES proof demos (standing rule) |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/9596038) | docs(upstream): submission campaign plan + status refresh — NOTHING posted |

<!--history-meta v1
5994dab	author	Will Norris
5994dab	added	13
5994dab	deleted	4
5994dab	files	1
5994dab	body	User-triggered ('finish wave 1; post items 2 and 3'): pushed\nmos-coalesce-rotate-ac (18244924b3d3) and opened PR #578 (body = drafted doc\nminus H1/preamble, four live-demo links); assembled the DWARF PR body from\nthe drafted companion note (status/metadata/Title/Posting stripped, test-half\nlead added) and opened PR #579 from mos-dwarf-65816-test-docs (0ae9415).\nWave 1 now fully live: issue #576 + PRs #577/#578/#579, all OPEN per\ndev/upstream-status.sh. Status doc rows, campaign plan checklist, TODO\ncampaign item, and both body-doc preambles flipped to posted. Next: Wave 2\nissues (reentrant, rc-undef-ra, sdk setjmp) — user-triggered.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
efe7ef4	author	Will Norris
efe7ef4	added	13
efe7ef4	deleted	0
efe7ef4	files	1
efe7ef4	body	RED: coalesce-rotate-ac.mir FAILS on the unfixed pristine llc (COPY coalesced\naway). GREEN: official llvm-lit PASS 100% after applying 0010 + incremental\nrebuild (build/upstream-llc reused). Branch minted in vendor/llvm-mos @\n18244924b3d3 (cut from 8be054612, same base as 0016); upstream-src restored\nclean. Push blocked by the permission layer per the no-outward-actions\nguardrail — push + gh pr create are the user trigger (commands atop the PR\nbody doc, which now carries the four live-demo links, verified 200).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ff79af7	author	Will Norris
ff79af7	added	6
ff79af7	deleted	2
ff79af7	files	1
ff79af7	body	Campaign Wave 1 item 1 executed after the user authed gh (wbniv): issue\nllvm-mos/llvm-mos#576 (spaceship-comparator backend abort, minimal repro,\nlive demo links) + PR #577 from wbniv:mos-scmp-ucmp-legalize (one-line\n.lower() fix + scmp-ucmp.ll lit test, Fixes #576). Live gh snapshot via\ndev/upstream-status.sh: #577/#576 OPEN; #562 merged 2026-07-05, #563 merged\n2026-07-13. Status doc, campaign plan checkbox, TODO campaign item, and both\nbody-doc preambles flipped drafted -> posted. Next user-triggered: Wave 1\nitem 2 (0010, branch to mint) / item 3 (DWARF, postable as-is).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3b105d6	author	Will Norris
3b105d6	added	5
3b105d6	deleted	4
3b105d6	files	1
3b105d6	body	Live check: 0ae9415 (Writer.cpp doc comment + dwarf-65816.ll test) auto-merges\nonto the new tip despite #567's Writer.cpp changes. All three Wave-1 items now\nverified against the current tip; posting blocked on gh auth only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
a460184	author	Will Norris
a460184	added	12
a460184	deleted	0
a460184	files	1
a460184	body	Tip moved 8be054612 -> 8b616af94 (one commit: lld/ELF .debug_frame GC, #567,\nno MOS-backend files). All five Wave-1/3 artifacts (0010/0011/0012/0015/0016)\nre-verified git-apply-clean at the new tip; 0016 branch has no overlap with\n#567 so the staged PR merges clean. DWARF branch needs a cherry-pick re-check\n(#567 touches lld/ELF/Writer.cpp). Demo links re-verified 200. Posting still\nblocked on gh auth only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
dc4be9a	author	Will Norris
dc4be9a	added	8
dc4be9a	deleted	5
dc4be9a	files	1
dc4be9a	body	Gallery reorg (in flight today) normalized all demos under /snes/ — the four\nnewest now serve there too (top-level still answers, mid-migration). Map\nupdated to the canonical form, all 16 re-verified HTTP 200. Standing rule\nsharpened: re-verify every demo link live immediately before pasting into a\nPR body; never post a cached link. The 0016 bodies already used /snes/ forms\n(all five re-verified 200) — unchanged.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
1ead2ab	author	Will Norris
1ead2ab	added	12
1ead2ab	deleted	7
1ead2ab	files	1
1ead2ab	body	RED on pristine 8be054612: LLVM ERROR unable to legalize G_SCMP (exact line in\nthe issue body). GREEN: official llvm-lit PASS with the one-line fix + new\nllvm/test/CodeGen/MOS/scmp-ucmp.ll (s8/s16 results x s8-s64 operands, signed +\nunsigned, -verify-machineinstrs). 0016 artifact regenerated = fix + test,\nbyte-identical to the pushed branch wbniv:mos-scmp-ucmp-legalize @ e54ef471d546.\nDWARF branch cherry-picks clean onto tip. Pristine build dir kept for later\nwaves. Posting the issue+PR remains the user's move (gh commands atop each body).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
