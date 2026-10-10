| Date | Change |
|------|--------|
| [2026-10-10](https://github.com/wbniv/llvm-mos-65816/commit/fbab753a) | Add repeatable validated compiler re-pin command |

<!--history-meta v1
fbab753a	author	Will Norris
fbab753a	added	41
fbab753a	deleted	0
fbab753a	files	1
fbab753a	body	Add task upstream:repin to reconstruct the active bootstrap stack at its pinned base, replay it onto fetched upstream main, and independently verify the exported patches. Retain conflicts for resolution and resume, preserve excluded hunks and patch credits, and require an isolated compiler build plus MOS CodeGen/MC suites before publishing patches and writing the pin last. Check input/export integrity and roll back publication failures. Do not commit or push automatically.\n\nDocument usage, completed preparation evidence and the next full validation step. Retain the dated real-stack command log and hashes. The tracked compiler pin and existing patch bytes are unchanged by this commit.\n\nValidation: all 12 local Git fixture tests passed, including conflict recovery, retirement, validation failures, integrity checks and publication rollback. Real prepare-only replayed 51 applications onto 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63; independent exported application matched tree 065937b873d8229d96932f59f0141724ccd0c9a9 and all 54 input hashes remained unchanged. Fixture build gates use a mock runner; no real compiler build, MOS lit or runtime validation was performed. Document dependency review and inventory are refreshed; repository pre-commit checks run on staged changes.\n\nOpenAI Codex 0.162.1; model gpt-6.1-sol; medium reasoning effort; verified session 01a1208b-91e0-7e33-b5bf-8787d2a9c919. Earlier contributor credits remain preserved in the source records.
-->
