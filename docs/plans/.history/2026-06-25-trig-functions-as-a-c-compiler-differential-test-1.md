| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/4ae4157) | #320: far array-subscript index-width fix (in 0001) + Q16.16 trig corpus + HiROM |

<!--history-meta v1
4ae4157	author	Will Norris
4ae4157	added	153
4ae4157	deleted	0
4ae4157	files	1
4ae4157	body	From wt/321-trig. Clang's EmitArraySubscriptExpr promoted the GEP index to the\ndefault 16-bit IntPtrTy for EVERY address space, so a subscript through a far\n(AS2, 32-bit) pointer with index >= 32768 was truncated to 16 bits, corrupting\nthe bank byte. Fix (clang/lib/CodeGen/CGExpr.cpp, folded into patch 0001):\npromote to the BASE POINTER's per-AS index width via\ngetDataLayout().getIntPtrType(ctx, TargetAS). For single-pointer-width targets\nthis resolves to exactly IntPtrTy, so their codegen is unchanged.\n\nRegenerated 0001 via dev/regen-patch-0001.sh (round-trips clean on the full\n0001..0008 stack); also fixed that script's STACK (was stale at 0007 — appended\n0008 so the recon/verify apply the whole live stack).\n\nTest corpus (the "beefy" far-rodata customer that exercises index >= 32768):\n- platforms/snes-hirom (banks $C0+ map a contiguous 64 KiB so a >32 KiB far\n  .far_rodata table fits — LoROM's 32 KiB windows can't), link.ld + CMakeLists\n- examples/65816/libfixmath (vendored MIT Q16.16 fixed-point math, used not\n  reimplemented) + examples/65816/k_trig32.c + dev/k_trig32{,lut}.sh + the\n  accurate-sin-LUT generator tools/gen-sin-lut-asm.py\n- examples/65816/farindex.c — the minimal 3-bank far-subscript repro\n- tools/snes-checksum.py grew --hirom (merged with mandel-zoom's 256 KiB LoROM\n  support); dev/_emu.sh slow-kernel knobs documented\n- docs/320-upstream-far-subscript-index-fix.md (drafted; rides the #320 far item)\n\nDifferential gate re-run on the consolidated stack this session.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
