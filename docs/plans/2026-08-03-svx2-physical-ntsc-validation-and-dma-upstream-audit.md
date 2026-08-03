# SVX2 bsnes-jg validation and DMA compiler-upstream audit

**Date:** 2026-08-03

**Status:** Complete

**Public artifact:** [SVX2 FastROM Animated Video](https://biohack.net/snes/svx2-fastrom-video/)

**ROM SHA-256:** `c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2`

The filename retains the plan's original name for stable links. Validation is emulator-only; this
project has no physical SNES hardware and none is required.

## Outcome

- [x] Download the published ROM and require its SHA-256 and 8 MiB size.
- [x] Rebuild the same artifact from hash-pinned video sources.
- [x] Require the public and rebuilt ROMs to be byte-identical.
- [x] Validate title exit, cadence, scene cuts, the frame-600 ExHiROM seam, looping, transport, and
  bidirectional seam crossings with bsnes-jg.
- [x] Run a long deterministic soak with presentation, deadline-slip, and composite-health gates.
- [x] Audit the earlier DMA-source-address diagnosis against pristine upstream llvm-mos.

The emulator evidence and verdict are in
[`2026-08-03-svx2-bsnes-validation.md`](../investigations/2026-08-03-svx2-bsnes-validation.md).
The compiler decision is in
[`2026-08-03-dma-source-address-upstream-audit.md`](../investigations/2026-08-03-dma-source-address-upstream-audit.md).

## Reproduction

Run the complete artifact and emulator gate:

```sh
dev/svx2-emulator-validation.sh
```

Run the independent pristine-upstream compiler audit:

```sh
dev/dma-source-address-upstream-audit.sh
```

## Emulator acceptance record

The authoritative `dev/snes-video-artemis-apollo.sh` run passed:

- 1,200 unique quantized frames with no adjacent holds;
- expected ExHiROM offsets `$3EF147`, `$3F0000`, and `$3F0F0C` at frames 599–601;
- exact frame-599 and frame-600 image/dashboard captures;
- deterministic pause, step, resume, forward crossing, and reverse crossing;
- 9,000 exact presentations after the 178-field title;
- zero deadline slips and composite health `0x00000000` after 9,177 fields.

These state and sequence assertions are stronger and more reproducible than measurements through an
unavailable external capture clock.

## DMA compiler-upstream decision

The original apparent DMA-address failure was a handwritten assembly ABI violation.
`svx_decode_payload_asm` reused `__rc0`, the llvm-mos software-stack pointer, without preserving it.
The compiler had correctly spilled and reloaded the linked address byte across the call.

The minimized plain-MOS testcase:

- is valid C with an ABI-conforming observable call;
- passes pristine upstream llvm-mos `8be0546128a55e78c63ca571d466aa72a782cd36` with
  `-verify-machineinstrs`;
- emits correct low/high linked-object relocations;
- links an object at `$91A5` to final low `$A5` and high `$91` instruction bytes;
- contains no far pointer, `+mos-a16`, SNES mapping, or fork linker feature.

The separate assembly control explicitly clobbers `__rc0` and therefore demonstrates the invalid
callee, not a compiler defect. The upstream decision gate fails to produce wrong output or a wrong
relocation, so no issue or PR should be prepared.

## Completion criteria

All emulator and compiler-audit criteria above are satisfied. The result is `PASS` for the published
SVX2 artifact under bsnes-jg and “no compiler defect; no upstream submission” for the DMA audit.
