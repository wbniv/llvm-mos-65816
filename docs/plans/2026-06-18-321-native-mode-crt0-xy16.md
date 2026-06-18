# #321 — native-mode crt0, xy16-era audit + the one real gap (explicit DBR=0)

**Branch:** `main` (no worktree needed — this is a `platforms/snes/` + `dev/` + docs change; it does
**not** touch `vendor/` or `0002`, so it rebuilds the **SDK only** via `dev/run.sh build`, exactly like
[`2026-06-14-321-native-mode-crt0.md`](2026-06-14-321-native-mode-crt0.md)).

## TL;DR

This task was filed as *"the full xy16-aware crt0 (16-bit SP setup, etc.) is still needed."* **Measured,
that premise is stale.** The crt0 already enters native mode, already does the 16-bit SP setup, and already
has native + emulation vectors; the authoritative xy16 plan even certifies *"No crt0 changes needed"* for the
in-function xy16 work, and `xy16basic`/`xy16spill`/`xy16spillr` already PASS. The one thing the crt0 does
**not** do — and the task literally names it — is **establish DBR=0 explicitly**. A relocation census proves
DBR=0 is **load-bearing** (the 8-bit `abs` global path + every MMIO write are DBR-relative), yet it is
satisfied only by the power-on reset default, never asserted by the crt0 — unlike the analogous M/X width
contract, which the crt0 *does* pin explicitly with `sep #$30`. **This plan closes that one gap** (a 2-byte
`phk; plb`), adds a standing contract-regression gate, and reconciles the stale docs.

---

## Context — what the crt0 already does (and the stale premise)

`platforms/snes/crt0.c` `.init.50` today (verified COMPLETE 2026-06-14, all 5 steps PASS):

```asm
sei                 ; mask IRQ
cld                 ; binary mode
clc
.byte 0xfb          ; XCE      -> E=0, 65816 native mode (M=1,X=1 kept from reset)
.byte 0xc2,0x10     ; REP #$10 -> 16-bit index regs so txs takes a full 16-bit value
.byte 0xa2,0xff,0x01; LDX #$01ff  (16-bit immediate)
txs                 ; hardware stack pointer -> $01FF (page 1)   <-- the "16-bit SP setup"
.byte 0xe2,0x30     ; SEP #$30 -> M=1,X=1: 8-bit A+index (the explicit codegen-default contract)
lda #$00 / sta $4200; NMITIMEN: no NMI/IRQ/auto-joypad
lda #$8f / sta $2100; INIDISP: force blank
```

Three of the task's four named items are **already present**, and the project's own docs say so:

| Task item | Reality | Evidence |
|---|---|---|
| **XCE / native mode** | Done | `crt0.c` `.byte 0xfb`; [`2026-06-14` plan](2026-06-14-321-native-mode-crt0.md) verification §1 PASS |
| **native vectors** | Done | `link.ld` `.snes_vectors_native` $FFE0–$FFEF + `.snes_vectors_emu` $FFF0–$FFFF |
| **"16-bit SP setup (still needed)"** | **Already done** | `rep #$10; ldx #$01ff; txs` → SP=$01FF (the transient 16-bit `ldx` is *exactly* the 16-bit SP setup) |
| **"full xy16-aware version"** | **Nothing more needed** | [xy16 plan](2026-06-17-321-xy16-index-register-mode.md) §Prerequisites: *"No crt0 changes needed."* `xy16basic/spill/spillr` PASS |
| **DBR setup** | **NOT done — the real gap** | crt0 never sets DBR; relies on reset DBR=0 (census below) |

The project docs currently **disagree** with each other and must be reconciled (see §Doc reconciliation):
- `TODO.md` (M2 xy16 line) lists *"native-mode crt0"* as a remaining xy16 follow-on.
- The xy16 plan says *"No crt0 changes needed."*
- `ROADMAP.md` says the native crt0 *"now landed."*

The TODO line is stale: it predates the xy16 plan's certification that the in-function xy16 work needed no
crt0 change. The genuine remaining crt0 work is **(a)** the DBR=0 contract (this plan) and **(b)** whatever the
*hardware-stack-ABI / calling-convention* follow-on demands — which is a separate, upstream-gated open item.

---

## The measured reality — DBR=0 is load-bearing (don't assume; measure)

