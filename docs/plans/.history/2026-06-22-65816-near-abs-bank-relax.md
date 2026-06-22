| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/1654e3c) | #320 plan: record the full 0001-0007 combined-stack gate (all green, both emulators) |
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/ff02726) | #320 65816: near-global absolute access stays 16-bit (suppress abs->long bank-relax) [0007] |

<!--history-meta v1
1654e3c	author	Will Norris
1654e3c	added	26
1654e3c	deleted	9
1654e3c	files	1
1654e3c	body	Belt-and-suspenders verification of 0007 (near-abs bank-relax fix) on the FULL stack:\nfresh compiler worktree, vendor reset to pristine + 0001-0007 applied fresh, toolchain\n+ SDK rebuilt, full gate run. corpus 7/7; packed24 e2e 0xF3; packed24_table static-init\n(packed 24 B vs far 32 B, -8 B/25%) walked == 0xA5; far suite (7) green; the 6 long->abs\na16 gates pass END-TO-END (disasm + MAME execution, both emulators); csmith 50/1 0\nmismatch. Confirms 0006 (static-init reloc) + 0007 (near-abs) compose with no interaction.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_016UaEGRGLhZFsejueUD9cnj
ff02726	author	Will Norris
ff02726	added	131
ff02726	deleted	0
ff02726	files	1
ff02726	body	Task B of the packed-24 productionization handoff, root-caused to a GENERAL 65816\nassembler issue (not packed-specific): MOSAsmBackend's bank relaxation grew every\nplain-symbol A-register near-global absolute access to the 4-byte absolute-LONG\nform, because it never distinguished near (bank-0) from far. X/Y escape only\nbecause they have no long form; lld doesn't shrink long->abs, so the +1 byte/access\nreached the linked ROM (~284 sites across the a16 examples alone).\n\nFix: in fixupNeedsRelaxationAdvanced, suppress the abs->long bank step for near\n(non-.far) sections. Far (.far_*/address_space(2)) still relaxes to long, and an\nunknown section already relaxes -> a misclassification can only miss the size win,\nnever emit a wrong-bank access. Relies on the same DBR=0 invariant the STX/STY\nnear abs-stores already depend on (X/Y having no long form is why only A bloated).\n\nLands as its own stacked patch (0007), independent of the packed-24 patch (0006).\nVerified: corpus 7/7, packed24 0xF3 (MAME+bsnes-jg), far suite green, csmith fuzz\n50/1 + 100/51 = 0 mismatch (default-65816 + a16 + host agree). The 6 a16 disasm\ngates were updated to match both abs (Xd) and long (Xf) forms, since the fix also\nshortens the native-s16 ALU absolute ops (adc/sbc/and/ora/eor/lda abs16) long->abs.\n\ndocs/plans/2026-06-22-65816-near-abs-bank-relax.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_016UaEGRGLhZFsejueUD9cnj
-->
