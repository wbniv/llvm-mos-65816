| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/d73ffce5) | docs(far-memops): reconcile plan + TODO with as-built fix |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/a81874d8) | #321 fix far (addrspace 2) memset/memcpy/memmove silent wrong-bank miscompile |

<!--history-meta v1
d73ffce5	author	Will Norris
d73ffce5	added	18
d73ffce5	deleted	10
d73ffce5	files	1
d73ffce5	body	- Plan Approach Part A: the runtime is index-style (ptr[i], invariant far base),\n  NOT mem.c-style ptr++ — a far-pointer loop IV forms an unsupported G_PHI(p2);\n  document the snes-c libc merge mechanics and the -fno-lto compile option.\n- TODO.md: move the far memset/memcpy/memmove wrong-bank item to Done (fixed in\n  a81874d / patch 0013).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01J79PZm5LMmiJGxQH9kHcuQ
a81874d8	author	Will Norris
a81874d8	added	249
a81874d8	deleted	0
a81874d8	files	1
a81874d8	body	A far memop the backend can't inline-expand (variable size, or constant size over\nlegalizeMemOp's SizeLimit) fell through to the generic createMemLibcall, which calls\nthe NEAR runtime (__memset/memcpy, 16-bit char*) while passing the 32-bit far pointer\n-> the bank byte was silently dropped -> wrong-bank store/load, no diagnostic. The\nloop-idiom recognizer is only ONE source: clang EmitAggregateCopy (any far struct\ncopy, no size threshold), null/const init, __builtin_mem*, and MemCpyOpt all converge\non the same path -- so the fix must live at the backend chokepoint, not the recognizer.\n\nFix (patch 0013, MOSLegalizerInfo.cpp): two static helpers (anyFarPointerOperand +\ncreateFarMemLibcall) route a far memop to a far-aware runtime\n(__memset_far/__memcpy_far/__memmove_far, platforms/snes/mem-far.c), widening any\nnear pointer to far bank $00 and coercing the length to size_t (i16). The near path\nis untouched. No generic-LLVM change; upstream-worthy for llvm-mos once #320 lands.\n\nThe runtime is written index-style (ptr[i], invariant far base) because a far-pointer\nloop induction variable forms an unsupported G_PHI(p2) -- a pre-existing backend gap\nnoted for follow-up.\n\nGate: dev/run.sh far_memops -- variable far memset + far aggregate memcpy into HIGH\nWRAM ($7E), read back via far loads == 0x74 on MAME (-Os/-O2) + bsnes-jg (xcheck).\nNo regression: corpus 7/7, corpus-a16 6/6, far suite 14/14, torture 40/40.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01J79PZm5LMmiJGxQH9kHcuQ
-->