Governing lesson #1 bit twice here. A first *synthetic* probe (an unlinked `.o` whose operands all print as
`$0`, plus a `volatile` array that happened to compile to `long,x`) suggested *"codegen is DBR-independent,
no DBR setup needed."* **A broader census with relocations overturned that.**

The addressing mode (hence DBR-dependence) is set by the **opcode**, and the relocation width confirms it:
- `ae`/`ac`/`8d` = `LDX/LDY/STA abs` + **`R_MOS_ADDR16`** → 16-bit `abs`, effective address **`DBR:addr`** → **DBR-relative**.
- `af`/`8f` = `LDA/STA long` + **`R_MOS_ADDR24`** → 24-bit `long`, bank in the operand → **DBR-independent**.

**Census across `examples/65816/*.c`, `+mos-a16` (and identical for `+mos-a16,+mos-xy16`):**

```
R_MOS_ADDR16 (16-bit abs, DBR-relative)    total: 83
R_MOS_ADDR24 (24-bit long, DBR-independent) total: 346
```

A 16-bit global copy `g = gg` is split by build (same source, different addressing):

```
default (8-bit):  ae 00 00  ldx gg        R_MOS_ADDR16   <- abs, DBR-relative
                  ac 00 00  ldy gg+1      R_MOS_ADDR16
+mos-a16 native:  af 00 00 00  lda gg     R_MOS_ADDR24   <- long, DBR-independent
                  8f 00 00 00  sta g      R_MOS_ADDR24
```

…and even *within one a16 function* (`a16ret.c`) the **same global** is touched both ways — `ae .. R_MOS_ADDR16 a`
(low byte, abs) and `af .. R_MOS_ADDR24 a+1` (high byte, long). So the platform's near-data access is a
**mix**, not uniformly DBR-independent (the `inc abs` rejection note's blanket *"all data via DBR-independent
long"* is true only of the 16-bit-accumulator path — see §Doc reconciliation).

**Three things depend on DBR=0, all satisfied today only by the power-on reset default:**
1. **8-bit `abs` scalar-global access** — the 83 `R_MOS_ADDR16` sites read/write `DBR:addr` (globals live in
   bank-0 low WRAM $0200–$1FFF, reachable in bank $00 only with DBR=0).
2. **The crt0's own MMIO writes** — `sta $4200` / `sta $2100` are `STA abs` (`8d`) → `DBR:$4200` / `DBR:$2100`.
   With DBR≠a system bank these would hit WRAM, silently *not* masking NMI / *not* force-blanking. (At
   `.init.50` time DBR is still 0 by reset — nothing has run — so these are safe *by timing*; the program's
   83 global sites that run later are what the explicit contract really protects.)
3. **Soft-stack / locals** are direct-page (`a5`/`85`/`a6` …), which is **always bank 0** regardless of DBR —
   so those are *not* a DBR concern. Good to know, and worth stating so the contract is precise.

The crt0 already pins the *width* invariant explicitly (`sep #$30`, redundant over XCE's M=1/X=1 but stated
as a contract). **DBR=0 is the same category of standing invariant and deserves the same explicit treatment**
— today it is an unstated reliance on a reset default that any future bank switch, `MVN`/`MVP` block move
(both *load* DBR from their operand), or interrupt handler could violate.

---

## Approach

### 1. Establish DBR=0 explicitly in `.init.50` (the one code change)

Add `phk; plb` (PHK=`0x4B`, PLB=`0xAB`) **after** the `txs` (so SP=$01FF is set before we push) and **before**
the first DBR-relative MMIO write. Encoded as `.byte` like the existing 65816-only opcodes (the TU is
assembled for the 6502):

```asm
txs                 ; SP -> $01FF  (must precede phk: phk pushes onto the hardware stack)
.byte 0xe2,0x30     ; SEP #$30 -> M=1,X=1 (8-bit width contract)
.byte 0x4b          ; PHK  -> push program bank (=0; reset/boot code is in bank $00)
.byte 0xab          ; PLB  -> DBR := 0  (explicit "all near data is bank $00" contract;
                    ;         the 8-bit `abs`/R_MOS_ADDR16 global path + MMIO writes read DBR:addr)
lda #$00 / sta $4200
lda #$8f / sta $2100
```

Cost: **2 bytes, ~7 cycles, once at boot.** Net SP change: zero (push then pull). It sets DBR to the value it
already holds (0), so it cannot change behavior today — it converts an implicit reset-default reliance into an
explicit, documented contract, robust against any future code path that leaves DBR non-zero.

`platforms/snes-far` inherits the crt0 via `PARENT snes`; bank-1 *data* there is read via `long`
(DBR-independent), so DBR=0 is correct and harmless for it too (re-run `far-bank1` confirms).

### 2. Make the full native-mode contract explicit in the crt0 comment

Rewrite the `.init.50` comment block to state the complete entry contract in one place — **E=0, SP=$01FF
(page 1), M=1, X=1, DBR=0, DP=0 (reset; the direct page never moves on this platform), vectors** — and *why*
DBR=0 is required (the 8-bit `abs`/`R_MOS_ADDR16` global path + MMIO), citing this plan. This is the
documentation half of the contract; the `phk; plb` is the enforcement half.

### 3. Standing contract-regression gate: `dev/crt0native.sh`

Turn the one-time 2026-06-14 verification into a **standing** test (wired into `dev/run.sh`, `-h` aware,
`set -euo pipefail`), so the contract can't silently drift (e.g. someone "simplifying" `rep #$10; ldx #$01ff;
txs` back to an 8-bit `ldx #$ff; txs` that quietly puts SP at $00FF and corrupts the direct page on the first
`JSR` — the exact risk the 2026-06-14 plan flagged). It asserts, on a **linked** ROM (`hello.sfc`):
- `.init.50` is byte-exact: `78 d8 18 fb c2 10 a2 ff 01 9a e2 30` **`4b ab`** `a9 00 8d 00 42 a9 8f 8d 00 21`
  (the `4b ab` is the new DBR=0 establishment, in position after `txs`/`sep #$30`).
