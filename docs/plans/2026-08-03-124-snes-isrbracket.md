# #124 — Mid-Bracket NMI Tunnel (`isrbracket`)

**Status:** DONE + PUBLISHED 2026-08-03 — clean positive after the #123 interrupt-envelope fix. Round 7 compiler-probe ROM.

## Question and shape

Does an NMI that lands inside a long native-width mainline region return with the interrupted M/X
state intact? The main loop repeatedly calls a dense 48-stage 16-bit arithmetic tunnel twice from
the same volatile seed. NMI may cut through either call; the two results must still agree. A
1,024-interrupt handshake makes the final tally and interrupt-side mix deterministic, while a
mismatch counter detects corrupted continuation without making the oracle depend on exact landing
times.

The visual is a scrolling native-width tunnel. Alternating blue and magenta operation blocks and
paired alignment rails derive from the live tunnel result; a bright vertical NMI needle cuts across
them at changing phases.

## Startup-progress visual options (2026-08-04)

The 1,024-NMI gate intentionally takes about 17 seconds on a 60 Hz machine. A static tunnel during
that interval looked stalled, so these ten test-derived progress treatments were considered:

1. Tunnel progress rail filling left-to-right, marked at 256/512/768/1024.
2. Four-stage circuit breaker, one block per 256 NMIs.
3. Hex odometer counting `0000` through `0400`.
4. Decimal `NMI #### / 1024` counter with percentage.
5. Circular 64-segment interrupt scope, one segment per 16 NMIs.
6. Packet journey through 16 tunnel chambers, one chamber per 64 NMIs.
7. Four-floor stack-depth elevator with fine progress within each floor.
8. Scrolling oscilloscope history accumulating one column per 64 NMIs.
9. Dual integrity meters: successful NMI progress and a continuously visible mismatch count.
10. A 32×32 mosaic filling one cell per NMI.

**Selected:** option 9 combined with option 1. During the gate the HUD reads
`NMI ####/1024 ERR ####`; a 16-segment tunnel rail fills every 64 NMIs, while the error rail stays
green at zero and becomes conspicuous if paired native-width computations ever disagree. The
display refresh happens only at those 64-frame milestones, leaving the intervening NMIs free to
land asynchronously inside the arithmetic tunnel.

## Gates and published result

- Host oracle: `0x1014`.
- Disassembly confirms a native-width bracket in `tunnel`.
- The ISR contains the 65816 outer `rep/sep` envelope plus A/X/Y saves and restores, ending in `rti`.
- Host == default == a16 == xy16 == `0x1014` on MAME after 1,400 ticks.
- Every target mode passes three repeated 1,400-frame bsnes-jg runs.

Run with `dev/run.sh isrbracket`.

## Publication

- [biohack.net demo](https://biohack.net/snes/isrbracket/) — counter release `v1.0.378`, commit `a4f3f11`
- [indri.studio demo](https://indri.studio/apps/llvm-mos-65816/snes/isrbracket/) — counter release `v0.1.147`, commit `a5a4abd`
- Published ROM: `build/isrbracket-a16.sfc`
- SHA-256: `71da6a04eee451edf8582f67a55e8bf5d55255acbb61675843e25797b9a7d062`

Both live pages and downloads pass paired verification, and `isrbracket` is the first card in both
newest-first catalogs.
