# SDK native-65816 setjmp/longjmp support

**Assessed 2026-09-20. Not posted.** Target: `llvm-mos/llvm-mos-sdk`.
This is a platform-support gap with a working downstream fix, not a fixless report.

## What fails

The common SDK implementation assumes a 6502 page-1 hardware stack: return-address
access uses `$101,x`/`$102,x`, the saved stack pointer is one byte, and restoration
uses `tax; txs`. In 65816 native mode with 8-bit index registers, restoring that
value does not restore the required page-1 high byte of the native stack pointer.
Our SNES reproduction reaches the pre-jump sentinel `0x1111` but not the expected
post-jump `0x2007`.

The current upstream [assembly](https://github.com/llvm-mos/llvm-mos-sdk/blob/3f6968bbc156ff9a63102a8e158db868819bd61c/mos-platform/common/c/setjmp.S)
and [jmp_buf layout](https://github.com/llvm-mos/llvm-mos-sdk/blob/3f6968bbc156ff9a63102a8e158db868819bd61c/mos-platform/common/include/setjmp.h)
still use that representation. This refresh verified source, not a new native-mode
emulator run; the runtime evidence is in the [investigation](investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md).

## Fix already available, with a specific contract

Our [SNES override](../platforms/snes/setjmp.S) keeps the 19-byte buffer ABI and
reconstructs `S = $01xx` using `TCS`, with stack-relative return-address accesses.
It requires the platform to keep the hardware stack in page 1 and to establish the
specified register widths. It is not a general arbitrary-stack-page 65816 library.
The existing host/MAME/bsnes-jg evidence records the expected `0x2007` result.

## Upstream route

SDK `main` currently has no SNES target or 65816 setjmp override. Existing
[SNES PR #415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) is **open, not marked
draft**, head `e6a5c17cab52`; it has not merged. Reconcile our native startup,
stack/width contract, vectors and this override with that platform work.

If the initial platform remains in emulation mode, common setjmp's stack assumption
is not this native-mode problem. If it enters native mode, the corresponding runtime
fix belongs in the same platform change or a dependent PR. There is no need to wait
for the platform to merge before proposing both together.

A standalone issue is useful for agreeing the supported mode/ABI; it is not a
prerequisite to writing a fix, because our page-1 implementation already exists.
Do not report it as a demonstrated regression on an already-supported upstream
native SNES target.

## Separate common-SDK bug: longjmp with zero

The common implementation also returns the supplied value unchanged. C requires
`longjmp(env, 0)` to make setjmp return **1**. This affects ordinary 6502 execution
and can be fixed independently of SNES. Current upstream assembly reproduced the
failure in mos-sim; a small candidate fix passed 20 cases across four optimization
levels. SDK CTest integration also passes all 20 with freshly built current SDK
libraries and simulator; see [integrated validation](pr-preparations/2026-09-20/sdk-longjmp-validation.md). See the [candidate assessment](upstream-pending-work.md) and
[validation matrix](pr-preparations/2026-09-20/sdk-longjmp-matrix.txt).

The new zero-value defect also exists in our native SNES override's unnormalized
return sequence. Its integration should incorporate the normalization too; the
20-case simulator matrix validates the common 6502 routine, not that native override.

The independent common-runtime normalization fix is now posted as [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450).
The native SNES stack-support work remains separate.
