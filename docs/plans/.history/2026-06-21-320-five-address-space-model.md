| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/caef3e9) | #320 five-address-space model: plan + Phase 0 census (packed-24/zero-bank = measured nulls) |

<!--history-meta v1
caef3e9	author	Will Norris
caef3e9	added	346
caef3e9	deleted	0
caef3e9	files	1
caef3e9	body	Phase 0 of the full five-address-space model (asiekierka's Option B). Two HARD gates,\nboth run host-side with zero vendor edits (dev/measure-five-space-census.sh):\n\n0a representability = GO. The upstream note's premise ("LLVM requires power-of-two\npointer sizes") is WRONG: parseSize has no pow2 rule and getPointerSize=divideCeil(24,8)\n= 3 bytes, so a 24-bit pointer is representable; the MOS GISel backend carries a genuine\n24-bit value (_BitInt(24) compiles clean default + +mos-a16, verify-clean).\n\n0b usage census = NO-GO for both new spaces. 0 far pointers are stored in memory in real\ncode; sizeof(far*)==2 (clang getPointerWidthV lacks `case 2: return 32`); G_STORE p2\ncrashes the legalizer on main (p2-value store/load is unmerged in 0004). So packed-24\n(AS3) and zero-bank (AS4) are empty AND blocked -> closed as measured nulls (frame-ABI\npattern). The valuable surfaced next work is front-end far-pointer value completeness\n(sizeof==4 + aggregates + merge 0004's p2 store/load), not new address spaces.\n\nHard constraints documented: C1 one shared MOS datalayout forecloses 0=far-default\n(would break the 6502); C2 addrspace(2)=far is load-bearing, defer renumber to upstream.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
