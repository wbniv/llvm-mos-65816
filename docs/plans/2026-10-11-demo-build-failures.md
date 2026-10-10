# Capture the three demo build failures (ascast, ascast_sim, lzss-gallery)

TODO item: **Capture the three demo build failures** (`[wip T4]`, Open section). Original report: the
[link-reserve log](../defects/evidence/2026-10-01-snes-soft-stack-collision/link-reserve/preexisting-demo-build-failures.log).
Scope: capture, reconcile, narrow and propose. **No compiler change, no rebuild, nothing posted upstream.**

Records:

- [`mos-a16-return-byte-ac16-transit-exhaustion`](../defects/mos-a16-return-byte-ac16-transit-exhaustion.json): `lzss-gallery`, status **confirmed**.
- [`mos-default-mode-far-cast-legalization`](../defects/mos-default-mode-far-cast-legalization.json): `ascast` and `ascast_sim`, status **contract clarification**.

Evidence: [`docs/defects/evidence/2026-10-11-demo-build-failures/`](../defects/evidence/2026-10-11-demo-build-failures/)
(`probe.sh`, `probe-llc.sh`, `identity.json`, `runs/<toolchain>/*.log`).

No visible surface: this work produces records and evidence only, so there are no mockups.

Attribution: Claude Code 2.1.295, `t4-opus-high` agent `a4b2414005f3ae41c`, model Claude Opus 5.5
(`claude-opus-5-5`), high reasoning effort; session `72f6d6de-6687-477a-bb4c-b186f9d1ba7f`
([claude.ai session](https://claude.ai/code/session_012Tm5osWxSMUvv28Uw7nudx)). Verified from the
agent transcript metadata.

## Toolchains

| Name | Host path | Binary sha256 |
|---|---|---|
| current shared install (0f031168a7cc, XY16 preserveX repair) | `build/llvm-mos-install` | llc `a78958b0194092f58a62c779b5059330a31a6c365620343cb4031f24a9fad16b`, clang-24 `ceff21dd020e3bd121a7b000482fa7ae024044080c1833a087c1a51107841989` |
| previous shared install (rollback) | `build/llvm-mos-install.6f303945` | llc `6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19`, clang-23 `e532fbee9b78871393d3f990b72dc66cec8e7d04b3443621f40a7fd8cf3822b9` |
| pin f24948c7d1a4 install | `build/llvm-mos-f24948c7d1a4-install` | llc `f68dae297924c7ed…`, clang-24 `da3fe645bd57bc62…` (full hashes in `identity.json`) |
| split series, round seven (read only) | `build/split-320-321/llc/{r7-321-16,r7-320-4,r7-fw-12,p-321-00}` | in `identity.json` |
| upstream llvm-mos 0f031168a7cc | `/opt/llvm-mos` in the dev container | clang-24 `8968d9dffc6d7bcec36149e47b9ec15d451c0ce12813f16861ab1d43046ebedf` |

The SDK for the link-shaped runs is the shared `build/install`; its stamp (built by clang `e532fbee…`) and
the hashes of the 49 SNES/common SDK files used are in `identity.json`. The second toolchain in the original
log (clang-23 `e532fbee…`) is the clang of `build/llvm-mos-install.6f303945`, so those runs replay the log's
"new" leg exactly. Its "old" leg (clang-23 `254624ba…`, pre-0071) is not on disk; that leg stays historical.

## Prior-work reconciliation

Full searches and findings: [`gallery/prior-work.json`](../defects/evidence/2026-10-11-demo-build-failures/gallery/prior-work.json)
and [`ascast/prior-work.json`](../defects/evidence/2026-10-11-demo-build-failures/ascast/prior-work.json).

- **No structured record** existed for either failure. Both were seen before and left uninvestigated: the
  gallery in the 2026‑09‑27 near-proof census (`census-failures.json`, non-LTO `-Os`, a16 and xy16) and both in
  step 6 of [the far-prerequisite plan](2026-09-30-far-prerequisite-defects.md) (identical on baseline and candidate).
- **Missing `mos-a16-only` marker — confirmed for ascast.** `083d8d00` added `ascast.c` and `corpus/ascast_sim.c`
  without it; the far type lives in `examples/65816/ascast.h`. The demo's own [plan](2026-09-28-round8-cluster-d-abi-and-memory-widths.md)
  says the far path is checked only in `+mos-a16`, `dev/round8d-demo.sh` builds ascast in a16 mode only, and
  `corpus/expected.tsv` omits it. Only `dev/build.sh`, which reads the marker, builds it in default mode.
- **Default-mode far-pointer limit — this is what ascast hits.** It is documented as deliberate
  ([far addressing audit](../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md)) and is
  called "the existing plain-mode limit" in [`mos-far-pointer-arg-exhaustion`](../defects/mos-far-pointer-arg-exhaustion.json),
  but no record owns it.
- **Known allocation defects — the gallery is in the a16regpress family but not covered by it.**
  [The a16regpress root cause](../investigations/65816-a16-regalloc-pressure-failure.md) is an unspillable
  single-instruction `Ac16` transit that cannot get `$a16` while an A-pinned add counter sits in `$a`; patch
  `0009` de-pins that counter. Here the squatter is a `gpr` return byte. `0009`'s source is in both pin
  checkouts, and its regression input `a16regpress.c` compiles at `-O1` and `-Os` on all three installs, yet
  this failure persists. [`twoaddr-physreg-reschedule-exhaustion`](../defects/twoaddr-physreg-reschedule-exhaustion.json)
  (default mode, physical-register extension) and [`mos-spc700-hint-outside-order`](../defects/mos-spc700-hint-outside-order.json)
  (SPC700) have other triggers.

## Failure 1: ascast and ascast_sim

**Pass: Legalizer. Construct: a near-to-far `addrspacecast` (`G_ADDRSPACE_CAST p0 -> p2`) without `+mos-a16`.**

`ac_to_far` is a bare `(AS_FAR const uint8_t *)p`. In every mode `MOSLegalizerInfo` custom-lowers the cast to a
zero-extension, `G_MERGE_VALUES` of four `s8` (low, high, bank `0`, `0`). The `{S32,S8}` and `{S32,S16}` merge
rules exist only under `hasAccum16()`, so default mode reports `unable to legalize instruction: %3:_(s32) =
G_MERGE_VALUES %4:_(s8), %5:_(s8), %6:_(s8), %6:_(s8) (in function: ac_to_far)`. With `+mos-a16` the same cast
becomes `G_MERGE_VALUES(s16 ptrtoint, s16 0)`, which is legal.

| Build | 0f031168 | 6f303945 | f24948c7 |
|---|---|---|---|
| `ascast_sim.i` default, `-O0` through `-Oz` | fail ×6 | fail ×6 | fail ×6 |
| `ascast_sim.i` `+mos-a16`, `-O0` through `-Oz` | pass ×6 | pass ×6 | pass ×6 |
| `ascast_sim.i` `-mcpu=mos6502 -Os` | fail | fail | fail |
| `dev/build.sh`-shaped links of both programs (no marker) | fail | fail | fail |
| the same links with the marker's flags (`-mcpu=mosw65816 +mos-a16`) | pass | pass | pass |

**Upstream.** Upstream llvm-mos has no far address space. `/opt/llvm-mos` fails earlier on the same input
(`unable to legalize … G_LOAD %6:_(p2)` in `ac_read`), as do the split base `p-321-00` and `#321` top
`r7-321-16`. The `#320` top `r7-320-4` and far-word top `r7-fw-12` fail exactly like downstream, so the
upstream-bound `#320` series defines this default-mode behaviour.

**Proposed fix (demo, no compiler change).** Add `// mos-a16-only: the near-to-far cast ladder needs the 16-bit
accumulator for its 32-bit far pointers.` to `examples/snes/ascast.c` and `examples/snes/corpus/ascast_sim.c`.
Verified by the "marker's flags" row: `dev/build.sh` would then pass exactly those flags. Risk: none to codegen;
the battery loses a default-mode build that never worked.

**Compiler contract (open, user or upstream decision).** Today default mode accepts the far type and the far
load, then aborts on the cast. Options, none implemented: (a) keep the limit and replace the fatal error with a
diagnostic naming `+mos-a16` (for example, gate `G_ADDRSPACE_CAST` custom lowering to `hasAccum16()` and report
it from the target); (b) legalize `{S32,S8}` merges in default mode into the `Imag32` quad that default far
loads and returns already use. Option (b) is a `#320` design change.

**Optimization level.** The failure is the same at `-O0` through `-Oz`, and the marker fix and both compiler
options are correctness or diagnostic changes, so nothing here can or should be gated by level.

## Failure 2: lzss-gallery `record_result`

**Pass: Greedy Register Allocator.** The failed virtual register is the single-instruction `Ac16` transit for
the volatile 16-bit store, `%99:ac16 = LDAImag16 %31; STAbs16 %99, @corpus_result` (after greedy its use is
`STAbs16 undef $a16`; `regalloc=basic` allocates the same MIR).

**Construct.** `record_result` returns an `i16` `gate` that is either the incoming argument or a select of
`0x9512` and `0x1512`, the value that is also stored volatile to `corpus_result`. The two constants share the
low byte `0x12`, so after legalization the return value's low byte is one `gpr` virtual register that is the
incoming `$x` byte on one path and `LDImm 18` on the other. Cross-block coalescing makes it a single live range
from function entry to `RTS`, hinted to `$a` by the return copy. Greedy assigns it `$a` across the `Ac16` transit
and does not evict or split it out, although `$x`/`$y` are free there, so the unspillable transit cannot get
`$a16` and allocation fails.

Evidence on the reduced inputs (all three toolchains agree):

| Reduced input | Result |
|---|---|
| `record-result-reduced.c`, default mode, `-O0` through `-Oz` | pass |
| the same, `+mos-a16` and `+mos-a16 +mos-xy16`, `-O1` through `-Oz` | fail; `-O0` (fast allocator) passes |
| `record-result-reduced.ll` through `llc`: as is / `-regalloc=basic` / `-join-globalcopies=false` / `-enable-misched=false` | fail / pass / pass / pass |
| `record-result-min.pre-greedy.mir`, `-run-pass=greedy` / `-run-pass=regallocbasic` | fail / pass |
| the same MIR with the return byte copied to `$y` instead of `$a` | pass |

Full program: the non-LTO preprocessed TU fails at `-O1`, `-O2` and `-Os` and compiles at `-O3` and `-Oz`; the
`dev/build.sh`-shaped LTO link fails at `-Os` and `-O2`; the gate and publish link (`dev/lzss-gallery.sh`,
`-Oz`) links on all three toolchains, so **the published ROM build is not affected**. The reduced input fails at
`-Oz` too, so the gallery's `-Oz` pass depends on its surrounding code, not on the level. On the full LTO
module, `-join-globalcopies=false` also avoids the failure, while `-enable-misched=false` alone does not.

**Upstream.** `+mos-a16` is not in upstream llvm-mos (`/opt/llvm-mos` ignores it and compiles the reduced
input). The upstream-bound series carries the defect: the reduced IR fails on `r7-321-16`, `r7-320-4` and
`r7-fw-12`.

**Not established.** Which greedy decision refuses the eviction or split (cascade, stage or hint-cost rule)
needs `-debug-only=regalloc` on an assertions build with `+mos-a16`. No such build exists on this machine:
every assertions build here is upstream-shaped and ignores the feature. Building one is outside this task
(disk and the no-rebuild constraint).

**Proposed fixes (not implemented; each needs that pinpoint before it is chosen):**

1. **Hint:** in `MOSRegisterInfo::getRegAllocationHints`, drop the `$a` copy hint for an 8-bit virtual
   register whose live range overlaps the definition of an `Ac16`/`A16` virtual register. The `$y` control above
   shows that, with the hint and return in another register, greedy succeeds. Risk: a missed `$a` hint costs a
   transfer at the return. Gate on `hasAccum16()` so default mode cannot change.
2. **Coalescing:** in `MOSRegisterInfo::shouldCoalesce`, refuse a cross-block join that makes an 8-bit range
   span an `Ac16` transit (both inputs pass with `-join-globalcopies=false`). Risk: the a16regpress note
   warns that coalescing barriers can undo A16-threading wins (`dev/measure-a16-threading.sh` must stay flat)
   and must not disturb the `a16localx.c` coalescer guard.
3. **Selection:** store a volatile `i16` assembled from two byte values with two 8-bit stores instead of an
   `Imag16`/`Ac16` round trip. This removes this transit only, not the class of failure.

Regression for any of them: `record-result-reduced.c` at `-O1`, `-O2`, `-O3`, `-Os`, `-Oz` in a16 and xy16,
the two MIR files at `-run-pass=greedy`, the full gallery at `-Os` and `-Oz`, `a16regpress` and `a16localx`,
the a16 suite and a fuzz run.

**Optimization level.** This is a compile failure on valid input at every level from `-O1` to `-Oz`, so the
repair itself cannot be gated off at any level. Only the codegen cost of the chosen fix can differ: measure
size at `-Os`/`-Oz` and cycles at `-O2`/`-O3` for candidates 1 and 2, and use a level gate only for a
profitability-only part of a fix, never for the part that removes the failure.

**Battery versus gate.** `dev/build.sh` builds every demo at `-Os`; the gallery's gate and published ROM use
`-Oz`. A battery opt-level marker would make the battery build the shipping configuration, but it would also
hide this defect from the battery. Under the "demos exist to find compiler bugs" rule, keep the battery
failing until the defect is fixed, or add the marker only together with a standing reduced regression that
fails on today's compiler.

## Verification

1. Reproduce both original signatures on the current and previous installs.

    ```
    $ docs/defects/evidence/2026-10-11-demo-build-failures/probe.sh build/llvm-mos-install 0f031168-a78958b0   (and the 6f303945 and f24948c7 installs)
    gallery-battery-link-Os	1
    gallery-gate-link-Oz	0
    ascast-battery-link-Os	1
    ascast-sim-battery-link-Os	1
    ascast-marker-link-Os	0
    ascast-sim-marker-link-Os	0
    LLVM ERROR: unable to legalize instruction: %3:_(s32) = G_MERGE_VALUES %4:_(s8), %5:_(s8), %6:_(s8), %6:_(s8) (in function: ac_to_far)
    ld.lld: error: <unknown>:0:0: ran out of registers during register allocation in function 'record_result'
    runs/0f031168-a78958b0/summary.tsv md5 851735a9882279a9d2936bf387b5e2b4 lines 51
    runs/6f303945-pre-xy16-repair/summary.tsv md5 851735a9882279a9d2936bf387b5e2b4 lines 51
    runs/f24948c7-f68dae29/summary.tsv md5 851735a9882279a9d2936bf387b5e2b4 lines 51
    ```

    PASS: both failures reproduce on all three toolchains with identical exit codes for all 51 runs, so they
    are independent of the XY16 repair.

2. Narrow each failure to a pass and a construct with retained inputs.

    ```
    gallery-reduced-default-O0	0
    gallery-reduced-a16-O0	0
    gallery-reduced-xy16-O0	0
    gallery-reduced-default-O1	0
    gallery-reduced-a16-O1	1
    gallery-reduced-xy16-O1	1
    gallery-reduced-default-O2	0
    gallery-reduced-a16-O2	1
    gallery-reduced-xy16-O2	1
    gallery-reduced-default-O3	0
    gallery-reduced-a16-O3	1
    gallery-reduced-xy16-O3	1
    gallery-reduced-default-Os	0
    gallery-reduced-a16-Os	1
    gallery-reduced-xy16-Os	1
    gallery-reduced-default-Oz	0
    gallery-reduced-a16-Oz	1
    gallery-reduced-xy16-Oz	1
    gallery-full-tu-a16-Os-nolto	1
    gallery-full-tu-a16-Oz-nolto	0
    gallery-ir-llc	1
    gallery-ir-llc-basic	0
    gallery-ir-llc-no-global-join	0
    gallery-ir-llc-no-misched	0
    gallery-mir-greedy	1
    gallery-min-mir-greedy	1
    gallery-min-mir-basic	0
    gallery-min-mir-greedy-return-in-y	0
    ascast-sim-default-O0	1
    ascast-sim-a16-O0	0
    ascast-sim-default-O1	1
    ascast-sim-a16-O1	0
    ascast-sim-default-O2	1
    ascast-sim-a16-O2	0
    ascast-sim-default-O3	1
    ascast-sim-a16-O3	0
    ascast-sim-default-Os	1
    ascast-sim-a16-Os	0
    ascast-sim-default-Oz	1
    ascast-sim-a16-Oz	0
    ascast-sim-default-Os-before-legalizer	1
    ascast-sim-a16-Os-after-legalizer	0
      %1:_(p2) = G_ADDRSPACE_CAST %0:_(p0)
        dead $a16 = LDAImag16 undef %31
        STAbs16 undef $a16, @corpus_result :: (volatile store (s16), align 1, !tbaa !8)
        $a = COPY %116
    ```

    PASS: Greedy Register Allocator (the `Ac16` transit fails while the return byte holds `$a`) and Legalizer
    (`G_ADDRSPACE_CAST` p0 to p2 in default mode).

3. Check upstream and the upstream-bound series.

    ```
    upstream-opt-llvm-mos	ascast-sim-default-mosw65816-Os	1
    upstream-opt-llvm-mos	ascast-sim-default-mos6502-Os	1
    upstream-opt-llvm-mos	gallery-reduced-a16-Os	0
    split-r7-320-4	gallery-ir-llc	1
    split-r7-320-4	gallery-ir-llc-basic	0
    split-r7-320-4	ascast-sim-default-ir-llc	1
    split-r7-321-16	gallery-ir-llc	1
    split-r7-321-16	gallery-ir-llc-basic	0
    split-r7-321-16	ascast-sim-default-ir-llc	1
    split-r7-fw-12	gallery-ir-llc	1
    split-r7-fw-12	gallery-ir-llc-basic	0
    split-r7-fw-12	ascast-sim-default-ir-llc	1
    split-p-321-00	gallery-ir-llc	0
    split-p-321-00	gallery-ir-llc-basic	0
    split-p-321-00	ascast-sim-default-ir-llc	1
    runs/upstream-opt-llvm-mos/ascast-sim-default-mosw65816-Os.log: unable to legalize instruction: %7:_(s8) = G_LOAD
    runs/split-r7-320-4/ascast-sim-default-ir-llc.log: unable to legalize instruction: %3:_(s32) = G_MERGE_VALUES
    runs/split-r7-321-16/ascast-sim-default-ir-llc.log: unable to legalize instruction: %7:_(s8) = G_LOAD
    runs/split-p-321-00/gallery-ir-llc.log: is not a recognized feature
    ```

    PASS: neither failure exists upstream in this form; both are carried by the split series.

4. Records pass the evidence checker.

    ```
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (43 records, worktree)
    ```

    PASS.
