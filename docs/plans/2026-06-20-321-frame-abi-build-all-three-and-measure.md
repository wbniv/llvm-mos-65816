# #321 — 65816 stack-frame ABI: build all three frames and measure head-to-head

**Date:** 2026-06-20 · **Status:** PLAN · **Scope:** `vendor/llvm-mos/` codegen + a new cycle-measurement
harness. Large, multi-phase, **gated**. Runs on a **feature worktree**, not `main`.
**ROADMAP:** step 5 (M2), the xy16 hardware-stack-ABI frontier · **TODO:** M2 "#321 stage 1 — full xy16 mode
+ ABI" / "#321 calling-convention".

## Context — why

The last open M2 frontier is the **xy16 hardware-stack ABI / 16-bit calling convention**. Its blocking
decision — *how to store locals/frames* — was resolved **on paper**: the CC frame-decision record
([2026-06-18-321-cc-frame-phased-decision.md](2026-06-18-321-cc-frame-phased-decision.md)) chose **(c) the
soft static stack** for the first pass, **deferred (a) the TCD direct-page window** behind a ZP-pressure
measurement, and **ruled out (b) pure stack-relative** as "dominated by (a)." But the ZP measurement was an
**indirect proxy** (it showed real code uses only ~5 of 14 ZP pairs, so "(a) relieves pressure that isn't
there") — it never measured (a)'s *direct* thesis: that DP 8-bit addressing is **smaller/faster** than
soft-stack access. And (b) was never measured at all. Governing **lesson #1 (measure, don't assume)** says a
paper "dominated" ruling is exactly the kind of unmeasured claim to retire.

**The decision (user, 2026-06-20):** build **all three** frame strategies to production quality and run a
rigorous **three-way head-to-head** (code size + real cycles + correctness) on the corpus + kernels, in
realistic 16-bit-ambient context. The measured numbers then back the **user-triggered upstream #321 CC
posting** — turning a paper proposal into an evidence-backed one.

**The central insight that shapes everything (the DP-collision).** llvm-mos's competitive advantage is a
global zero-page imaginary-register file `__rc*`, **hard-fixed by the SNES linker at ZP `$0000–$001F`**
(`vendor/llvm-mos-sdk/mos-platform/snes/link.ld:13-21`, `ASSERT(__rc31 == 0x1f)`). On the 65816, zero-page
addressing **is** direct-page-relative — operand `N` decodes as `D+N`. So the instant a DP-window prologue
sets `D ≠ 0`, **every `lda __rcN` silently retargets** from the imaginary register at `$00+N` to a frame byte
at `D+N`. The 1990s commercial ABIs (WDC816CC/ORCA, [prior-art note](../320-321-65816-c-abi-prior-art.md))
don't hit this because they have *no* global ZP register file — their world *is* the DP frame. This asymmetry
is the dominant correctness trap, the main cost driver for (a), and a first-class finding for upstream.

**Expected outcome — and why a NULL result is a first-class deliverable.** After the ZP-slack finding removed
(a)'s structural justification, its only remaining rationale is raw access speed; the DP-collision tax (every
`__rc*` access in a DP-window function must become a 3-byte DBR-relative `abs` to bypass `D`) plus per-call
`tsc;phd;tcd … pld` setup plausibly erase the per-local DP win for the **non-recursive** code llvm-mos
targets (whose locals are *already* ZP-resident). The most likely measured result: **(c) soft static stack
ties or beats (a); (b) is dominated as predicted.** That is a rigorous, upstream-worthy *confirmation* of the
existing shelving — strictly stronger than the indirect proxy. The plan is built so that null is a publishable
conclusion, not a failure.

## Where it runs — feature worktree, gated landing