- Native vectors at `$FFE0–$FFEF` and emulation vectors at `$FFF0–$FFFF` are present, with RESET=`$FFFC`→`_start`.
- A **functional** re-assert that the 8-bit `abs` global path still round-trips under the explicit DBR=0 —
  the existing `dev/run.sh corpus` `globals` case (crt0 `.data` copy + `.bss` clear + global read-back, an
  8-bit build that exercises `R_MOS_ADDR16` access) already covers this; the gate references/asserts it rather
  than duplicating it. (A nonzero DBR would corrupt those globals → corpus `globals` would fail. So the
  functional guard already exists; this gate adds the *disasm* guard that the contract is present.)

### 4. Reconcile the docs (same turn)

See §Doc reconciliation.

---

## Critical files

| File | Change |
|---|---|
| `platforms/snes/crt0.c` | `.init.50`: add `.byte 0x4b` (PHK) + `.byte 0xab` (PLB) after `txs`/`sep #$30`; rewrite the contract comment (E/M/X/SP/DBR/DP/vectors + the DBR=0 rationale) |
| `dev/crt0native.sh` | **New** — standing native-mode-contract gate (disasm of linked reset path + vector tables + functional global round-trip reference) |
| `dev/run.sh` | Wire `crt0native` into the dispatch |
| `TODO.md` | Reconcile the stale xy16 "native-mode crt0" follow-on; add the `[verify]` item for this plan |
| `docs/ROADMAP.md` | Note DBR=0 is now explicit; correct the "all data DBR-independent" framing if it appears |
| `docs/agent-handoff.md` | One line: DBR=0 is an explicit crt0 contract; 8-bit `abs` globals are DBR-relative |

No `vendor/` edit, no `0002` regen, no toolchain rebuild — **SDK-only** (`dev/run.sh build`).

---

## Risks

- **`phk` before a valid SP.** `phk` pushes one byte; if SP were garbage it would clobber a byte and (paired
  with `plb`) net-neutral SP, but the clobber is undefined. **Mitigation:** placement is strictly **after**
  `txs` (SP=$01FF). Verified by the byte-exact disasm gate (the `4b ab` must follow `9a e2 30`).
- **Wrong program bank at `phk`.** `phk` pushes PB; if code were not in bank $00, DBR would be set wrong.
  Boot/reset code *is* bank $00 (RESET vector `$00:FFFC`; both the 32 KiB and snes-far linker scripts place
  `.text`/`.init` in bank $00). Safe.
