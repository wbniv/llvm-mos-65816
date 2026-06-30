| Date | Change |
|------|--------|
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/7172dd9) | feat(snes): #22 64-Bit Avalanche — splitmix64 hash matrix / 64-bit integer libcall stress demo |

<!--history-meta v1
7172dd9	author	Will Norris
7172dd9	added	96
7172dd9	deleted	0
7172dd9	files	1
7172dd9	body	Round-2 (new-codegen-corner) demo. Every Round-1 demo tops out at 32-bit; this one mixes\nuint64_t, so on the 16-bit 65816 each op is a multi-limb libcall: __muldi3, __lshrdi3/\n__ashldi3 (incl. variable 1ULL<<i and whole-limb >>32), __udivdi3, __adddi3, 64-bit xor.\n\nBit-exact differential (64-bit integer ops are exact): host == default-8bit == +mos-a16 ==\n+mos-xy16 == 0x27EA on bsnes-jg; disasm __muldi3=2, 64-bit shift, __udivdi3=1, rep/sep=19.\nNo bug found. Visual: cell (i,j) = output bit j of hash64(seed^(1<<i)) -> a ~50%-dense\nrainbow avalanche field. bank-0 buffer (5-way), Mode-7. Published biohack.net/snes/avalanche/.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
