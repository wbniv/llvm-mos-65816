# Third independent review: #320 rebuilt on #594 and the far-word packet

October 1, 2026. **Once mlund answers the #594 points, the #320 prerequisite and 0069/0070 can file. No new blocking defect was found.** The second-round series carries #594 faithfully. Its only change to mlund's code is the one-token `bits<16>`→`bits<32>` rebase. The reservation fix in 1b reserves exactly the quads that overlap reserved pairs, and it leaves default-mode code identical. The 65816-only allocation gate in 1c adds no pressure set and changed no default output I measured. Moving far-word patch 10 into 1d and moving patch 9 before patch 5 are both token-faithful. The shared `dropDeadFarAddressDebugUses` helper closes B8 at every far fold site I could reach, and it never dropped a live location. B9, N10 and N12–N15 are fixed. Two blockers remain, and both depend on mlund's answer, not on this series: B5 (the RL DWARF numbering) and B7 (#594 alignment, including whether mlund folds 1b's fix into #594). I found six nonblocking items, N17–N22. The most notable is N17: #320‑2 silently fixes an upstream SPC700 segfault that no default-mode check covers.

## Exact scope

| Item | Identity |
|---|---|
| Split source (read only) | `build/split-320-321/source`, branch `split-320-321-r2`, nine #320 commits on `25c40909b44a` |
| #320 commits | 1a‑i `ad7b2f4239a2`, 1a‑ii `f8a569b204c1`, 1a‑iii `fcb88211d861` (#594, mlund), 1b `733b59e025ee`, 1c `dcb9d3227be9`, 1d `cbbe9c70f520`, #320‑2 `3046c5754503`, #320‑3 `8d9c0382db7c`, #320‑4 `d19b7155d3c6` |
| Far-word packet | branch `pkt-r2-far-word`: patch 9 `8802a1b438df`, 5 `a252fae7ee3f`, 6, 7, 8, 11, 12 `5a8bdff0172e`, 13, 14 `c275e191de52`; exported as `patches-split/0019`–`0036` |
| Compared against | the reviewed `split-320-321-carry` (`59d98c37ab77`), `pkt-c-far-word` (`a5515aab9219`), and upstream #594 head `7b80f7e18768` (fetched from `github.com/llvm-mos/llvm-mos` `pull/594/head`) |
| Destination | upstream main `06bc967d2668` |

Frozen tools, from `build/split-320-321/llc/` (assertion builds; hashes equal `evidence/r2/stages.tsv`, and every gated commit's tree equals its final commit's tree):

```text
184095f9338a0de9046f86a97f98a85104bd1e933095eaa739224e4c6fd2b7c4  u594        (06bc967d2668 + #594)
7f7562c7b43dad2921288eb1f34f10ac1d26615e1210662e0b050c366ce546ec  u594-resv   (+ reservation rule only)
7538162716d3665ebcd9100ff4d901782f11f9ff85c7e0f2410d5ff23ec49049  r2-320-1a2
9f8b456100f1b90336b1bf4d19fec2740d5d200c1b658c8e30ddbabcc33de5ce  r2-320-1a3
e4e2c1e171cabffd668a62c9fdf10bb6c97b4bf883d85f0f0985904e8fdec0de  r2-320-1b
f4c0da84e614deba6a728f7926639a1b5be6a2def2beb3dd625654cdf0e4a7e7  r2-320-1c
a5a166005f75950e2d96bf9348bd321b1630f9e44b961044b42c56aa78b08cb9  r2-320-1d
9f52795b3f2eb45c986213fc0e613872d51929e0cea0d07ef98ad1d06a17d22c  r2-320-2
d3a90acf52ac427e3c331e79256cac7e87ca79cf92cc5e51973de2e2d2cd3e26  r2-320-3
70d96dbc4e78218c77cf687ce5383a1bcad72561bbf77986b97b1881d15af1b5  r2-320-4
cda3200958d98920a56af357527f5bd69c8f3e6c5e8961be61f5cd1dee8faf23  r2-fw-9
72341912b4cdd21030a0b8c69de92b0359ad4e8b75a2e96196a8f9efdd2fe9b9  r2-fw-5
e34098a6f568ba546af0c86e71fef17ad68a8fc86423311cee844db7d4bd4f90  r2-fw-11
c90f96487d2fe6d3fa49a8cfc01f9485affdbd4857e4594ee8b87f7bfefcbbcb  r2-fw-14
```

