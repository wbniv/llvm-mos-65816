# #321 upstream series addition — preserve unknown 65816 M/X state across C interrupts

<!-- CURRENT DECISION (2026-08-03): keep local in holistic patch 0002. There is no #321 PR. -->

## Current upstream disposition

This is implemented and verified locally, but it is **not posted upstream**. GitHub #321 is an
issue, not a pull request, and none of the currently open upstream PRs carries `0002`. Keep this
change folded into the complete native-width patch; do not combine it with the unrelated focused
PRs #577, #578, #579, or #584.

If `0002` is submitted later, present it as the complete opt-in native-width implementation tracked
by #321—not as a "first stage"—and reorganize the large patch into a reviewable commit series under
one draft PR. The interrupt envelope belongs in that series because it completes the native-width
ABI contract at asynchronous entry boundaries. The canonical submission plan is
[321-upstream-native-width-pr](321-upstream-native-width-pr.md).

## Series placement

Fold this change into the holistic `#321` native-width patch/series, immediately after the
`MOSInsertREPSEP` mode-state work. It completes the same contract at asynchronous boundaries:
ordinary calls enter and return M8/X8, CFG edges carry a known state, while interrupts may arrive
from either width and must restore exactly what they interrupted.

## Problem

The 65816 hardware stacks P on interrupt but leaves the live M/X flags unchanged. The MOS backend
previously emitted `cld; pha; ...` while assuming ordinary M8/X8 C entry. If NMI arrived in an
M16/X16 region, width-sensitive pushes and subsequent instructions used the inherited widths,
unbalancing the generated save/restore sequence.

Round 7 demo #123 made the failure repeatable: default M8/X8 returned `0xDA3B`; a16 returned
`0xF4F4` or `0x0000` depending on the interrupt landing point; xy16 returned `0x0000`.

Framing for upstream: this is **not a latent defect in existing llvm-mos** — without
`+mos-a16`/`+mos-xy16`, generated code never leaves M8/X8 and the stock prologue's assumption
always holds. The hazard is created by the opt-in native-width feature itself, and #123 was the
first interrupt handler ever compiled under it. The envelope is therefore new ABI surface that
completes the feature's contract at asynchronous entry boundaries (with defect-severity stakes:
the miscompilation was silent), which is why it belongs inside the #321 series rather than as a
standalone bug fix.

## Fix

`MOSFrameLowering` gives native-mode 65816 interrupt functions a fixed outer envelope:

```asm
rep #$30
pha
phx
phy
sep #$30
; ordinary generated ISR body under the C ABI's M8/X8 state
...
rep #$30
ply
plx
pla
rti
```

The full-width pushes preserve A/B, X, and Y independently of the interrupted widths. `RTI` then
restores the hardware-stacked P, including the original M/X flags. `no-isr` remains the opt-out.

## Tests and live demonstration

- LLVM regression: `llvm/test/CodeGen/MOS/interrupt-width-65816.ll` asserts the exact envelope.
- Runtime: host == default == a16 == xy16 == `0xDA3B`; a16 passes three deterministic repetitions.
- Machine verification is clean on every build.
- Runnable ROM and illustrated explanation: [https://biohack.net/snes/nmitally/](https://biohack.net/snes/nmitally/).

No standalone patch is carried: source, LLVM test, and the live-demo URL are folded into
`patches/llvm-mos/0002-321-accum16.patch` as part of the #321 series.

After a #321 draft PR is actually posted, refresh wald3n.com's contributions snapshot so its public
tracking entry can link the upstream PR. Until that PR URL exists, the wald3n.com update remains
intentionally pending rather than inventing a standalone contribution record.
