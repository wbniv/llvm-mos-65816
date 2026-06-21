| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/05cda9c) | #320 far-value evidence: committed sample programs + compile results (proof) |

<!--history-meta v1
05cda9c	author	Will Norris
05cda9c	added	78
05cda9c	deleted	0
05cda9c	files	1
05cda9c	body	Inspectable C fixtures (examples/65816/far-value-evidence/, with a README mapping each to\nits real compile result) demonstrating the far-pointer value-type state by compiling or\nfailing to compile — both default and +mos-a16:\n- WORKS: deref a constant far addr (t1), near->far cast+deref (t2, a16), and a genuine\n  24-bit value via _BitInt(24) (m1 — lowers to 3x byte ops, NO MVT::i24).\n- MISSING: store/load/array/struct of a far ptr (s1-s4: G_STORE/G_LOAD p2 fail),\n  far->near / dp->near narrowing casts (c1/c2), sizeof(far*)==2 not 4 (z1).\nRefactor dev/measure-far-ptr-value-state.sh to compile these committed fixtures (single\nsource of truth). Evidence subdir is outside the test-harness glob (fixtures intentionally\nfail). Link from the plan's Phase 3 results.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
