# TODO

llvm-mos-65816 = bringing an optimizing open-source C compiler to the WDC 65816 via
[llvm-mos](https://github.com/llvm-mos/llvm-mos), plus the SNES platform to exercise it.
See [docs/ROADMAP.md](docs/ROADMAP.md) for the M0 → M1 → M2 plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and rationale.

**Status markers:** `[ ]` open · `[wip]` in progress · `[verify]` implemented, verification
not yet run+recorded (run the linked plan's verification steps, paste raw output + PASS/FAIL
back into the plan, then promote to `[x]`) · `[x]` done (moved to Done, one tight line).
Plan-first: non-trivial work gets a `docs/plans/YYYY-MM-DD-<topic>.md` and a TODO entry.


## Open

### M0 — Test Bench

_M0 complete — test bench stands (ROADMAP steps 1–2 PASS). See Done._

### M1 — Far Pointers (first real codegen)

- [ ] **#320 Increment 2 — emulator end-to-end far pointers.** 65816 native-mode crt0 (XCE/DBR/reg
  widths) + multi-bank ROM; a far-pointer corpus program boots and runs correctly in MAME. ROADMAP step 3.
- [ ] **#320 full model + upstream.** Five-address-space layout (asiekierka's 32-bit-default, packed
  24-bit, zero-bank, abs-16) after maintainer ABI blessing; open the PR. Upstream-gated — coordinate
  on the llvm-mos Discord (@asiekierka/@mysterymath) with the running slice in hand.
- [ ] **Cross-check emulator (bsnes-jg / Mesen2)** added to the bench for fidelity once codegen
  correctness depends on it.

### M2 — Optimizing Payoff

- [ ] **#321 stage 1 — 16-bit accumulator + REP/SEP** late-stage insertion; X/Y 16-bit (xy16).
  Then hardware-stack ABI + calling convention. ROADMAP step 5.
- [ ] **DWARF round-trip (drmon tie-in).** `-g` build emits llvm-mos DWARF that drmon's DAP loads
  with correct line/variable mapping. ROADMAP step 6; drdevtools `mame-65816-gdbstub` pre-wires it.

### Upstream / Contribution

- [ ] **Surface WDC816CC/ORCA-C ABI prior art in #320/#321** — low-effort, no-code contribution
  documenting the calling-convention prior art (DP frame vs hardware-stack frame).


## Watch

_Nothing being watched yet — items move here when they need periodic checking (e.g. an upstream
llvm-mos change to track) rather than active work._


## Parked

_Nothing parked yet — items move here when intentionally shelved (feasibility done but not
starting, or blocked on an external factor)._


## Done

- 2026-06-14 — [320-increment-1-far-codegen] far (addrspace 2) load/store now lowers to 65816
  absolute-long (`LDA/STA $xxxxxx`, AF/8F, 4-byte incl. bank), gated on `W65816`; near stays 16-bit,
  far global → `R_MOS_ADDR24`. GISel `G_LOAD/STORE_FAR_ABS` → `LDAbsLong/STAbsLong` MC wrappers.
  `dev/run.sh far` 5/5 PASS + corpus 7/7 on the patched from-source toolchain. ROADMAP step 4.
  Tracked patch `0001-320-far-addrspace.patch`. [plan](docs/plans/2026-06-14-320-far-pointer-codegen.md).
- 2026-06-14 — [m1-phase0-toolchain] llvm-mos built FROM SOURCE in the dev container
  (`dev/run.sh toolchain`), lean (clang+lld, dropped clang-tools-extra → 39.2→26.1 min cold). Bench
  toolchain selectable via `MOS_TOOLCHAIN`; `build.sh` wipes the SDK tree on toolchain change. Corpus
  7/7 on the self-built compiler (byte-equiv to prebuilt). M1 codegen prerequisite.
  [plan](docs/plans/2026-06-14-m1-from-source-toolchain.md).
- 2026-06-14 — [regression-corpus] 6 self-contained C programs (`examples/snes/corpus/`) exercising
  ALU / control flow / arrays+.rodata / structs+pointers / calls+recursion / crt0 init; host-checked
  vs `expected.tsv`. `dev/run.sh corpus` 7/7 PASS, negative control + clean-room `repro` green.
  ROADMAP step 2. [plan](docs/plans/2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).
- 2026-06-14 — [emulator-smoke-loop] `dev/run.sh smoke` boots hello.sfc headless in MAME's `snes`
  driver, asserts `sentinel==0x42` in WRAM. Negative control + clean-room `dev/run.sh repro` +
  manual GitHub CI (run 27475012894) all green. Closes ROADMAP step 1 (run-half).
  [plan](docs/plans/2026-06-14-emulator-smoke-loop.md).
- 2026-06-13 — [snes-sdk-platform] SNES SDK platform (crt0, header, link.ld, snes.h, clang.cfg)
  builds a valid 32 KiB LoROM `.sfc` from C via the 6502 backend; structural verification PASS
  (reset→crt0 byte-exact, `main()` placed, checksum 0xFFFF). ROADMAP step 1, structural half.
