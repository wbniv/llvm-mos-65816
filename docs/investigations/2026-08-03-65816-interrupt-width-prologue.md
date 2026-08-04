# 65816 interrupt handlers inherited an unknown M/X width

**Date:** 2026-08-03 · **Found by:** Round 7 #123 `nmitally` · **Status:** fixed and runtime-verified

**Play the reproducer:** [https://biohack.net/snes/nmitally/](https://biohack.net/snes/nmitally/) — the page includes the ROM, live
WRAM fidelity check, and a red-before/green-after explanation of the compiler failure.

## Summary

MOS C interrupt handlers were correct on 6502-family targets and on 65816 code that never entered
native-width regions, but unsafe when an interrupt could arrive while M=0 or X=0. The backend
treated an interrupt entry like an ordinary C call and assumed M8/X8. Real 65816 interrupt entry
preserves the interrupted M/X bits in the live processor status until software changes them.

The first generated instructions were `cld; pha`. If NMI arrived with M=0, that `pha` pushed two
bytes instead of the one byte assumed by the rest of the prologue. X had the analogous problem for
`phx`/`phy`. The resulting stack imbalance and incorrectly decoded width-sensitive instructions
made the failure depend on the exact interrupted instruction.

## Reproducer and evidence

`examples/snes/nmitally.c` arms an ISR for exactly 120 VBlanks. The ISR updates volatile 16- and
32-bit tallies; main continuously executes native arithmetic. A publication handshake stops ISR
mutation exactly at frame 120, so the host oracle is deterministic (`0xDA3B`) and independent of
instruction-level interleaving.

Before the fix:

- default M8/X8: `0xDA3B` (pass);
- a16: `0xF4F4` on one run and `0x0000` on two repeats;
- xy16: `0x0000`;
- `-verify-machineinstrs`: clean, because MIR does not model asynchronous entry mode.

The changing a16 result was useful evidence: a bad oracle would fail consistently, whereas this
varied with the width state at the NMI landing point.

## Root cause

`MOSInsertREPSEP::runOnMachineFunction` seeds the entry block with M8/X8, which is correct for the
normal C ABI. `MOSFrameLowering` and the callee-save machinery then emit ordinary `PH`/`PL` pseudos.
For an ISR, however, no ABI caller establishes those widths. The CPU enters with the interrupted
M/X state and merely stacks P for the eventual `RTI`.

Normalizing to 8-bit before saving registers is insufficient: it would preserve only A's low byte,
and an a16 handler may modify B. Saving before normalization is also insufficient unless the save
width is first made deterministic.

## Fix

For interrupt functions compiled with native-width codegen, `MOSFrameLowering` adds a fixed outer
envelope around the ordinary prologue/epilogue:

```asm
rep #$30
pha
phx
phy
sep #$30
; existing generated ISR, now under the normal M8/X8 ABI contract
...
rep #$30
ply
plx
pla
rti
```

Forcing M16/X16 before the pushes makes every outer save exactly two bytes and preserves full
A/B, X, and Y. The inner generated prologue may still save registers conservatively; that is
redundant but correct. Before return, the outer values are restored at the same fixed widths.
`RTI` then restores the hardware-stacked P, including the interrupted M/X state. The `no-isr`
attribute remains an explicit opt-out.

The envelope lives in `MOSFrameLowering`, not the SNES ROM or SDK. Frame lowering already owns ISR
save/restore construction; placing it there also makes the contract explicit before the fork's
mode-placement pass and keeps the fix part of the holistic #321 native-width patch. An assembly
wrapper in the ROM would have hidden the compiler defect and left every other 65816 C ISR exposed.

## Verification

- Focused LLVM codegen check asserts the exact entry/exit envelope.
- Toolchain rebuilt successfully with the change.
- `dev/run.sh nmitally`: host == default == a16 == xy16 == `0xDA3B`.
- Three independent a16 emulator runs returned `0xDA3B` with byte-identical screenshots.
- `-verify-machineinstrs` is clean for all three builds.
- A wider corpus spot-check completed 12 consecutive slices (`arith` through `ca1d_sim`) with no
  regression before the long full sweep was stopped; non-ISR functions are byte-unaffected because
  the new envelope is attribute-gated.