- **`plb` sets N/Z.** Harmless — no branch consumes flags between `plb` and the following `lda #$00`.
- **Platform-wide: every program reboots through this.** Same blast radius as the 2026-06-14 native-mode
  flip; guard is the full green tree (corpus + far + xcheck + a16 + xy16 + fuzz), all in native mode.
- **Redundant-today objection** (governing lesson #2: don't add code that can't help). Weighed and rejected:
  DBR=0 is a *standing architectural invariant* the codegen relies on (83 `R_MOS_ADDR16` sites + MMIO), not a
  one-off defect — establishing it is the crt0's job, exactly as it already does for M/X via `sep #$30`. The
  change is zero-risk (sets DBR to its current value) and gated by the same predicate as the feature it
  protects (bank-0 data placement, which is the whole platform).

---

## Verification

Steps are the spec; raw output + PASS/FAIL filled in at implementation time. Run on a **quiet box**.

### 1. DBR=0 is load-bearing (justification — already measured)

```
R_MOS_ADDR16 (16-bit abs, DBR-relative)    total across examples/65816/*.c, +mos-a16: 83
R_MOS_ADDR24 (24-bit long, DBR-independent) total: 346
a16abs.c default: ae 00 00 ldx gg  R_MOS_ADDR16   (abs, DBR-relative)
a16abs.c +a16:    af 00 00 00 lda gg R_MOS_ADDR24  (long, DBR-independent)
crt0 MMIO: sta $4200 / sta $2100 -> STA abs (8d), DBR:$4200 / DBR:$2100
```

PASS (measured 2026-06-18) — the 8-bit `abs` global path + MMIO writes are DBR-relative; DBR=0 required.

### 2. crt0 byte-exact with explicit DBR=0 (2026-06-18)

Linked `crt0native.sfc` reset path (follow `$FFFC`):

```
emu RESET   : $8000 -> _start
reset bytes : 78d818fbc210a2ff019ae2304baba9008d0042a98f8d0021
expected    : 78d818fbc210a2ff019ae2304baba9008d0042a98f8d0021
PASS: .init.50 byte-exact (native entry + 16-bit SP + M=1/X=1)
PASS: phk/plb (4b ab) present immediately after sep #$30 — DBR=0 is explicit
```

PASS — PHK/PLB (`4b ab`) land immediately after `sep #$30` (`e2 30`), before the NMITIMEN write.

### 3. Green tree unchanged in native mode with explicit DBR=0 (2026-06-18)

```
dev/run.sh corpus  → 7/7  (hello/arith/control/arrays/structs/funcs/globals)
  globals  PASS  corpus_result=0xAB55   (crt0 .data copy + .bss clear + abs/R_MOS_ADDR16 global access)
  funcs    PASS  corpus_result=0x011E   (calls + recursion, soft stack)
dev/run.sh a16abs  → PASS  0x5A3D on MAME + bsnes-jg   (native-16 long/DBR-independent path)
dev/run.sh far-run → PASS  0xF3 on MAME                (snes far load+store, DBR-independent)
dev/run.sh far-bank1 → PASS 0xF3 on MAME               (snes-far PARENT crt0 inheritance, bank $01)
```

PASS — corpus 7/7; the 8-bit `abs` global path (`globals`), recursion/soft-stack (`funcs`), the native-16
path (`a16abs`), and the snes-far crt0 inheritance all hold with the explicit DBR=0.

**BLOCKED (concurrent toolchain, not this change):** the full `dev/a16*.sh`/`dev/k_*.sh` suite, the
`xy16*` tests, and `dev/run.sh fuzz 50 1` could not be re-run: a concurrent worker rebuilt the **shared**
`build/llvm-mos-install` toolchain at 06:52 from a `vendor/` state **below the xy16 merge**, so the binary
reports `'+mos-xy16' is not a recognized feature` (and shifted the a16 soft-stack spill shape → `a16spillr`/
`xy16spillr` disasm gates fail on *value-correct* output: `0x3457` still agrees on both emulators). Pinned:
`clang-23` mtime advanced 01:55→06:52 with no toolchain build started here; `vendor/llvm-mos` HEAD at pristine
`c798c3141` with no `FeatureIndex16` in the working tree; committed `patches/0002` still carries all 41 xy16
hunks (source-of-truth intact). This is provably orthogonal to a boot-time `.byte 4b/ab`. **Re-run when the
shared toolchain is restored to a `+mos-xy16`-capable state** (do **not** clobber the concurrent build), then
promote the TODO item to `[x]`.

### 4. `dev/run.sh crt0native` passes (2026-06-18)

```
PASS: .init.50 byte-exact (native entry + 16-bit SP + M=1/X=1)
PASS: phk/plb (4b ab) present immediately after sep #$30 — DBR=0 is explicit
native NMI=$802E IRQ=$802D   emu NMI=$802E IRQ=$802D
PASS: native NMI/IRQ == emulation NMI/IRQ (both -> the rti stubs)
MAME:     SMOKE: PASS addr=0x7E0202 len=2 got=0x2345 (8-bit abs global round-trip => DBR=0 holds at runtime)
bsnes-jg: SMOKE: PASS off=0x202   len=2 got=0x2345 (independent confirmation)
RESULT: PASS — native-mode crt0 contract holds (DBR=0 explicit, vectors placed, round-trip OK)
```

PASS — the standing gate confirms the contract on both emulators.

### 5. xy16 unaffected

DBR posture is unchanged by xy16 — measured **before** the concurrent vendor reset: the `R_MOS_ADDR16`/
`R_MOS_ADDR24` census was byte-identical for `+mos-a16` and `+mos-a16,+mos-xy16` (41 vs 41 DBR-relative
opcodes), and the change is a boot-time `.byte` orthogonal to the X-flag. Re-confirm the `xy16*` tests PASS
alongside step 3's blocked re-run once `+mos-xy16` is back in the shared toolchain.

---

## Doc reconciliation (same commit)

1. **`TODO.md` M2 xy16 line** — strike *"native-mode crt0"* from the *Remaining follow-ons*: the in-function
   xy16 work needed no crt0 change (xy16 plan §Prerequisites); the only crt0 items are this DBR=0 contract
   (this plan) and the CC-gated DP-frame (below). Leave the follow-ons as *legalizer integration* +
   *hardware-stack ABI / calling convention*.
2. **The `inc abs` rejection note** (TODO done-line + ROADMAP) says *"this platform addresses all data via
   DBR-independent long loads/stores."* Narrow it: that holds for the **16-bit-accumulator** path; the **8-bit
   `abs` scalar-global path is DBR-relative** (`R_MOS_ADDR16`) and relies on DBR=0 — which is *why* the crt0
   now establishes it. (This does **not** reopen `inc abs`: that was rejected because there's no `inc long`
   and `inc abs`'s DBR-relative RMW couples to placement; explicit DBR=0 doesn't change that calculus.)
3. **`docs/agent-handoff.md`** — add DBR=0 to the platform contract notes.

---

## Out of scope (gated elsewhere)

- **Hardware-stack ABI / 16-bit calling convention** — the *other* genuine native-mode crt0 work, but it is
  **gated on the open [calling-convention decision](../investigations/65816-calling-convention-decision.md)**
  (the "frame" sub-decision: ORCA/WDC-style DP-window `tsc; phd; tcd` vs stack-relative vs keep-soft-stack).
  Only the DP-window choice changes the crt0 (it would add a per-frame `phd/tcd`, not a boot-time change). Do
  **not** front-run an undecided, upstream-blessed ABI. Forward note for whoever lands it: a DP-frame keeps
  DBR=0 (this plan) and adds DP setup per call; keep-soft-stack needs *no* further crt0 change.
- **Native interrupt service** — real NMI/IRQ handlers (vblank/input) replacing the `rti` stubs. The bare
  `rti` stubs are width-safe (interrupts are masked all through bring-up; `rti` restores P, hence M/X, on
  return). **xy16 wrinkle to record for that future work:** a real native-mode handler can be entered with
  **M=0 and/or X=0** (it may interrupt a `rep #$30` region), so it must `php`/save and force known widths
  before touching A/X/Y and restore via `rti` — the handler cannot assume 8-bit width. (Carried from the
  2026-06-14 plan's out-of-scope; the M16/X16-entry note is the new xy16-specific addition.)
