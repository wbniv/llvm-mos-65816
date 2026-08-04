# #123 — VBlank Interrupt Tally (`nmitally`)

**Status:** implemented; a16 interrupt-entry gap surfaced and closed 2026-08-03 · **Round:** 7, Cluster B

The first C interrupt handler in the demo battery increments volatile 16- and 32-bit state from
VBlank NMI while `main` continuously executes native-width arithmetic. An armed/done publication
handshake stops mutation at exactly 120 interrupts, making the final folded snapshot identical to
the host model without depending on instruction-level ISR/main interleaving.

The visual is an oscilloscope-like interrupt trace: periodic raised pulses represent entry into the
C NMI handler, and a bright scan column continues moving after the frozen `N=078` / CRC result is
published.

Verification: host == default == `+mos-a16` == `+mos-xy16` in bsnes-jg, three repeated a16 runs,
`-verify-machineinstrs` clean, and a disassembly audit requiring `cld`, `rti`, `rep`/`sep`, plus
balanced saves/restores in `nmi`. MAME is an additional leg when the SPC700 IPL is installed.

## Finding

The default build passes (`0xDA3B`). The a16 build returned `0xF4F4` once and `0x0000` on two
repeats; xy16 returned `0x0000`. This is genuine landing-time nondeterminism, not a bad golden.
The generated ISR begins `cld; pha` and performs several more pushes/loads before its first
`rep`/`sep`. An NMI inherits the interrupted M/X flags, so `pha` itself pushes one or two bytes and
the following immediate/load instructions are decoded/executed at the inherited width. The
epilogue consequently cannot balance the stack or restore imaginary registers reliably when the
interrupt lands inside a native-width bracket. `-verify-machineinstrs` remains clean because the
machine IR has no model of asynchronous entry mode.

Classification: this is a **missing piece of the a16 port, not a latent llvm-mos bug**. The stock
prologue is correct for every pre-a16 configuration — without `+mos-a16`/`+mos-xy16` generated
code never leaves M8/X8, so an interrupt always lands at the assumed widths. The hazard exists
only once the opt-in native-width feature opens `rep`/`sep` regions, and this demo compiled the
first interrupt handler ever built under it: a previously-undefined corner of the feature's ABI.
It still carries defect severity — a well-formed program was silently miscompiled with no
diagnostic — but the fix below is new ABI design (defining interrupt-entry semantics for native
mode), not a repair of broken existing logic.

Fixed holistically in `MOSFrameLowering`: a 65816-only outer envelope now executes
`rep #$30; pha; phx; phy; sep #$30` before the ordinary M8/X8 C body and
`rep #$30; ply; plx; pla; rti` on exit. The hardware-stacked P remains authoritative for restoring
the interrupted M/X flags. After rebuilding, default/a16/xy16 all return `0xDA3B`; a16 is 3×
deterministic. Full analysis: [interrupt width report](../investigations/2026-08-03-65816-interrupt-width-prologue.md).

Published, build-verified demo pages:

- [https://biohack.net/snes/nmitally/](https://biohack.net/snes/nmitally/)
- [https://indri.studio/apps/llvm-mos-65816/snes/nmitally/](https://indri.studio/apps/llvm-mos-65816/snes/nmitally/)

Both sites serve visual republish ROM SHA-256
`a2e40ea72618641eed1804846f5cd6f0032a33a6dbcf655f737b176cead21283`.
Visual republish commits/releases: biohack.net `6f05515` / `v1.0.368`, indri.studio `061b749` /
`v0.1.138`.
