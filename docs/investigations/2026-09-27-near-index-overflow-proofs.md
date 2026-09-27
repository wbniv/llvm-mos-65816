# Recover near-index overflow proofs

The near-index proof recovery is implemented locally in `0002`. Loop Strength Reduction (LSR) was rebuilding near addresses without their overflow flags. A MOS loop pass now records sound unsigned no-wrap proofs immediately afterward. The [canonical optimization record](../defects/mos-near-index-overflow-proofs.json) retains the failing baseline, passing candidate and exact input.

Implementation and validation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`. The interrupted earlier plan and its recorded Claude attribution are preserved verbatim in [dated evidence](../defects/evidence/2026-09-27-near-proofs/interrupted-plan.md.txt). That attempt left a plan and measurement script, with no compiler implementation or completed measurements.

## Cause and proof

The [prior-work audit](../defects/evidence/2026-09-27-near-proofs/prior-work.json) reconciles the original [near-decoder report](2026-09-27-near-y-decoder.md), the TODO, Git history, standalone patches, `0002`, and live compiler sources. The existing [bank-wrap repair](../defects/mos-near-index-bank-wrap.json) is required for correctness. This follow-up addresses the extra address arithmetic caused by lost proofs.

The retained `far_rt_blit` input begins with an `inbounds` near GEP indexed by a counter ranging from 0 to 63. [Before/after LSR IR](../defects/evidence/2026-09-27-near-proofs/lsr.log) shows LSR replacing it with an unflagged byte GEP. `LSRInstance::Expand` constructs formula sums using `getAddExpr(Ops)` without flags. IRTranslator correctly transfers the flags that reach it. ScalarEvolution still knows the address recurrence is `{%dst,+,1}<nuw>` immediately after LSR; recomputing the analysis from the new IR loses that fact.

`MOSRecoverNearNoWrap` runs directly after LSR in the same loop pipeline. It examines only scalar near GEPs with an `i8` element and a single `i16` index. For that shape, there is no scaling, index truncation or intermediate addition: unsigned addition cannot wrap exactly when the resulting address is at least the base. The pass establishes this from a `nuw` recurrence starting at the same base, or from ScalarEvolution proving the unsigned comparison. It adds only `nuw`; it does not infer object bounds.

The [recovery trace](../defects/evidence/2026-09-27-near-proofs/recovery.log) shows `getelementptr nuw`. The copy loop then uses adjacent `lda [pointer],y` and `sta (pointer),y`, eliminating the explicit near-address addition. The fixed-buffer loop also regains `sta nearbuf,x`. An unflagged wrapping loop still computes its near address. The target gate excludes stock 6502; vector pointers and other address spaces are excluded. The legalizer's bank-wrap guard is unchanged.

## Size measurement

[The census](../defects/evidence/2026-09-27-near-proofs/census.json) compares recovery disabled and enabled in the same identified compiler, using 412 existing C inputs, `-Os`, no LTO, and machine verification. [The runner](../../dev/measure-near-index-proofs.py) retains commands, objects and diagnostics under `build/near-proof-recovery/census/`.

| Mode | Successful pairs / inputs | Before bytes | After bytes | Change | Smaller / larger objects |
|---|---:|---:|---:|---:|---:|
| Default | 375 / 412 | 1,950,055 | 1,945,851 | −4,204 (−0.22%) | 128 / 7 |
| A16 | 411 / 412 | 2,036,818 | 2,022,518 | −14,300 (−0.70%) | 141 / 1 |
| XY16 | 411 / 412 | 2,025,991 | 2,011,336 | −14,655 (−0.72%) | 145 / 1 |

Total savings are 33,159 bytes over 1,197 successful pairs. All 39 unsuccessful configurations fail in both arms; there are no newly failing configurations. These are aggregate object sizes, not a single linked ROM size or a speed measurement. The nine increases are retained below; proof recovery can change register allocation as well as addressing.

| Input | Mode | Growth |
|---|---|---:|
| `examples/snes/corpus/byvaledge_sim.c` | Default | 11 B |
| `examples/snes/corpus/critters_sim.c` | Default | 24 B |
| `examples/snes/corpus/dither_sim.c` | Default | 34 B |
| `examples/snes/corpus/keycmp64_sim.c` | Default | 7 B |
| `examples/snes/corpus/poolfx_sim.c` | Default | 124 B |
| `examples/snes/critters.c` | Default | 3 B |
| `examples/snes/dither.c` | Default | 20 B |
| `examples/snes/corpus/dither_sim.c` | A16 | 153 B |
| `examples/snes/corpus/dither_sim.c` | XY16 | 88 B |

## Validation and delivery

- The same retained IR input fails the indexed-store regression on the preserved baseline and passes on the final compiler. [Replay runner](../../dev/check-near-index-proofs.py), [baseline log](../defects/evidence/2026-09-27-near-proofs/baseline-replay.log), [candidate log](../defects/evidence/2026-09-27-near-proofs/candidate-replay.log).
- The MOS CodeGen and MC suites pass: 183 passed, two unsupported. Focused tests check the recovered IR flag, indexed assembly, an unflagged wrapping control and the stock-6502 exclusion.
- Both permanent near fixtures pass in default/A16/XY16, with and without LTO: twelve bsnes-jg checks return `0x5CF0`, including the signed-offset bank-$7E witness.
- The unchanged 62-work gallery returns `0x5CF0` after 30,000 frames. The published [SNES LZSS gallery](https://biohack.net/snes/lzss-gallery/) provides the demo context; its published ROM was not replaced by this work.
- All 16 corpus programs whose generated code changes pass in default/A16/XY16: 48 bsnes-jg checks. Ten use manifest oracles; six use freshly compiled host implementations. [Manifest-backed results](../defects/evidence/2026-09-27-near-proofs/corpus-runtime-final.json) and [host-oracle results](../defects/evidence/2026-09-27-near-proofs/corpus-runtime-extra.json) retain every outcome.
- The patch stack applies to the pinned source and reproduces all six changed source/test files. The scoped regeneration preserves the separate incoming `0068` change. The new regression is registered in `dev/regen-patch.sh`.

Binary hashes, source identity and preserved build locations are in [identity.json](../defects/evidence/2026-09-27-near-proofs/identity.json). Baseline and final binaries are retained separately under `build/near-proof-recovery/`. The preserved final compiler replays all 1,236 census configurations: all successful objects match the measured code/relocation hashes, and the 39 unsuccessful configurations retain their exit status. The final twelve-case near runtime matrix and all 48 affected-program runtime checks pass. The verified compiler and linker are installed in `build/llvm-mos-install`; [installed hashes](../defects/evidence/2026-09-27-near-proofs/installed.json) match the preserved final binaries.

This restores the demonstrated loop proofs; it does not establish that every lost overflow proof is recoverable. GEPs outside the deliberately narrow shape continue to rely on existing flags and known bits. The change belongs with the native-width feature series and its existing submission prerequisites.