Per project convention (CLAUDE.md "Worktree-based feature workflow" + "Investigations go on throwaway
worktrees") and mirroring the existing `wt/321-xy16`, do this on a dedicated worktree **`wt/321-frame-abi`**
off `main` HEAD ([howto-feature-worktree.md](../howto-feature-worktree.md)). It changes the compiler, so the
worktree needs its own toolchain build (this is a *feature* worktree, not a host-only investigation).
**Durable artifacts merge back regardless of outcome** — the cycle-measurement harness, the
`measure-frame-abi.sh` driver, and the decision-record update. **The (a)/(b) compiler code lands in `0002`
only if it clears the pre-registered go/no-go bar** (below); otherwise it stays a measured spike and the
worktree's compiler diff is discarded.

## Step 0 — set up the feature worktree (do this first)

This is a **compiler-changing** feature, so unlike a host-only spike the worktree needs its **own editable
`vendor/llvm-mos`** and a **freshly built toolchain** — the `cp -al` hardlink trick in
[howto-feature-worktree.md](../howto-feature-worktree.md) exists to run `dev/run.sh` *without* rebuilding;
here we rebuild because we edit the backend. Hardlink only the read-only bits we don't change (SDK,
`jgxcheck`, bsnes-jg, BIOS — the SDK is default-built and our features are off-by-default, so it's unaffected,
which P0 proves).

```bash
SLUG=frame-abi
MAIN=/home/will/SRC/llvm-mos-65816
WT="$MAIN-$SLUG"                                   # /home/will/SRC/llvm-mos-65816-frame-abi

# 1. Worktree off the LIVE main tip -> branch wt/321-frame-abi (hot tree: never a pinned older commit).
git -C "$MAIN" worktree add -b "wt/321-$SLUG" "$WT" main

# 2. Its OWN editable backend source — a REAL copy (not hardlinked), so edits/rebuilds stay isolated from
#    main. vendor/ is gitignored, so the worktree starts without it.
mkdir -p "$WT/vendor" "$WT/build"
cp -a  "$MAIN/vendor/llvm-mos"  "$WT/vendor/"      # the LLVM/clang tree we edit + rebuild

# 3. Hardlink the read-only, unchanged bits (near-instant, shares inodes — never edit in place):
cp -al "$MAIN/build/install"    "$WT/build/"       # SDK: mos-snes.cfg + platform libs
cp -al "$MAIN/build/jgxcheck"   "$WT/build/"       # bsnes-jg readback harness
cp -al "$MAIN/vendor/bsnes-jg"  "$WT/vendor/"      # bsnes-jg core + Database
cp -al "$MAIN/dev/roms"         "$WT/dev/"         # SPC700 IPL (gitignored BIOS)

# 4. Build the toolchain FRESH from the worktree's own source (30-90 min — unavoidable for a backend
#    change; writes build/llvm-mos-install independently of main).
cd "$WT" && dev/run.sh toolchain

# 5. Sanity: the worktree compiles + runs the differential end-to-end before any edits.
dev/run.sh corpus                                  # expect 7/7
```

