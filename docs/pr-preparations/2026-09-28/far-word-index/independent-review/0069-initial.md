# Independent correctness review: patch 0069

## Verdict

**No correctness defect found in the reviewed 0069 implementation.** The accepted induction pattern proves the stated unsigned range, and the offset walk preserves the actual arithmetic width. I recommend accepting the downstream change with the nonblocking coverage suggestions below. This is a static review with inspection of retained results; I did not run compiler tests or emulators, add tests, or change implementation files.

Scope: published commit `0eae3e7a0c42b1d20c482c154ec3716a3674ad1c`, `patches/llvm-mos/0069-mos-far-loop-range.patch`, live vendor source, callers, instruction definitions, generic value-tracking utilities, and all 26 MIR cases. The live legalizer also contains 0070; this report reviews the range proof and its use by the caller, without issuing a separate verdict on the word policy.

## Independent reviewer identity

OpenAI Codex CLI **0.158.0**, originator `codex-tui`, exact recorded model ID **`gpt-6-astra`**, reasoning effort **`xhigh`**. Verified from this reviewer's own `session_meta` and `turn_context` in `/home/will/.codex/sessions/2026/09/28/rollout-2026-09-28T15-43-55-01a0e72f-5a2d-7530-b114-4bfe66710323.jsonl`.

Reviewer thread ID: `01a0e72f-5a2d-7530-b114-4bfe66710323`; agent path: `/root/review_0069` (Cicero); session/root ID: `01a0e67f-298f-7a21-80af-06f867085f84`. No finer model revision is exposed in that metadata. Independence here means a separate AI reviewer task, **not human review or different-model review**. I reviewed code before author conclusions, did not read other new reviewer reports, and did not coordinate conclusions. Source identity information supplied by the parent was independently checked with SHA256.

## Correctness audit

Line references below are to `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` at the hashed live source unless a different file is named. Patch line numbers refer to the published patch file.

| Area | Assessment |
| --- | --- |
| Incoming edges and induction | Lines 3138–3157 (patch 27–46) require a same-block, two-input PHI, exactly two predecessors and successors, a self-edge, one constant non-self input, and a same-block unit `G_ADD` whose left operand is that PHI. For valid SSA MIR, these conditions account for every incoming edge. Either PHI operand order is supported. Every entry through the non-self predecessor resets to the same constant. An exit path that later re-enters through that predecessor does not invalidate the proof. |
| Reachability | Lines 3159–3194 (patch 48–83) require the first terminator to be the matched conditional branch, followed by exactly one complementary `G_BR` and no remaining instructions. There is no unexamined additional backedge. The proof uses the current access block, and the PHI, increment, and SBC must belong to it. It therefore does not apply a different block's loop condition to this access. An unreachable loop cannot produce a runtime counterexample. |
| Lowered operand roles | `MOSInstrGISel.td:36–42` specifies branch operands as test, target, test value. Its lines 59–61 specify SBC outputs 0=result, 1=carry, 2=negative, 3=overflow, 4=zero, and inputs 5=left, 6=right, 7=carry-in. Lines 3178–3184 check the actual zero output, the actual recurrence value on the left, and carry-in exactly one. The operand positions agree with comparison lowering at legalizer lines 1845–1867 and branch lowering at 4102–4118. |
| Exit polarity | When the conditional target is the loop, the immediate must be zero, meaning `Next != End`. When the target is the exit, it must be one, meaning `Next == End`, with the unconditional branch returning to the loop. Carry, negative, overflow, comparing the PHI instead of Next, and borrow-in zero all decline the proof. |
| Overflow and wrap | The byte PHI and same-typed addition/SBC establish byte Start, Next and End. Line 3188 requires unsigned `Start < End`, so `0 <= Start < End <= 255`. At each header `IV < End`; `Next = IV + 1 <= End`, and a self-edge occurs only for `Next < End`. The recurrence therefore reaches End before wrapping and the maximum header value is End−1. Bounds above 127 are valid unsigned endpoints. Start==End, zero endpoint/full-cycle loops, descending/wrapping intervals, and non-unit steps are rejected. |
| Constant recovery | `GlobalISel/Utils.cpp:331–394` follows copies and explicit truncation/sign/zero extension while preserving their APInt effects. It rejects `G_ANYEXT` in this API. Recovered constants do not silently discard narrow integer wrapping. |
| Width-preserving expression walk | Lines 3205–3229 (patch 94–119) start from the known-bits maximum and only refine with a smaller proven upper bound. Zero extension preserves unsigned values. Constant left shifts require amount<16, amount<the operation's own width, width<=64, and `Input <= max_unsigned(width) >> amount` before shifting. Thus the refinement is monotonic only where the operation cannot wrap. `G_ADD`, sign extension, truncation, and unrecognized operations keep their known-bits bound. Recursion beyond depth five also keeps that bound. |
| Known bits and saturation | Taking the minimum of two sound upper bounds is sound. For maxima requiring more than 64 bits, `getLimitedValue()` saturates at UINT64_MAX, which exceeds both Y limits and is rejected before index construction. The disabled option likewise preserves the old accept/reject decision for the 255/65535 limits. |
| Consumption of the proof | The caller at 3343–3381 checks the upper bound plus the final accessed byte, then truncates/extends the existing offset and adds only the admitted constant displacement. It does not rebuild a narrow expression at a wider width. The existing all-users and call restrictions remain in force. A successful loop proof adds range information; it does not change the far base or bank-carry convention. |

