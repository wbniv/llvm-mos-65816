# TODO

llvm-mos-65816 = bringing an optimizing open-source C compiler to the WDC 65816 via
[llvm-mos](https://github.com/llvm-mos/llvm-mos), plus the SNES platform to exercise it.
See [docs/ROADMAP.md](docs/ROADMAP.md) for the M0 → M1 → M2 plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and rationale.

**Status markers:** `[ ]` open · `[wip]` in progress · `[verify]` implemented, verification
not yet run+recorded (run the linked plan's verification steps, paste raw output + PASS/FAIL
back into the plan, then promote to `[x]`) · `[x]` done (moved to DONE, one tight line).
Plan-first: non-trivial work gets a `docs/plans/YYYY-MM-DD-<topic>.md` and a TODO entry.


## M0 — TEST BENCH

- [wip] **Emulator smoke loop (MAME, headless).** Bank-0 C "hello world" boots and runs in
  MAME's `snes` driver headless, with a programmatic assert (`sentinel == 0x42` in WRAM),
  driven by `dev/run.sh smoke` and CI. Closes the run-half of ROADMAP step 1. MAME chosen so
  the CI bench shares drmon's emulation core (green-in-CI == attachable-in-drmon).
  [Plan](docs/plans/2026-06-14-emulator-smoke-loop.md).
- [ ] **Regression corpus (≥5 programs).** Small C programs with known-correct output, green
  in CI from a clean checkout. ROADMAP step 2. Builds on the smoke harness above.


## M1 — FAR POINTERS (first real codegen)

- [ ] **#320 — 24-bit address space / far pointers**, registers stay 8-bit. Five-address-space
  data layout; default 32-bit pointer, 24-bit packed as a size option; near/far calls (JSR/JSL).
  Deliverable: a working multi-bank unoptimized 65816 C compiler. ROADMAP steps 3–4.
- [ ] **Cross-check emulator (bsnes-jg / Mesen2)** added to the bench for fidelity once codegen
  correctness depends on it.


## M2 — OPTIMIZING PAYOFF

- [ ] **#321 stage 1 — 16-bit accumulator + REP/SEP** late-stage insertion; X/Y 16-bit (xy16).
  Then hardware-stack ABI + calling convention. ROADMAP step 5.
- [ ] **DWARF round-trip (drmon tie-in).** `-g` build emits llvm-mos DWARF that drmon's DAP loads
  with correct line/variable mapping. ROADMAP step 6; drdevtools `mame-65816-gdbstub` pre-wires it.


## UPSTREAM / CONTRIBUTION

- [ ] **Surface WDC816CC/ORCA-C ABI prior art in #320/#321** — low-effort, no-code contribution
  documenting the calling-convention prior art (DP frame vs hardware-stack frame).


## DONE

- [x] SNES SDK platform authored (crt0, header, link.ld, snes.h, clang.cfg) — builds a valid
  32 KiB LoROM `.sfc` from C via the existing 6502 backend; structural verification PASS
  2026-06-13 (reset→crt0 byte-exact, `main()` placed, checksum 0xFFFF). ROADMAP step 1, structural half.
