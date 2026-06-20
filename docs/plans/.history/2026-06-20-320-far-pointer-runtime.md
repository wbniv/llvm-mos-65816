| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/88b18f0) | #320 Inc 3 plan: runtime far-pointer dereference (lda [dp]), near→far cast, arithmetic |

<!--history-meta v1
88b18f0	author	Will Norris
88b18f0	added	271
88b18f0	deleted	0
88b18f0	files	1
88b18f0	body	Removes the "upstream-gated / blocked on posting" framing from the TODO —\nthe design is settled (0=16-bit stays, 2=far opt-in, no upstream blessing\nneeded to build), so implementation proceeds code-first. The plan covers:\n3a (lda [dp]/sta [dp] via new Imag32 class + LDA_IndirectLong MC def +\nG_LOAD_FAR_INDIR GISel pseudo + tryFarIndirectAddressing legalizer),\n3b (G_ADDRSPACE_CAST AS0→AS2 zero-extend), 3c (G_PTR_ADD on AS2 — likely\nno-op, verify first). Far calls (JSL/RTL) are Inc 4, planned separately.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