For before-state controls I also used `p-321-00` (upstream base), `c-320-0x`/`c-fw-14` (the reviewed carry) and `p-320-0x` (pre-carry), with the hashes recorded in [review 2](independent-review-2.md). No LLVM build was performed. `llvm-tblgen` from `build/split-320-321/build/bin` generated register info from each commit's `.td` sources in a scratch directory. Every `llc` ran under `ulimit -c 0; ulimit -v 2000000` and `timeout`, with at most three in parallel. The review used a `--shared --no-checkout` scratch clone, so nothing under `build/split-320-321/source` was touched.

## Coordinator results verified

| Claim | Independent result |
|---|---|
| 1a‑i..iii are #594 unchanged except `bits<16>`→`bits<32>` | Confirmed against the public PR head `7b80f7e18768`. The added and removed lines of 1a‑i and 1a‑ii are identical to `a1e2fa5ce11a` and `d3d346169104`. 1a‑iii differs from `7b80f7e18768` in exactly one line, `class MOSImagReg32<bits<32> num, …>`. Author and author date are mlund's. The messages are unchanged apart from a bracketed note on 1a‑iii that states the rebase edit. |
| #594 alone aborts on calls with stack arguments; 1b fixes it | Confirmed. `imag32-reserved-pairs.ll` passes on `p-321-00`, fails on `u594` and `r2-320-1a3` (in `mos6502` and `mosw65816`, with and without the verifier, and at O0), and passes on `u594-resv` and `r2-320-1b`. The record's `variadic-call.ll` fails on `u594` with `Invalid global physical register`. See N19 for the reduced test's different signature. |
| Nine patches round-trip; `patches-split/0019`–`0027` are the #320 patches | Confirmed with `git apply --cached` into a scratch index from `25c40909b44a`. Each tree matches, ending at `11f4fcadc11a`, and the whitespace warning from review 2 is gone. The diff bodies of `0019`–`0027` are identical to `patches-320/0001`–`0009`. |
| Suites: 1a‑iii 166, 1c 168, #320‑4 178, fw‑9 179, fw‑5 180, fw‑14 187 (each + 1 unsupported) | Confirmed with my RUN-line runner on each commit's own tests. The only non-pass in each is `getchar-regression.ll`, which lit marks unsupported. |
| Red/green (27 red, 143 green) | I reran 21 of the rows and more (listed below); all agree with `evidence/r2/red-green.tsv`. |
| Default mode identical to the parent except 1a‑iii's aborts | Confirmed for `mos6502` and `mosw65816`: 51 non-far `CodeGen/MOS` inputs at O0, O2 and Os give byte-identical assembly on `r2-320-1a2`, `-1a3`, `-1b`, `-1d` and `-4` (306 comparisons, 0 differ). **Not true on `mosspc700`** (N17). |
| Replay objects identical to the reviewed packet | Spot-confirmed. `r2-fw-14` on Farblit A16 O2 gives `5283ea31…` and `r2-fw-11` on Farblit XY16 O3 gives `41b1482b…`, the same objects as review 2's rebuild. So the [0070 per-level table](independent-review-2.md#coordinator-results-verified) stands. |
| Our commits are clang-format-clean | Confirmed: `clang-format-diff.py` reports 0 lines for 1a‑i, 1a‑ii, 1b, 1c, 1d, #320‑2, #320‑3, #320‑4 and packet patch 9. #594's register commit reports 11 lines (mlund's code, left unchanged), and packet patch 5 reports 23 lines (review 1's N3, still open for patches 5 and 6). |

## Contracts checked (the brief's focus items)

