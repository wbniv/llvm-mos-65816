| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/46a1484) | #321 plan: file the register-scavenger N/Z-liveness crash upstream |

<!--history-meta v1
46a1484	author	Will Norris
46a1484	added	242
46a1484	deleted	0
46a1484	files	1
46a1484	body	Plan-first contract for the queued upstream issue (saveScavengerRegister\nasserts N/Z dead — already root-caused, XFAIL'd, draft + gh command ready).\nDrives the actual file-it path: pre-flight that the bug is still live both\nhere (release verifier + asserts build) and on upstream HEAD, a time-boxed\nattempt at a DEFAULT-8-bit repro so a maintainer can trigger it WITHOUT the\nfork-only +mos-a16 (analysis-only filing as the guaranteed fallback), the\nuser-triggered post, and same-turn tracking close-out (the XPASS guard\nalready fires on an upstream fix). Issue-only — no fork patch, no codegen\nchange. Wires the existing TODO "File the ... issue" item to the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
