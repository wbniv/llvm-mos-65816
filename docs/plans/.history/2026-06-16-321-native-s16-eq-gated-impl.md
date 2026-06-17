| Date | Change |
|------|--------|
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/37674ff) | #321 native s16 equality-as-value (gated v1): indirect-load operand goes native |

<!--history-meta v1
37674ff	author	Will Norris
37674ff	added	171
37674ff	deleted	0
37674ff	files	1
37674ff	body	`b = (*p == c)` consumed as a VALUE narrowed to the 8-bit cpx/cmp two-byte chain even\nunder +mos-a16. When an EQ operand is a non-absolute (indirect) s16 load (`*p == c`,\n`p[i] == c`, `s->field == c`), the loaded value already lands in Imag16, so a native\n16-bit compare reads it directly -- `rep; lda (zp); cmp; sep; beq/bne` + a 0/1\nmaterialize -- instead of unmerging it back into bytes. eq_deref 38 -> 34 B.\n\nGated to exactly that case (`isIndirectS16Load` in legalizeICmp): register/global/\ncomputed operands stay 8-bit, because there the native form routes the LHS through\nImag16 + rep/sep that the tight 8-bit `cpx;cmp` avoids. A throwaway spike confirmed the\n*blanket* native form is a net regression (register +8 B, global +4..12 B) -- hence the\nnarrow gate. No new pseudo: the value materializes through the existing\nbuildNZSelect -> MOSLowerSelect -> G_BRCOND_IMM -> CmpBrImag16 path (the originally\nsketched CmpSelImag16/CmpSelImm16 pseudo proved unnecessary).\n\nSubsumes the indirect-s16-load byte-wise follow-up (closed won't-implement): a native\nEQ keeps the operand 16-bit, so there is no G_UNMERGE and no spill-vs-byte-spill dilemma.\n\nVerified: eq_deref native 38->34 B, every other shape byte-identical (no regression),\n-verify-machineinstrs clean, ambient indirect-EQ native; examples/65816/a16eqvalp.c\nhost == default == +mos-a16 (0x0101) on MAME + bsnes-jg; a16 suite 44/44, corpus 7/7,\nfuzz 50/50 (0 mismatch, on the F4-fixed build); patches/0002 round-trips.\n\nv2 (computed-LHS) and v3 (abs-operand fold for globals) remain -- see\ndocs/plans/2026-06-16-321-native-s16-eq-gated-impl.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