1. **1a‑iii fidelity.** Verified line by line against the public PR (see the table). The token change is required, because `0x30080` does not fit `bits<16>` after #571 made `MOSReg` numbers 32 bits wide.
2. **1b reservation rule.** Every reservation in `MOSRegisterInfo` is pair-level: `reserveAllSubregs` of RS0, RS8, RS16..RS127 and, when `hasFP`, the frame register. 1b adds exactly the quads that contain one of those pairs (RL0, RL4, RL8..RL63 and the frame-pointer quad). It does not reserve their subregisters, so the free sibling pair (RS1, RS9, …) stays allocatable. That is the minimum: an allocated quad over a reserved pair would clobber it. The unit explanation is right. LLVM treats a register unit as reserved only if its root and every super-register are reserved, so after #594 the RS0 byte units stopped being reserved (RL0 was not). 1b restores exactly the pre-#594 unit state, so default code cannot change by construction; my 306-comparison sample and the implementer's 90-input levels agree.
3. **1c gate.**
   - The generated register info for 1b and 1c has the same six pressure sets. The only table change is Imag32's own class-to-set row, plus a `getRawAllocationOrder` override for Imag32. Unlike the native-width classes, the gate therefore creates no pressure set that default code would see.
   - On non-65816 CPUs, far pointer values cannot reach the allocator: a far argument is stacked, and storing it fails legalization first (N20). So the empty order is defensive and never exercised by IR.
   - Explicit `{rl1}` inline-asm constraints fail the same way on the upstream base (RL did not exist there), and `i32` `"r"` operands fail at translation on every binary. Neither is a regression.
   - Spill-slot sizes and copy costs are only reached for allocated quads.
   - The strong-hint filter only drops hints the allocator would have asserted on (`AllocationOrder` requires hints to be in the order), so it cannot change a compile that previously succeeded.
   - The `CCIf` on `hasAllocatableImag32()` is evaluated per call site's function. On the 65816 it keeps the reviewed RL1–RL3 assignment; B1's stack fallback is unconditional.
   - #594's own `imag32-nonalloc.mir` is deleted by 1c. The 1c message says so, but mlund should hear it in the #594 conversation too.