The validity assumptions above are ordinary MIR contracts. `MachineVerifier.cpp:1127–1164` checks standard pre-isel generic type equalities and excludes physical registers; lines 3401–3461 check PHI predecessors and missing incoming operands. `MOS::G_SBC` separately declares one shared `type0` for its arithmetic result and both arithmetic inputs, and its inspected lowering builds matching types. The standard generic verifier entry at lines 2372–2373 does not itself establish that the target-specific SBC receives all those checks. A malformed PHI with a missing third edge or an SBC with mismatched arithmetic widths does not meet the instruction contracts and is not a valid counterexample.

## Nonblocking coverage suggestions

These are coverage gaps, **not demonstrated defects**; severity P3.

1. **Exercise every incoming-edge rejection explicitly.** All positive fixtures put the entry pair first. Add a positive case with the PHI pairs reversed, and a valid three-predecessor PHI with two different external starts plus its self-edge. The latter must decline the specialized proof. This directly protects the critical guards at lines 3140–3146 (patch 29–35); `multiple_blocks` at MIR line 952 checks a different rejection path.

2. **Check operands as well as the selected opcode.** The assertions beginning at MIR lines 11–16 and repeated throughout distinguish `_INDIR`, `_IDX`, and `_IDX16`, including their trailing delimiter. They do not assert that the selected base is the original runtime base or that the index is the preserved offset plus displacement. Add operand checks for a positive scaled case and a narrow-wrapping fallback. Existing runtime and shape evidence supports the present implementation, but these MIR assertions alone would not catch a future operand substitution error.

3. **Protect the expression walk's boundaries.** The file covers wide scaling that fits Y, wide scaling that exceeds Y, and a narrow wrapping shift/add. A narrow nonwrapping shift and an expression just beyond the recursion limit would directly protect lines 3207 and 3225–3227. The inspected code handles both conservatively; this is additional regression coverage.

No valid trigger for a wrong-code result was identified, so there is no proposed compiler defect record or status change.

## Retained evidence inspected

After source review, I read the integration investigation, prior-work audit, identity/receipt files, focused command record, focused/full-suite logs, installed gate and shape-test logs, and source/runs archives. I checked all **35** entries in the integration `artifact-hashes.json`; all matched. This checks retained bytes, not whether a historical process actually executed those bytes.

The published MIR patch, live MIR file, and archived MIR file have the same SHA256. The complete live legalizer differs from the earlier range-only source because it includes the later word policy. The text from `FarLoopRange` through the end of `getFarOffsetMax` is byte-identical between those sources: SHA256 `0417e8cefaef65c70d6c08a63a31b03789d6c27480621c131d52cb0159b5c535`.

The retained `focused-checks.json` records three successful legalizer/FileCheck commands with `-verify-machineinstrs`. I also read the actual archived `focused-a16.mir`, `focused-xy16.mir`, and `focused-off.mir`: each contains the 26 named functions, with the expected Y8/fallback/Y16 distinction. Generic EQ/NE cases show that the pattern is reachable through branch legalization. The separate installed focused-lit log records one passing test.

The retained receipt records 36 LTO ROM configurations passing both emulators and 16 checker sensitivity tests. I inspected the boundary C fixture, the installed gate log, and sample raw baseline/candidate bsnes and candidate MAME boundary logs. The sample bsnes results contain `pass:true` with got==expected==3374804766 (`0xC9276F1E`), and the MAME log reports the same oracle. This is supporting historical evidence, not a fresh independent execution of the full runtime matrix.

The full MOS suite log is **127 passed, 2 unsupported, 5 failed**. Each of the five retained failures reports duplicate registration of `mos-recover-near-nowrap` during opt startup. It is not a completely green suite, and these failures provide no execution coverage of the new proof. The identified range-only candidate llc SHA256 is `20026cd1ed2cd653a77db4a98a31a7b4d1fac6c7e12dff98df86ed150a8094dd`; the baseline is `cfbd4478040a1c4b36adbb2cdd7374a454e01f2676f0e8488aa5623d1b9a4e0a`. These are historical identities read from the manifest; I did not rehash or execute those binaries in this review.

## Prior-work reconciliation and limits

Searches covered structured defects, investigations/plans, TODO/upstream summaries, patch files including 0002, Git history, and live helpers using `0069`, `far-loop-range`, `getFarLoopMax`, `getFarOffsetMax`, `tryFarRuntimeIndexFold`, far indexing, and wrapping. The indexed byte fold already exists in 0002; 0069 adds the specialized bound. The published merge commit `3495deb92424bc0ea5f76812fd027aba376edce9` introduces the published 0069/0070 work. Ordinary symbol pickaxe did not expose that merge addition, so I also inspected the patch-specific history and merge message.