Register `wt/321-frame-abi` in the **Active worktrees** table at the top of `docs/agent-handoff.md` while it
is live. After each `vendor/` edit, rebuild with `dev/run.sh toolchain` and **confirm the rebuild actually
took** (the stale-`clang-23` gotcha — check the binary's mtime). **Disposition** (howto §Disposition):
durable artifacts (`dev/measure-frame-abi.sh`, `dev/probe-cycles.lua`, the decision-record update + new test
gates) merge back to `main` regardless; the (a)/(b) **compiler diff lands in `0002` only if it clears the
go/no-go bar** — otherwise `git worktree remove "$WT"` + `git branch -D "wt/321-$SLUG"`, keeping only the
recorded verdict.

## Selection mechanism (keeps the default byte-identical)

Add two subtarget features mirroring `FeatureAccum16`/`FeatureIndex16` (`MOSFeatures.td:26-37`), **not**
attached to any `Family` in `MOSDevices.td` (so default codegen is provably untouched):
`FeatureDPFrame` (`+mos-dp-frame`) and `FeatureSRFrame` (`+mos-sr-frame`). Add `MOSSubtarget` getters and a
tri-state query:

```cpp
enum class FrameStrategy { SoftStatic, DPWindow, StackRelative };
FrameStrategy frameStrategy() const {
  if (HasDPFrame) return FrameStrategy::DPWindow;
  if (HasSRFrame) return FrameStrategy::StackRelative;
  return FrameStrategy::SoftStatic;            // default — existing path, unchanged
}
```

**Branch discipline:** at each strategy branch point — `emitPrologue` (`MOSFrameLowering.cpp:282`),
`emitEpilogue` (321), `processFunctionBeforeFrameFinalized` (243), `eliminateFrameIndex`
(`MOSRegisterInfo.cpp:256`) — add the non-default strategies as **new early-return branches placed *before*
the existing logic**; the `SoftStatic` case is `break` and falls into the existing soft-stack body
**verbatim**. With both features off, `frameStrategy()==SoftStatic` ⇒ zero instructions execute differently.
The build/A-B harness selects strategies via the existing `-Xclang -target-feature -Xclang +mos-XXX` path
(`tools/a16_fuzz.py:705-709`, `dev/measure-a16-threading.sh:13`).

## Phased, gated sequence

| Phase | Deliverable | Gate to proceed |
|---|---|---|
| **P0** | Features + `frameStrategy()` tri-state + **inert** branch scaffolding | **Byte-identical default**: corpus+kernels `llvm-objdump -d` unchanged vs pre-change (the key guardrail) |
| **P1** | Cycle infra: `dev/probe-cycles.lua` reachability probe + sentinel protocol + `dev/measure-frame-abi.sh` (size, 4-way) | MAME `total_cycles()` reachable (else adopt frame-count proxy fallback) |
| **A0** | **DP-collision resolution** + hand-written `.s` proof ROM + a `canUseDPWindow` eligibility rule | Collision provably avoided at runtime on MAME+bsnes with a *clean* eligibility rule — **else STOP and report "(a) can't safely layer on the fixed-ZP model" as the finding** |
| **A1–A2** | `D` register modeled (**reserved**, not allocatable) + `tsc;[sec;sbc #sz;tcs;]phd;tcd` prologue / `pld` epilogue (FrameSetup/Destroy flags) | `dev/run.sh crt0native` still PASS with a DP-window fn in the call chain |
| **A3–A4** | New `MosDPFrame` `TargetStackID` + DP-offset `eliminateFrameIndex` + fallbacks (recursion / >256 B / ISR / FP → soft stack) | `a16_fuzz.evaluate` differential PASS on corpus+kernels under `+mos-dp-frame` (host==default==a16, both emus) |
| **B** | **FULL (b)**: 65816 `op dp,s` + `(dp,s),y` instruction defs (`HasW65816`), ISel/expansion, **`SPAdj` frame-offset tracking** (lift the `MOSRegisterInfo.cpp:263` `SPAdj==0` assert), new `MosSRFrame` stack ID + `,S` `eliminateFrameIndex`, soft-stack fallback | Differential PASS under `+mos-sr-frame` |
| **M** | Full `measure-frame-abi.sh` run: 4-way **size + cycles**, multi-shape, 16-bit-ambient; inner-loop *and* whole-call cycle brackets | **Every cell differentially verified before any number is reported** (a smaller-but-wrong build is not a data point) |
| **D** | Decision-record update + #321 evidence paragraph; apply go/no-go | — |

### Key implementation notes

- **A0 (make-or-break).** The only *correct* DP-window that preserves llvm-mos semantics restricts (a) to a
  **narrow eligibility class**: non-reentrant functions whose `__rc*` footprint is empty/tiny, with the few
  imaginary-register touches re-emitted as `D`-independent 16-bit `abs` (DBR=0, already established by crt0).
  `canUseDPWindow(MF)` enforces it; everything else falls through to the unchanged soft stack. If A0 yields no
  clean, reasonably-broad rule, that *is* the result — stop before A1.
- **D register (A1).** Add `def D` in `MOSRegisterInfo.td` with a fresh HWEncoding outside the imaginary
  ranges (mirror the `XH/YH/X16/Y16` placement, `:114-123`); mark **reserved** in the `MOSRegisterInfo` ctor
  alongside `RS0`/`RS8` (`:69-73`). It's a frame invariant, never allocated. Frame-index elimination encodes
  the slot offset as an **8-bit DP immediate** directly in the access instruction (no base-reg arithmetic —
  that *is* (a)'s speed thesis). `PHD/PLD/TCD/TCS/TSC` already exist (`MOSInstrInfo.td:751-814`).
- **FULL (b) is the heaviest single piece.** The `,S` offset is measured from a stack pointer that *moves*
  with every push/pull, so `eliminateFrameIndex` must thread `SPAdj` through the call-frame pseudos (today
  asserted zero at `MOSRegisterInfo.cpp:263`). The `StackRelative`/`IndirectStackRelativeY` addressing-mode
  defs exist (`MOSInstrFormats.td:441-459`) but are wired only for 65CE02 — add the 65816 opcodes under
  `Predicates=[HasW65816]`.
- **Cycle instrumentation (P1).** First probe reachability: `dev/probe-cycles.lua` prints
  `manager.machine.devices[":maincpu"].execute.totalcycles` via the existing MAME invocation
  (`a16_fuzz.run_mame`). If reachable → **sentinel protocol**: the benchmark wrapper writes a magic byte to
  `$7E00F0` before the measured region and `$7E00F2` after; the Lua taps both (like `smoke.lua`'s periodic
  read, `:32-62`), latches `start`/`end` cycles, prints a greppable `CYCLES: <delta>` line parsed exactly as
  `SMOKE:` is. Run **two brackets** per kernel — *whole-call* (charges `tsc;phd;tcd…pld` setup) and
  *inner-loop* (isolates DP-access speed) — so the study shows where (a) wins vs where setup eats the win. If
  `total_cycles()` is unreachable, fall back to the **frame-count proxy** (iterations completed in N fixed
  frames; deterministic on both emulators).

## Pre-registered go/no-go (decide the bar *before* measuring)

- **(a) DP-window is WORTH landing** iff, on realistic corpus+kernels at `+mos-a16 -Os`, it wins **cycles by
  ≥ ~10%** on the inner-loop bracket on **multiple** programs **AND** regresses code size by **≤ ~2%** on every
  program **AND** the A0 eligibility rule is clean and reasonably broad. The bar is high on purpose: (a) adds a
  256-B cap, a recursion fallback, a reserved register, a stack ID, and the collision guard — real complexity
  that must be *paid back* by a repeated, real win, not a wash.
- **(a) is CONFIRMED-shelved** if it ties/loses on cycles, wins only marginally while costing size, or A0's
  rule is too narrow to matter.
- **(b) stack-relative**: measured as the validating control; landed only under the same bar (expected:
  dominated → not landed, paper ruling now evidence-backed).
- **NULL result** ("soft static stack is already at/near optimal for non-recursive code; the fancier frames
  aren't worth their complexity") is the expected, publishable conclusion that *strengthens* the upstream CC
  argument.

## Reuse (don't rebuild)

- **Size:** `text_bytes()` (`dev/measure-a16-threading.sh:33-36`, `llvm-objdump --section-headers` summing
  `.text*`). New `dev/measure-frame-abi.sh` models on `dev/corpus-a16.sh` (differential driver) +
  `dev/measure-zp-pressure.sh` (per-program iteration + summary table).
- **Correctness:** `tools/a16_fuzz.py evaluate()` (`:889-981`) — three-way compile + MAME + bsnes-jg +
  `corpus_result` readback + KNOWN_ISSUES XFAIL. Extend with the new feature flags.
- **Readback bridge:** `dev/_emu.sh run_assert` + `dev/smoke.lua` (`SMOKE:`/sentinel pattern) → extend for
  `CYCLES:`.
- **Workload:** corpus `examples/snes/corpus/*.c` (+ `expected.tsv`), kernels `examples/65816/k_*.c`, a16
  micro-suite as a leaf-floor reference (with the handoff caveat that leaves mis-weight rep/sep).

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSFrameLowering.cpp` — strategy branch points (46-50, 243-261,
  282-349); DP prologue/epilogue.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` — `eliminateFrameIndex` (256-351), reserved-reg
  ctor (47-74); DP-offset and `,S` lowering, `SPAdj` tracking.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.td` — model `D`; the `__rc*` defs are the collision's
  other half.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSFeatures.td` + `MOSSubtarget.h` — the two features + `frameStrategy()`.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrInfo.td` / `MOSInstrFormats.td` — 65816 `,S` instruction defs.
- `tools/a16_fuzz.py` (`evaluate`), `dev/smoke.lua` (sentinel→cycles), new `dev/measure-frame-abi.sh`,
  `dev/probe-cycles.lua`.
- Read-only context: `vendor/llvm-mos-sdk/mos-platform/snes/link.ld` (the fixed `__rc` ZP map = the
  collision) and the CC frame-decision record (this study revives + updates it).

## Verification

The bar is the project **differential** (`docs/agent-handoff.md`): host == default == strategy on **MAME +
bsnes-jg**, plus `-verify-machineinstrs` clean. Concretely:

1. **Byte-identical default (P0 gate).** Pre-change vs post-scaffolding `llvm-objdump -d` over corpus+kernels
   at `-Os` default and `+mos-a16` → identical. PASS = no default regression.
2. **Per-strategy correctness.** `dev/run.sh corpus` 7/7 and `a16_fuzz.evaluate` on corpus+kernels under each
   of `+mos-dp-frame` / `+mos-sr-frame` → host==default==strategy on both emulators; `-verify-machineinstrs`
   clean. A new `examples/65816/frameabi*.c` + `dev/frameabi*.sh` value gate per strategy (incl. a **>256 B
   frame** case forcing the DP→soft-stack fallback, and a **recursive** case forcing fallback).
3. **crt0/DBR (A5).** `dev/run.sh crt0native` PASS with a DP-window function in the chain; assert `D=0` at
   `main` entry in the contract gate.
4. **Cycle infra (P1).** `dev/probe-cycles.lua` confirms (or refutes) `total_cycles()` reachability; a known
   fixed-cycle micro-ROM validates the sentinel delta against a hand-count.
5. **The measurement (M).** `dev/measure-frame-abi.sh` emits the 4-way table (`prog | soft | dp | sr | Δ`)
   for **bytes and cycles**, every cell differentially verified first; multi-shape inputs; inner-loop and
   whole-call brackets reported separately.
6. **Fuzz + torture non-regression.** `dev/run.sh fuzz 200+` and a torture pass under the new features → 0
   mismatch / 0 new-crash.
7. **Patch hygiene (only if landing).** `dev/regen-patch.sh` → `0002` round-trips; `git diff --cached
   --name-only` is exactly the authored set; sanity-check `0002` absorbed no foreign hunks.
8. **TODO + decision record.** Add a `TODO.md` M2 entry linking this plan; update the CC frame-decision
   record with the measured result; mirror an `docs/upstream-contribution-status.md` pointer for the #321 CC
   evidence paragraph (posting stays user-triggered).

## Out of scope / non-goals

- **Not** changing argument passing (stays imaginary-register first-pass) or the A/X return convention
  (LOCKED) — this studies the **frame/locals** sub-decision only.
- **Not** auto-merging (a)/(b): landing is gated on the pre-registered bar; the default expectation is a
  measured spike + a null-result decision record.
- **Not** posting upstream from this plan — the evidence paragraph is *prepared*; posting is user-triggered.
