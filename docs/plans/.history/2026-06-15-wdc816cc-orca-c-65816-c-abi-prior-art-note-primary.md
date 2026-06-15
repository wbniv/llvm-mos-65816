| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/d13970f) | docs: 65816 C ABI prior-art note (WDC816CC/ORCA-C), primary-sourced + vendored |

<!--history-meta v1
d13970f	author	Will Norris
d13970f	added	107
d13970f	deleted	0
d13970f	files	1
d13970f	body	Standalone calling-convention prior-art note for the #320/#321 ABI decision,\nread firsthand from primary sources (not the secondary drdevtools capture):\nWDC816CC manual pp.21-26 + ORCA/C Gen.pas. Both shipped-in-production compilers\nconverge on a hybrid frame (stack-passed args + PHD/TCD Direct-Page window,\n256-byte cap) with A(low)/X(high) returns; the near/far model maps onto #320.\n\nSources vendored locally but gitignored (copyrighted WDC manual; ORCA source\nnot redistributable) + a SOURCES.md manifest and dev/fetch-refs.sh (sha256-\nverified re-fetch). Tightens design-note §3; TODO item -> Done.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
