| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/697f40c) | docs: validate the coalesce-rotate-Ac fix — more tests, minimality, no-regression report |

<!--history-meta v1
697f40c	author	Will Norris
697f40c	added	144
697f40c	deleted	0
697f40c	files	1
697f40c	body	New investigation docs/investigations/2026-06-26-coalesce-rotate-ac-fix-validation.md answering the\nthree questions the fix raises:\n\n1. MORE fail-before/pass-after programs. Method: keep the frontend fixed (post-LTO bitcode via\n   --lto-emit-llvm) and swap only the backend (baseline llc with the fix reverted vs the committed\n   llc), link both, compare on bsnes-jg + host. A 96-program synthetic CRC fuzzer (4 polys x dir x\n   1-4 interleaved accumulators x indexing, + MMIO/hash pressure) found 0 -> the bug is NARROW (a\n   bare CRC won't push the coalescer to the Ac join). Mutating the known-reproducing min.c (CRC poly\n   0x1021/0x8005/0x8408/0xA001) gives 4/4 fail-before/pass-after, each confirmed correct after\n   (fixed-default == the +mos-a16 oracle).\n\n2. MINIMALITY. Env-toggled 4-variant sweep on pl.ll: the committed condition (NewRC==Ac AND both\n   operands rotate-referenced) is the tightest correct form. `either` (not `both`) INTRODUCES a\n   different miscompile (0x454E); dropping NewRC==Ac doubles refusals (74 vs 30); dropping the rotate\n   check bloats +372 B (477 refusals). Each clause is load-bearing.\n\n3. NO REGRESSION. corpus 7/7, c-torture 30/30, csmith 54/60 (0 mismatch/crash/error), a16+xy16\n   micro-tests PASS, -verify-machineinstrs clean. The fix only refuses the precise rotate-Ac class.\n\nAlso: embedded the full patch + lit test in docs/upstream-coalesce-rotate-ac-pr.md (per request);\nplan RESULT links the validation doc.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
