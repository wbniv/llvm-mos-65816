| Date | Change |
|------|--------|
| [2026-09-22](https://github.com/wbniv/llvm-mos-65816/commit/13cd70f0) | docs(upstream): preserve review bundles and reproduction evidence |

<!--history-meta v1
13cd70f0	author	Will Norris
13cd70f0	added	108
13cd70f0	deleted	0
13cd70f0	files	1
13cd70f0	body	Add the supporting records referenced by the upstream work tracker: MVN/MVP\nand SDK longjmp submissions, the separate simulator proposal, SDK SNES\nreconciliation, and the held undef-lane contribution with its patch alternatives.\nKeep the recorded publication state and validation scope explicit.\n\nSave stock-6502 C reproducers for the independent compiler findings and the\nrevision-pinned upstream-reference wrapper. The wrapper preserves the saved\ncompiler snapshot and executes it using its recorded container image.\n\nThe 0028 patch is retained as a review artifact; its toolchain integration and\nthe related native-width implementation changes are outside this commit.\nRaw diagnostic logs retain their original formatting.\n\nValidation: shell syntax, staged comment-history checks, and the existing\nrecorded compiler/test results. No new upstream PR or discussion is submitted.
-->
