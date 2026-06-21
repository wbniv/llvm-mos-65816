| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/05cda9c) | #320 far-value evidence: committed sample programs + compile results (proof) |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/f84efcd) | #320 five-space: Phase 3 (cast/value-state matrix) + correct the verdict (defer, don't null) |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/d038c3a) | #320 five-space plan: expand 0a (representability) + tie it to the upstream #320 response |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/caef3e9) | #320 five-address-space model: plan + Phase 0 census (packed-24/zero-bank = measured nulls) |

<!--history-meta v1
05cda9c	author	Will Norris
05cda9c	added	3
05cda9c	deleted	1
05cda9c	files	1
05cda9c	body	Inspectable C fixtures (examples/65816/far-value-evidence/, with a README mapping each to\nits real compile result) demonstrating the far-pointer value-type state by compiling or\nfailing to compile — both default and +mos-a16:\n- WORKS: deref a constant far addr (t1), near->far cast+deref (t2, a16), and a genuine\n  24-bit value via _BitInt(24) (m1 — lowers to 3x byte ops, NO MVT::i24).\n- MISSING: store/load/array/struct of a far ptr (s1-s4: G_STORE/G_LOAD p2 fail),\n  far->near / dp->near narrowing casts (c1/c2), sizeof(far*)==2 not 4 (z1).\nRefactor dev/measure-far-ptr-value-state.sh to compile these committed fixtures (single\nsource of truth). Evidence subdir is outside the test-harness glob (fixtures intentionally\nfail). Link from the plan's Phase 3 results.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f84efcd	author	Will Norris
f84efcd	added	75
f84efcd	deleted	18
f84efcd	files	1
f84efcd	body	Phase 3 characterization (dev/measure-far-ptr-value-state.sh, run both default and +mos-a16):\na far pointer is a complete ADDRESS mechanism (deref/load/store/arith/calls work, a16-gated)\nbut an INCOMPLETE VALUE TYPE — store/load/array/struct all fail under both modes,\nsizeof(far*)==2 not 4, far->near / dp->near casts fail (dp->near can segfault). 3a cast\nmatrix = the durable spec; 3b far-default flag = blocked on the value-type completion.\n\nVerdict corrected after user pushback: my first pass called this an "empty opportunity, close\nas null" — but that was circular (nothing stores far pointers because storing them is BROKEN,\nnot because there's no use). So:\n- NEW spaces (packed-24 #3, zero-bank #4): DEFER, not null — packed-24 would size-optimize a\n  capability (a far pointer stored in memory) that does not exist yet.\n- The capability they presuppose — completing the far-pointer VALUE type (sizeof==4 +\n  G_STORE/G_LOAD p2 in memory + aggregates + narrowing casts + merge 0004's pass/return) — is\n  promoted to its own DESIRABLE M1 TODO item. Coordinate the clang side with the F2 work.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d038c3a	author	Will Norris
d038c3a	added	76
d038c3a	deleted	13
d038c3a	files	1
d038c3a	body	Deepen the Phase 0a finding and inline how it reshapes our planned #320 post:\n- IR layer: exact DataLayout.cpp source — parseSize has no pow2 rule (only parseAlignment\n  does), getPointerSize=divideCeil(24,8)=3 bytes, getIntPtrType=i24. The note's "LLVM\n  requires power-of-two pointer sizes" is a misconception to retract.\n- Backend layer: the real reason far is 32-bit is MVT (no MVT::i24) — a register-class +\n  calling-convention plumbing convenience, not an IR limit. _BitInt(24) proves the\n  intra-function path; the MVT::i24 gap is the cross-function/stored cost.\n- Three axes (representable / cheaper-at-runtime / cheap-to-implement) + our corrected\n  upstream position (keep 32-bit far, defer space 3 on measurement not on a false pow2\n  premise) + the concrete note edits to stage before posting (do not post).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
caef3e9	author	Will Norris
caef3e9	added	346
caef3e9	deleted	0
caef3e9	files	1
caef3e9	body	Phase 0 of the full five-address-space model (asiekierka's Option B). Two HARD gates,\nboth run host-side with zero vendor edits (dev/measure-five-space-census.sh):\n\n0a representability = GO. The upstream note's premise ("LLVM requires power-of-two\npointer sizes") is WRONG: parseSize has no pow2 rule and getPointerSize=divideCeil(24,8)\n= 3 bytes, so a 24-bit pointer is representable; the MOS GISel backend carries a genuine\n24-bit value (_BitInt(24) compiles clean default + +mos-a16, verify-clean).\n\n0b usage census = NO-GO for both new spaces. 0 far pointers are stored in memory in real\ncode; sizeof(far*)==2 (clang getPointerWidthV lacks `case 2: return 32`); G_STORE p2\ncrashes the legalizer on main (p2-value store/load is unmerged in 0004). So packed-24\n(AS3) and zero-bank (AS4) are empty AND blocked -> closed as measured nulls (frame-ABI\npattern). The valuable surfaced next work is front-end far-pointer value completeness\n(sizeof==4 + aggregates + merge 0004's p2 store/load), not new address spaces.\n\nHard constraints documented: C1 one shared MOS datalayout forecloses 0=far-default\n(would break the 6502); C2 addrspace(2)=far is load-bearing, defer renumber to upstream.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
