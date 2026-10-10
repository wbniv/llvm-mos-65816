| Date | Change |
|------|--------|
| [2026-10-10](https://github.com/wbniv/llvm-mos-65816/commit/5c68aa5e) | Advance compiler pin and retire merged upstream carries |

<!--history-meta v1
5c68aa5e	author	Will Norris
5c68aa5e	added	17
5c68aa5e	deleted	0
5c68aa5e	files	1
5c68aa5e	body	Pin llvm-mos to f24948c7d1a4b9f162d4d0192ccceecab1e441ff and share the revision across toolchain, lit, and patch regeneration scripts. Retire merged standalone patches and duplicate fixes in the aggregate patches, then port the remaining 50-patch stack to the new compiler APIs and target layout.\n\nRefresh upstream tracking, dependent summaries, and validation records. Preserve historical closure artifacts and capture matching-input evidence for the packed-layout integration repair and native-index copy-cost backport. Qualify performance and runtime results that have not been revalidated on this pin.\n\nValidation: clean 50-patch bootstrap with no touched-file mismatches; patch regeneration round trip; 205 MOS tests passed with one upstream-disabled test; 56 C object configurations passed; prefetch checks passed; repository pre-commit checks passed.\n\nAI assistance: OpenAI Codex 0.162.0, model gpt-6.1-sol, medium reasoning effort. Session: 01a1208b-91e0-7e33-b5bf-8787d2a9c919.
-->