`docs/defects/mos-farblit-byte-load-legalization.json` concerns the separate eager-load/worklist failure repaired by 0066. Its retained later observations already distinguish the 0069 optimization from that correctness closure. This review neither reopens nor re-closes that defect. No newly suspected causal defect survived the static audit.

This review supports the downstream patch at the identified source. It does not establish applicability or test results for an extracted stack on the exact upstream destination. It also does not establish profitability on unseen applications, fresh runtime correctness, or human/different-model approval.

## Inspected file identities

Paths prefixed `vendor/` are in `/home/will/llvm-mos-65816`; other repository paths below are in the published worktree `.scratch/far-word-publish`. Hashes cover the complete files even when review inspected only relevant sections.

| File | SHA256 |
| --- | --- |
| `patches/llvm-mos/0069-mos-far-loop-range.patch` | `0a3e03130ee3b1e3a8a9be6bba565d92c153f57c16c7e3725fe537e41ad5ede9` |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` | `e95d5b9ccc21dc956c99761b5b3f386ef1db2cfba85b9c5820cd7e6c6437d518` |
| `vendor/llvm-mos/llvm/test/CodeGen/MOS/far-loop-range.mir` | `aad0896456e28c3278022b11c6c99b3b5afd5baff058e60dd25277ceb90eb414` |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrGISel.td` | `48e3f912c89f68a473579ce115dcd15a3bbbe86c7be57e1cb68cf63bf4099a4f` |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` | `b8c33e5b149d2fa32ac8eef09914a0265a86070ca519fbf47914d4d5c07107ca` |
| `vendor/llvm-mos/llvm/lib/CodeGen/GlobalISel/Utils.cpp` | `78371f00d74bca15efa50eac68a9bca449cf0aef1bb5a3f80a0e1a1c8cc7e75a` |
| `vendor/llvm-mos/llvm/lib/CodeGen/GlobalISel/GISelValueTracking.cpp` | `c4115c9f57287b7d584d7edec176ba9de2bda640acac419144d2d9a6f43af813` |
| `vendor/llvm-mos/llvm/lib/CodeGen/MachineVerifier.cpp` | `7f7117afa76037c9806f2843216009d743b267c68098c37e22d1c68d50e40f71` |
| `patches/llvm-mos/0002-321-accum16.patch` | `dcc587682f9b0ce4caf1a0f20ed8eb32500cb1b2ff3593502b9350b627c4693b` |
| `docs/defects/mos-farblit-byte-load-legalization.json` | `e7563418b65c76f7587da94903f696aad6462bd1d1d359b9b53221d3c276d13c` |
| `docs/investigations/2026-09-28-farblit-range-integration.md` | `6c613d5a24b881465057bf1928cf2b8057c1bfda5e8bf55e295fdb11d9168cda` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/source.tar.gz` | `cd4204a6860f44db5e2fb4184ef56784165fca06a6e71cbd7d1d1974dfb0b6e3` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/runs.tar.gz` | `c84c4712fd5751225f21582622f3b37fa50c74010585f8047cd143436c5b5fea` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/artifact-hashes.json` | `c02bb72758bd34cda9f5242bd78017e4414f48746669cd67110d509f0f7f7679` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/identity.json` | `6279a633092d8092e15e003449c087090699f03e2269f877c69f2af3130e4653` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/prior-work.json` | `d6a9014d245793b7bb6f4a2131e5356a48ac56940b958c289a45b3880e209f88` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/receipt.json` | `ac174f2f6b45c5be3b98f8087bc529f9906ef131fba45423e9be6be20322f80e` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/focused-checks.json` | `c058ba1cb04a8e7c0a7836107f3e330d61612134b4f165198ab3be7ff11ceca6` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/installed-focused-lit.log` | `bee381ca848f0353a5de0650953e350c922bbc086ff7a3b5eeaec58c83a6c665` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/lit-all.log` | `b0ec59cf372980801da118bd8b5e9e7fe1a339d5f9c6eaff4bf7cfcae2646d8a` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/installed-gate.log` | `23165a1326ed23e557281c65b6fdf849f450ed40e43a8cb998d3b69db05b1ee4` |
| `docs/defects/evidence/2026-09-28-farblit-range-integration/installed-shape-tests.log` | `4e1b45c604b7e9275c5c3d0af74cb6a3d732f07d828cb7d3166011addc7a3257` |

Archived focused output identities: `runs/focused-a16.mir` = `1e7edc9844e3907c46fcb1f36b6ffa8d39c3a8b32381f42bfb997fee2e0b3c36`; `runs/focused-xy16.mir` = `ff391995679a27e361f2389ed15d38c59262c4c537bdb2ef02b6fdacfd6e5ca7`; `runs/focused-off.mir` = `8b84348af8abe8a022c7a8e3fcfb8f5fa6214bc98f5792e0a5828e9f5be21c60`.

This temporary report is the only file written by this reviewer. No repository documentation or defect status was changed.
