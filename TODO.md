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

- [ ] **#320 full model + upstream.** Five-address-space layout (asiekierka's 32-bit-default, packed
  24-bit, zero-bank, abs-16) after maintainer ABI blessing; open the PR. Upstream-gated — coordinate
  on the llvm-mos Discord (@asiekierka/@mysterymath) with the running slice in hand. **Design note
  drafted + ready to post** ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md));
  posting to #320/Discord is the next (user-triggered) step.

### M2 — Optimizing Payoff

- [ ] **#321 Increment 1b — dual-width accumulator register** (after 1a, done): model `A` as the low
  half of a 16-bit `C` that aliases the same physical bits (8- or 16-bit by the runtime M flag) + a
  register bank, so 16-bit `lda`/`sta` flow a real 16-bit value (not just the register-free STZ of 1a).
  The genuine hard core of #321. Reuses the 1a `MOSInsertREPSEP` pass + `+mos-a16` feature.
  [plan](docs/plans/2026-06-14-321-increment-1-16bit-accumulator.md).
- [ ] **#321 — proper native-mode crt0** (XCE + native vectors, M/X default 8-bit) so *all* SNES
  programs run in native mode (the eventual M2 platform mode) — replaces the 1a test-local `clc; xce`.
  Corpus + far must stay green in native 8-bit. Enables the emulator run for all 16-bit codegen.
- [ ] **#321 stage 1 — full xy16 mode + ABI** (after Increment 1): X/Y permanently 16-bit; REP/SEP
  mode-tracking across control flow + churn minimization; 16-bit arithmetic; **native-mode crt0** (XCE
  + native vectors + DBR — the prerequisite for 16-bit registers, moved here from #320 Increment 2);
  then hardware-stack ABI + calling convention. ROADMAP step 5.
- [ ] **DWARF round-trip (drmon tie-in).** `-g` build emits llvm-mos DWARF that drmon's DAP loads
  with correct line/variable mapping. ROADMAP step 6; drdevtools `mame-65816-gdbstub` pre-wires it.

### Upstream / Contribution

- [ ] **Surface WDC816CC/ORCA-C ABI prior art in #320/#321** — low-effort, no-code contribution
  documenting the calling-convention prior art (DP frame vs hardware-stack frame). Summarized in the
  [#320 design note](docs/320-upstream-far-pointer-note.md) (open ABI decisions §3) with an offer to
  expand into a standalone prior-art writeup if the maintainers want it; promote when that's done.


## Watch

_Nothing being watched yet — items move here when they need periodic checking (e.g. an upstream
llvm-mos change to track) rather than active work._


## Parked

_Nothing parked yet — items move here when intentionally shelved (feasibility done but not
starting, or blocked on an external factor)._


## Done

- 2026-06-14 — [321-increment-1a-16bit-accumulator] **first real 16-bit-accumulator codegen** — a
  16-bit store-of-zero fuses (under opt-in `+mos-a16`) to `rep #$20; stz; sep #$20` via the new
  `MOSInsertREPSEP` pass (reuses the MC `MLow/MHigh` width TSFlags), and — run in 65816 native mode —
  fully zeroes the 16-bit value: `corpus_result == 0x0042` on **both** MAME and bsnes-jg. Non-breaking
  (corpus 7/7, far/xcheck unaffected; feature not implied by W65816). Tracked patch
  `0002-321-accum16.patch`; `dev/run.sh a16`. Finding: 16-bit registers need native mode (XCE) — the
  deferred prerequisite. ROADMAP step 5 (first slice). [plan](docs/plans/2026-06-14-321-increment-1-16bit-accumulator.md).
- 2026-06-14 — [second-emulator-xcheck] **second-emulator fidelity cross-check** — `dev/run.sh xcheck`
  boots the far ROMs in **bsnes-jg** (cycle-accurate, independent of MAME) headless and reads WRAM via
  `Bsnes::getMemoryRaw(MainRAM)` (a small `dev/jgxcheck.cpp` harness, no SDL/X/save-state): far-run
  (bank $00) + far-bank1 (bank $01) both `got=0xF3`, agreeing with MAME — the bank-$01 far read isn't a
  MAME quirk. Mesen2 abandoned (prebuilt crashes on 26.04 glibc-2.43; headless `--testrunner` won't run
  Lua). Completes ROADMAP step 3's "both emulators".
  [plan](docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).
- 2026-06-14 — [320-upstream-design-note] drafted the upstream #320 design note
  ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md)): leads with the
  verified running slice (Inc 1/2/2b, by commit), the addrspace-numbering divergence (slice `2`=far
  additive vs proposal `0`=far-default) + a reconciliation path, the open ABI decisions, and the
  WDC816CC/ORCA-C calling-convention prior art. Code-first artifact to anchor the #320 discussion;
  posting upstream is user-triggered. [plan](docs/plans/2026-06-14-320-upstream-design-note.md).
- 2026-06-14 — [320-increment-2b-multi-bank-far-read] far read now **crosses a real ROM bank
  boundary**: a 64 KiB LoROM (`snes-far` child platform, banks $00+$01) places a far global in bank
  $01 ($018000), far-read via `lda $018000` (`af 00 80 01`); the cross-bank result round-trips in MAME
  (`SMOKE: PASS got=0xF3`). No codegen/native-mode change (section attr + linker rule; `snes-checksum.py`
  now owns the ROM-size byte). New `dev/run.sh far-bank1` + `examples/65816/far-bank1.c`; 5/5 PASS,
  default snes platform untouched (corpus 7/7, far-run PASS). Completes ROADMAP step 3.
  [plan](docs/plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md).
- 2026-06-14 — [320-increment-2-far-emulator-run] far-pointer codegen now **executes in MAME**: a
  `-mcpu=mosw65816` program far-LOADs a ROM constant and far-STOREs the result to WRAM; the byte
  reads back `0xF3` (`SMOKE: PASS`) on the existing single-bank emulation-mode crt0. Finding:
  absolute-long ignores the DBR → no native mode needed (XCE/DBR/16-bit regs re-scoped to M2/#321);
  multi-bank far-read split to Increment 2b. New `dev/run.sh far-run` + `examples/65816/far-run.c`;
  5/5 verification steps PASS, corpus still 7/7. ROADMAP step 3 (execution half).
  [plan](docs/plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md).
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
