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

## Follow-up: vacuous `-verify-machineinstrs` sweep (2026-08-04)

This demo's gate script comments (the `-fno-lto -c` + `llvm-objdump -h` block added above) named
`dev/_demo5.sh` and the `/snes-demo` skill template as sibling offenders — under the platform
config's default LTO, `mos-clang --config … -c` (or an unqualified `--config … -o rom.sfc`) emits
LLVM IR bitcode / never forwards `-mllvm` to the LTO backend, so `-mllvm -verify-machineinstrs` on
those invocations verifies nothing (a silent, always-PASS gate). TODO item tracked this as a
sweep-and-fix across all `dev/*.sh`.

**Swept 2026-08-04 — 21/23 offenders fixed, 2 escalated.** Every `dev/*.sh` and the
`.claude/skills/snes-demo/SKILL.md` §6 disasm-probe template were audited (grep for
`-verify-machineinstrs` invocations, classify each by whether it shares a compile with `--config`
without `-fno-lto`/`--target=mos`). 23 genuine offenders found (most already had a *separate*
non-LTO `--target=mos -c` disasm-gate compile the flag could ride on; four — `blossom.sh`,
`buddha.sh`, `invaders.sh`, `mandel-oop.sh` — needed a brand-new nmitally-style verify block).
Fix landed and verified clean (host-run `-fno-lto`/`--target=mos` compile + `llvm-objdump -h`
real-object check) for 21 scripts. Red proof: the OLD `--config … -c` pattern (no `-fno-lto`) was
reproduced on `a16absidx.c` — `mos-clang` exits 0 but emits `LLVM IR bitcode` (magic `42 43 c0
de`), and `llvm-objdump -h` correctly **rejects** it (`error: … not recognized as a valid object
file`), proving the check has teeth. Green proof: the fixed `--target=mos -mllvm
-verify-machineinstrs -c` pattern emits a real `elf32-mos` object and `llvm-objdump -h` accepts it.

**ESCALATED — left vacuous:** `dev/blossom.sh` and `dev/mandel-oop.sh`. A real `-fno-lto -c`
verify leg on `examples/snes/blossom.c` and `examples/snes/mandel-oop.c` (both `+mos-a16`, `-Os`)
trips:

```
*** Bad machine code: Using an undefined physical register ***
- function:    main
- instruction: renamable $x = COPY renamable $rc2
fatal error: error in backend: Found 1 machine code errors.
```

This is **not a new defect** — it is another witness of the already-tracked
`a16-rc-undef-ra-pure-virtual` MachineVerifier false-positive (`tools/a16_fuzz.py`
`KNOWN_ISSUES`; prior witnesses on `mandel-double` and `gouraud`, both differential-proven correct
per TODO.md's Done entries; open root-cause plan:
[2026-06-29 rc-undef fix](2026-06-29-a16-rc-undef-ra-machineverifier-fix.md)). The other 4 far-grid/
Mode-7 demos in the same family (`buddha.sh`, `invaders.sh`) verified clean, so this is
codegen-shape-specific, not universal to the family. Landing a real verify leg on these two
scripts without XFAIL-awareness would turn an always-green (vacuous) gate into an always-crashing
one on a pre-existing, accepted issue — worse than leaving it vacuous. Wiring the demo-level gate
scripts into the `tools/a16_fuzz.py` `KNOWN_ISSUES` / `dev/known-issues.sh` XFAIL mechanism (today
that registry only covers corpus-slice fuzzing, not whole-ROM demo gates) is a design decision
outside a bounded per-script edit — **ESCALATE to T3/T4**.