4. **Patch 10 → 1d.** The token-level edits to `MOSInstrInfo.cpp`, `MOSRegisterInfo.cpp` and `prologepilog.mir` are identical to the reviewed `cf2e7a5df7fb`; only clang-format reflow differs. B9's reproducer (four far pointers live across a call, and review 2's `spill.ll`) is clean on `r2-320-2`, `r2-320-4` and `r2-fw-14` in A16 and XY16 at O0 and O2. `far-quad-spill-call.ll` fails on `c-320-02` with the `expandLDSTStkImpl` assertion and passes on `r2-320-2`.
5. **`isDeadFarAddressTree` / `dropDeadFarAddressDebugUses`** (`MOSLegalizerInfo.cpp`, added in #320‑2).
   - *No live location is dropped.* `isDeadFarAddressTree(R)` holds only if every non-debug user of R is a `G_PTR_ADD` based on R whose result is itself a dead tree. The climb only moves to a base that passes the same test. The collection walk only descends from that dead root. Every register whose `DBG_VALUE` is cleared is therefore dead.
   - *The climb* stops at the first base with a live user. That base is often the new instruction's own base operand, so the fold's own base always stops it.
   - *The three call sites* are right for their fold. Each passes the access's former pointer after the access stops using it: the in-place rewrite in `tryFarAbsoluteAddressing`, the erase in `tryFarRuntimeIndexFold`, and the erase in `tryFarIndirectIndexedAddressing`. Packet patch 5 adds the same call to `tryFarAbsoluteIndexedAddressing`, and that call is its only change against the reviewed patch 5. The other erasing far functions (`legalizeLoadStore16`, `tryFarIndirectAddressing`) keep the access's pointer in use, so they leave nothing dead.
   - *Re-run.* All nine review 2 reproducers (`field`, `store1`, `argoff`, `chain`, `qonly`, `gfield`, `gidx`, `word`, `arglist`) are verifier-clean on `r2-320-4`, `r2-fw-5` and `r2-fw-14` in A16 and XY16 at O0 and O2. Five new far word and extending-load shapes (global word ±, word store, indexed global word, runtime base + 2, zext/sext of global + 3 and base + 2) are also clean on `r2-320-4`, `r2-fw-6`, `r2-fw-7` and `r2-fw-14`. Plain `mosw65816` runs that fail do so with the documented A8 `unable to legalize … G_MERGE_VALUES` limitation, not the verifier; the reviewed carry (`c-fw-14`) still shows the verifier error for `field` and `gidx`.
   - *Live-location control* (`keep.ll`): base + zext offset with `dbg.value` on `p`, then `q = p + 1` with `dbg.value` on `q`, a load through `q`, and a store of `p` that escapes. After the legalizer, `p`'s `DBG_VALUE %3(p2)` is kept and only `q`'s becomes `$noreg`.
6. **N12 and N13.** At #320‑2 a far `memset` that is not inlined now stops with `unable to legalize … G_MEMSET` instead of calling the near runtime; #320‑3 turns it into `jmp __memset_far`. With `customIf(typeIs(1, PF))` ahead of the other rules on non-65816 CPUs, every far access is diagnosed exactly once on `mos6502` (i32 load, i32 store, volatile i16, `<2 x i8>`: one diagnostic each; two accesses: two). Far `atomicrmw` and `memset.inline` at O0 still fail with a loud generic error (N16, unchanged).
7. **N10 and N14 messages.** #320‑3 now says that with a near or direct-page operand the IRTranslator narrows the length first, and that this is sound by LangRef's index-type bound. That is accurate. #320‑2 and the code comment now say far pointer values need quads and are unsupported off the 65816, which is accurate. The 1c message's "every far pointer on other CPUs goes to a 4-byte stack slot" is true of call lowering but reads as if it were supported (N20).
8. **Patch 9 before patch 5.** Each packet commit stands alone. `r2-fw-9` (patch 9 on #320‑4) passes its own suite, 179 + 1. `native-index-copy-cost.mir` is empty-output red on `r2-320-4` and green on `r2-fw-9`. `r2-fw-5` passes 180 + 1, and patch 5's `far-fold-debug.ll` is red on `r2-fw-9` (RUN 28) and green on `r2-fw-5`. Against their reviewed versions, patches 8, 9 and 12 are token-identical, and patch 5 differs only by the B8 call.
9. **DWARF numbering (B5), risk only.** The composite that review 1 reported (a 46-bit piece list) is gone. A far pointer in RL5 is now `DW_OP_regx 0x30085` (bytes `90 85 81 0c`), which `llvm-dwarfdump` names `RL5`. Under the MOS DWARF specification's type‑0x03 (RS) range, a consumer that is not built from this LLVM decodes it as RS index 133. With `MaxImag16Regs = 128` that register does not exist, so the likely outcome is "unknown register". The worse cases are a consumer that computes the address as `__rc(2 × index)` (a nonexistent symbol) or that reads two bytes (an RS width) and shows a truncated far pointer. A future widening of the RS range would silently alias. A defined type code for quads in the specification, or keeping `DwarfNumbers = [-1]` with an explicit, well-formed piece list, avoids this. That is a specification decision for mlund and the maintainers, correctly escalated.

## Findings

| # | Severity | Summary | Location |
|---|---|---|---|
| N17 | Nonblocking (process) | #320‑2's `MOSLateOptimization` guard fixes an upstream `mosspc700` segfault in 15 of 51 default inputs; no default-mode check covers SPC700, and no message states it | `MOSLateOptimization.cpp:290` (#320‑2) |
| N18 | Nonblocking (process) | 1a‑iii (#594 as posted) aborts every call with stack arguments on every CPU until 1b; bisect hazard inside an upstream series | 1a‑iii → 1b |
| N19 | Nonblocking | 1b's message and test comment cite `Invalid global physical register`, but the reduced test fails with `Use not jointly dominated by defs.` | `imag32-reserved-pairs.ll`, 1b message |
| N20 | Nonblocking | A far pointer value on a non-65816 CPU fails with a generic `unable to legalize … G_STORE`/`G_UNMERGE_VALUES`, not the far diagnostic; the 1c message reads as supported | #320‑2 legalizer, 1c message |
| N21 | Nonblocking (quality) | The helper drops constant-offset adds' locations to `$noreg` although `base + DW_OP_plus_uconst k` is expressible | `dropDeadFarAddressDebugUses` |
| N22 | Nonblocking (records) | `mos-far-fold-dangling-dbg-sites.json` is still `confirmed` although same-input red (`c-320-04`, `c-fw-14`) and green (`r2-320-4`, `r2-fw-5`) runs exist | `docs/defects/` |

### Nonblocking findings

- **N17 (bundled upstream fix).** On `mosspc700 -O2`, 15 of the 51 non-far `CodeGen/MOS` inputs segfault in "MOS Late Optimizations" on the upstream base `p-321-00`. The inputs include `fcmp.ll`, `char-stats.ll`, `light-spill.ll`, `shift-rotate.ll`, `zp-alloc.ll` and `vector-scalarize.ll`. They also segfault on `u594`, `c-320-01` and `r2-320-1a2`..`r2-320-1d`, and they compile from #320‑2 on (`c-320-02`, `r2-320-2`, `r2-320-4`). The #320‑2 hunk that restricts `combineLdImm` to `GPRRegClass` destinations is the likely cause; the backtrace names `MOSLateOptimization`. It is a real upstream defect fix hidden in a far commit: the "Default-mode effect: none" check runs only `mos6502` and `mosw65816`. Split the `MOSLateOptimization` change into its own commit (or its own upstream PR) with an SPC700 regression test, record it under the defect workflow, and extend the default-mode check to the other MOS CPUs. `mos65c02`, `mos65ce02`, `mos45gs02`, `moshuc6280` and `mos65el02` are unchanged between `r2-320-1a2` and `r2-320-4` in my sample.
- **N18 (bisect hazard).** Keeping mlund's commit byte-for-byte means 1a‑iii ships a default-mode abort that 1b repairs. The coordination draft already lists the defect, so ask mlund to fold the reservation rule into #594 before it lands. If #594 lands as posted, 1b becomes an upstream fix PR of its own.
- **N19.** `imag32-reserved-pairs.ll` fails on `u594`/`r2-320-1a3` with `Use of $rs0 does not have a corresponding definition on every path … LLVM ERROR: Use not jointly dominated by defs.`, which is also in the red/green table. The record's longer `variadic-call.ll` gives `Invalid global physical register`. Name both signatures in the message and the test comment.
- **N20.** `call void @use(ptr addrspace(2) %p)` on `mos6502` (`r2-320-4`) fails with `unable to legalize … G_UNMERGE_VALUES %5:_(s32)`. That is loud, but it is not the purpose-written far diagnostic. The upstream base compiled the same IR, because without `p2:32:8` in the layout an `addrspace(2)` pointer was 16 bits. That is inherent to the data-layout change in 1c (unchanged since review 1), but the PR should say that `addrspace(2)` changes meaning on every MOS CPU. Consider diagnosing far pointer values off the 65816 the same way as far accesses.
- **N21.** For a constant-offset add (`q = p + 1`), a salvage to `DBG_VALUE p, DW_OP_plus_uconst 1` would keep `q` visible in a debugger instead of "optimized out". This is a quality improvement, not a correctness one.
- **N22.** The record already has the evidence for closure. Close it with the red and green runs above, as the defect workflow requires.

## What I re-verified

`R` is my RUN-line runner, which runs each file's RUN lines with the named frozen `llc` and the split build's tools. Every command ran under `ulimit -c 0; ulimit -v 2000000` with `timeout`.

| Item | Command | Red | Green |
|---|---|---|---|
| 1b | `R … imag32-reserved-pairs.ll` | `u594`, `r2-320-1a3`: `Use not jointly dominated by defs.` | `p-321-00`, `u594-resv`, `r2-320-1b` |
| 1c | `R … imag32-allocation-gate.mir` | `r2-320-1b` FAIL | `r2-320-1c` PASS |
| B9 | `R … far-quad-spill-call.ll` (#320‑2 version) | `c-320-02`: `expandLDSTStkImpl` assertion | `r2-320-2` |
| B8 (#320‑2) | `R … far-fold-debug.ll` (#320‑2 version) | `r2-320-1d`: p2 not legal | `r2-320-2` |
| B8 (#320‑4) | `R … far-fold-debug.ll` (#320‑4 version) | `r2-320-3` RUN 9, `c-320-04` RUN 2: `DROP` not found | `r2-320-4` |
| B8 (patch 5) | `R … far-fold-debug.ll` (patch 5 version) | `r2-fw-9` RUN 28, `c-fw-14` RUN 2 | `r2-fw-5` |
| B4 | `R … far-index-fold-debug.ll` | `r2-320-3` RUN 2 | `r2-320-4` |
| B2 / N12 | `R … far-memop-length.ll` | `r2-320-2`: `unable to legalize … G_MEMSET` | `r2-320-3` |
| B3 / N13 | `R … far-access-non-65816.ll` | — | `r2-320-4` |
| Patch 9 | `R … native-index-copy-cost.mir` | `r2-320-4`: `'<stdin>' is empty` | `r2-fw-9` |

Other runs:

- Suites: `R` over each commit's own `CodeGen/MOS` and `MC/MOS` files. `r2-320-1a3@fcb88211d861`: 166 + 1. `r2-320-1c@dcb9d3227be9`: 168 + 1. `r2-320-4@d19b7155d3c6`: 178 + 1. `r2-fw-9@8802a1b438df`: 179 + 1. `r2-fw-5@a252fae7ee3f`: 180 + 1. `r2-fw-14@c275e191de52`: 187 + 1. The + 1 is always `getchar-regression.ll`.
- Default mode: 51 inputs × {`mos6502`, `mosw65816`} × {O0, O2, Os} on five binaries gave 0 differences. 51 inputs × six other CPUs at O2 (`r2-320-1a2` vs `r2-320-4`) gave only the 15 `mosspc700` segfault→compile changes of N17.
- Replay: two objects rebuilt with `r2-fw-14` and `r2-fw-11` match the reviewed hashes.
- Probes: B8 (review 2's nine shapes plus six new word, extending-load and live-location shapes), B9 (`min4.ll`, `spill.ll`), 1c effects (`{rl1}` asm, `i32` asm, far value passing, far `select`) across `p-321-00`, `u594`, `r2-320-1c` and `r2-320-4`, and the DWARF bytes of an RL location.

## Status of all findings

| # | Finding | Status after the second round |
|---|---|---|
| B1 | Far-pointer arg exhaustion | **Fixed**; RL1–RL3 now gated to the 65816, stack fallback unconditional. |
| B2 | Far memop lengths > 65535 | **Fixed**. |
| B3 | Far access on non-65816 CPUs | **Fixed**; one diagnostic per access (N13). |
| B4 | Runtime-index fold dangling `DBG_VALUE` | **Fixed**, now through the shared helper. |
| B5 | Far-quad DWARF | **Open, awaiting mlund.** The malformed composite is gone; `0x30080 + K` falls in the RS type range (risk above). |
| B6 | s32→s16 `G_TRUNC` assertion | **Fixed** (unchanged). |
| B7 | Imag32 vs #594 | **Implemented as option 1; awaiting mlund's answer** (allocation gate, the 1b defect, numbering). |
| B8 | Dangling `DBG_VALUE` at other far fold sites | **Fixed** at #320‑2, #320‑4 and packet patch 5; record not yet closed (N22). |
| B9 | #320 not standalone (quad spills) | **Fixed**: patch 10 is 1d, token-identical. |
| N1 | X16↔Y16/A16 copies | Open (packet patch 9 unchanged). |
| N2 | Patch 11 diff size | Open. |
| N3 | clang-format | Fixed for our #320 commits; open for packet patches 5 and 6, and for #594's commit (mlund's). |
| N4 | History tags | Fixed; none remain in the #320 patches. |
| N5 | Hidden options | Open. |
| N6 | Container-alias records | Fixed. |
| N7 | Loud unsupported far shapes | Open (PR list). |
| N8 | Sensitivity runner coverage | Open. |
| N9 | Overlap with #593, #601, #585 | Open. |
| N10 | Mixed-space memop lengths | **Fixed** (message states the LangRef argument; test added). |
| N11 | SDK far runtime entries | **Queued** in `upstream-contribution-status.md`, not drafted; must land with or before #320. |
| N12 | #320‑2 near-runtime memop | **Fixed**: loud until #320‑3. |
| N13 | Repeated diagnostics | **Fixed**. |
| N14 | "Stays legal on every CPU" | **Fixed** (wording); see N20. |
| N15 | Test tags, trailing blank line | **Fixed**. |
| N16 | Far atomics unsupported | Open (loud; PR list). |
| N17–N22 | This review | New, all nonblocking. |

## Verdict for 0069/0070 and the #320 prerequisite

**They can file once mlund answers the #594 points.** Those points are:

1. whether #594 absorbs the reservation fix (B7, N18);
2. the RL DWARF numbering (B5);
3. the allocation gate and deleted test (1c).

If an answer changes the numbering, the gate or the #594 commits, re-gate the affected commits and rerun this review's B8/B9 probes. Before posting, also:

1. Have N11's SDK companion ready.
2. Decide N17: split the SPC700 fix out, or state it.
3. Fix the N19 and N20 wording.

N21 and N22 can follow.

## Limits

- All binaries are assertion builds.
- I did not check which exact `MOSLateOptimization` hunk fixes N17, beyond the backtrace and the commit boundary.
- The SPC700 sample is my 51 test inputs, not the corpus.
- I rebuilt two of the 58 replay objects and trusted the recorded MAME/bsnes results for the rest.
- My runner does not evaluate `REQUIRES`.
- Packet patches 6, 7, 11, 13 and 14 were checked through their suites and the B8 probes only.
- mlund's intentions for #594 were not consulted; the coordination comment is still a draft.

## Attribution

Third independent review, probes and this record: **Claude Code 2.1.285**, agent type `t4-opus-high` (agent `a86560004d12c0518`, the same subagent that wrote review 2, resumed), model **`claude-opus-5-5` (Claude Opus 5.5)**, **high** reasoning effort, read from this subagent's transcript metadata. It ran as a subagent of session `310aee67-a99e-4b78-ba48-c560322fe80d` ([session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F)). The second-round implementation was made by a different agent. mlund keeps authorship of 1a‑i..iii, and earlier contributors keep the credits recorded in their commits and documents.
