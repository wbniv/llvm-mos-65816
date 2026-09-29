# Near decoder: Y lifetime and near-address bank carry

The unchanged 62-work XY16 gallery benchmark now returns `0x5CF0`. Two independent compiler contracts caused its `0xA50F` failure. Both repairs are carried in `0002`; no upstream submission is made for them.

The published [SNES LZSS gallery](https://biohack.net/snes/lzss-gallery/) shows the workload's integration context. The validation below uses the preserved local regression input; this work does not update the published ROM.

The repair is committed as [e370e031](https://github.com/wbniv/llvm-mos-65816/commit/e370e03153109aee2bef7b48b5917d870dec3744). The [simulated PR packet](../pr-preparations/2026-09-27/near-y-pr-simulation.md) presents its proposed review body and remaining native-width submission gates.

Implementation, isolation and validation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`. Earlier reports retain their original attribution.

## Reconciliation and preserved builds

The [original report](../plans/2026-09-25-dpy-indexed-phase2-increment2.md) already had a [canonical near-Y record](../defects/mos-xy16-near-indirect-y-clobber.json). The existing X-writer restoration does not protect Y. An incoming uncommitted byte-fusion attempt also omitted committed increment-2 source and tests; its exact files were saved under `build/near-y-fix/` before reconstruction. The [prior-work audit](../defects/evidence/2026-09-27-near-y/prior-work.txt) records the searches and distinguishes the second mechanism.

The red build reconstructs `a9bedfae`'s exact `dev/toolchain.sh` patch list on vendor `8be0546128a55e78c63ca571d466aa72a782cd36`. All patched compiler sources were independently reconstructed and compared, including generic LLVM and Clang files. Preserved compiler/linker binaries and resource headers remain in `build/near-y-fix/{baseline,candidate,final}`. Here `candidate` means fusion only; `final` includes both repairs. Binary hashes, inputs, preprocessed sources, LLVM/LTO bitcode, machine IR and commands are retained in [near-Y evidence](../defects/evidence/2026-09-27-near-y/) and [bank-wrap evidence](../defects/evidence/2026-09-27-near-wrap/). The older canonical baseline is unchanged.

## 1. Split Y index

A separately selected `LDYImag16` can precede X8 spill reloads. Width insertion places `SEP #$10` before those reloads, clearing Y's high byte before `LDIndirYIdx` uses it. A later `REP` cannot recover those bits.

The byte and word load/store pseudos now consume the Imag16 index directly, define all of Y16, retain their memory operands, and have an explicit four-byte size. They survive allocation and width insertion, then emit adjacent `LDY` and indirect access instructions. Word forms require both M=16 and X=16. Genuine register-index operands retain their existing path.

The reduced decoder uses 384 literals followed by 288 bytes of distance-257 backreferences. It fails on the preserved baseline and passes with fusion, with and without LTO. The full gallery still fails with fusion alone, so that result does not establish gallery closure by itself.

## 2. A near offset carried into DBR+1

The [separate bank-wrap record](../defects/mos-near-index-bank-wrap.json) covers a different mechanism. A stage diagnostic finds the first gallery asset's compressed staging and far output byte-perfect. Near decoding returns the correct length but first differs at byte 6: a distance-4 backreference.

The exact [diagnostic source snapshot](../defects/evidence/2026-09-27-near-y/diagnostic-gallery.c.txt) is retained as documentary text, including inherited comments and display code. Its bytes are unchanged from the diagnostic build.

Loop strength reduction expresses that read as the current destination pointer plus a negative offset. With DB=$7E, the emitted unsigned indexed access adds `$A806 + $FFFC` and reads `$7F:A802`. The near pointer contract requires `$7E:A802`. The low-bank RAM mirrors conceal this difference in the reduced decoder's bank-$00 configuration.

`canFoldNearIndex` now requires `NoUWrap`, `NoUSWrap` with a nonnegative offset, or known-bits bounds proving that the unsigned sum fits. Otherwise it materializes the 16-bit near address before the access. The rule covers byte/word and absolute/indirect near indexing on 65816. Far indexing retains its bank-carry semantics. The isolated regression places `$5A` and `$C3` at the corresponding addresses in banks $7E and $7F: fusion alone returns `$C3`, and the guard returns `$5A`.

**Follow-up, September 27:** [near-index proof recovery](2026-09-27-near-index-overflow-proofs.md) now preserves sound unsigned no-wrap facts immediately after Loop Strength Reduction. The demonstrated near loops regain indexed accesses; unproven wrapping addresses still materialize the 16-bit address. The [optimization record](../defects/mos-near-index-overflow-proofs.json) retains its separate baseline and measurements. The validation below remains the dated evidence for the two correctness repairs. The [September 29 upstream packet](../pr-preparations/2026-09-29/near-index-proofs/README.md) extracts the recovery with the bank-wrap guard; its derived bank-wrap witness returns `0x5CF0` on the extracted backend. Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

## Validation

| Input | Committed baseline | Fusion only | Both repairs |
|---|---|---|---|
| Reduced decoder, LTO and non-LTO | `0xA50F` | `0x5CF0` | `0x5CF0` |
| Signed near offset, DB=$7E | Not needed for isolation | `0xA5C3` | `0x5CF0` |
| Original 62-work gallery, XY16 LTO | `0xA50F` | `0xA50F` | `0x5CF0` |

The permanent gate is `dev/container.sh -- bash dev/near-y-decode.sh`: decoder and bank-wrap fixtures, default/A16/XY16, LTO/non-LTO, machine verification and bsnes-jg runtime checks. All twelve configurations pass. The existing indirect-word gate and X-index control also pass on MAME and bsnes-jg. Focused LLVM tests cover fused byte/word loads and stores, full Y16 clobbers, volatile memory operands, and wrapping-address rejection. The final MOS suite passes 178 tests with 2 unsupported and no failures. `0002` round-trips against the live MOS sources and focused tests; both logs are retained with the evidence. The verified compiler and linker are installed in `build/llvm-mos-install`.

## PR #609

At the user's explicit request, computed-carry PR #609 was closed on September 27 at `01:38:15Z`; its branch remains at `155e209c4cee`. The [submission record](../pr-preparations/2026-09-26/0064-submission.json) preserves its earlier publication history. These near-address defects are separate from that scheduling PR.

## Earlier gallery discoveries

The gallery also exposed the [non-GPR LDImm late-optimization crash](../upstream-late-opt-nongpr-ldimm-pr.md), submitted as [PR #584](https://github.com/llvm-mos/llvm-mos/pull/584), and [zero-page allocation nondeterminism](../upstream-zp-alloc-deterministic-pr.md), submitted as [PR #590](https://github.com/llvm-mos/llvm-mos/pull/590). Their earlier packets retain their original mechanisms, dates and attribution. The discovery map keeps the gallery's original July 27 discovery date; the near-decoder repair and bank-wrap isolation above were completed on September 27.
