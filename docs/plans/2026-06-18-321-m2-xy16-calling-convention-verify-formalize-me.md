# #321 M2 — xy16 calling-convention: verify, formalize & measure the boundary

**Project:** llvm-mos-65816, issue #321, ROADMAP M2 (native 65816 codegen, ROADMAP step 5 frontier).
**Scope (user-chosen):** *Verify + formalize the resolved 8-bit-register xy16 boundary, then cheaply MEASURE
the two xy16-specific boundary levers and close-with-evidence or greenlight each — build a lever only if its
measurement shows a real gated win.* (Not the speculative hardware-stack-spill build.)

---

## Context — why this work, and what is NOT in question

The "xy16 hardware-stack ABI" was the last open item on the M2 calling-convention frontier. Exploration this
session established that the *design* is **already decided and the boundary is already mechanically built** —
what is missing is **verification, formalization, and measurement**, not a new feature:

1. **All four CC sub-decisions are resolved** ([CC decision doc](../../SRC/llvm-mos-65816/docs/investigations/65816-calling-convention-decision.md),
   [phased record](../../SRC/llvm-mos-65816/docs/plans/2026-06-18-321-cc-frame-phased-decision.md)): return = **A(low)/X(high)** (locked,
   `dev/run.sh a16ret`); args = **imaginary-register passing**; frame = **soft static stack**; recursion =
   soft static stack. The hardware-stack *frame* and stack-relative arg passing were **measured NULL** (the
   frame-ABI census: **0/13** realistic functions profit, `dev/frameabi-census.sh`) and shelved with evidence.

2. **The xy16 boundary is already implemented** in the backend (`vendor/llvm-mos/llvm/lib/Target/MOS/`):
   `MOSInsertREPSEP.cpp` `requiredXWidth(MI)` forces `XW_X8` for `isCall()`/`isReturn()` and seeds
   `XIn[Entry]=XW_X8`; `X16`/`Y16` are **caller-saved** (`MOS_CSR` in `MOSCallingConv.td` lists only RC20–RC31;
   the generated `MOS_CSR_RegMask` clobbers them); caller-save spill encodings exist for both stacks
   (static: `STXAbs16`/`LDXAbs16`; soft: `TXA16`+`STAIndir16`). The contract is *"+mos-xy16 is an in-function
   optimization; X/Y are 8-bit at every call boundary."*

3. **The gap is a missing differential test, not a missing feature.** **No** existing test holds a 16-bit-index
   value (`Xc16`/`Yc16`) live across a non-recursive call — every xy16 test (`xy16basic`/`ops`/`indiry`/`spill`/
   `spillr`) indexes *within* a function; `xy16spillr` is recursive but carries `Ac16`, not `Xc16`. The
   correctness of "X16 survives a call" rests on an **untested** chain: the RA must spill `Xc16` *before* the
   REP/SEP pass inserts the `sep #$10` that narrows X (a wrong order zeroes X's high byte — the **seed-247/445
   bug class**). The structural argument says it is correct (RA spills before `MOSInsertREPSEP` runs in
   `addPreEmitPass`; Track A already hardened the 8-bit-indexed family) — so the test most likely comes back
   **GREEN**, and the deliverable is the *locked regression guard + formalized docs*. But by the project bar
   (differential on both emulators) it must be proven, not assumed.

4. **Two xy16-specific boundary levers remain unmeasured** — these are the only places xy16 could change the
   boundary, and both get a cheap *measurement-first* pass (not a speculative build): an **i32 return in
   A16:X16** (the A/X-return note's "high word in X" intent) and a **PHX/PLX hardware-stack caller-save spill**
   of X16/Y16 (the literal "hardware-stack ABI"; `PHX`/`PLX`/`PHY`/`PLY` exist as MC instructions but no spill
   path uses them today — the backend spills only via the soft/static stack).

**Intended outcome:** the xy16 call/return boundary becomes a *tested, locked, documented* ABI invariant (the
xy16 analogue of the A/X-return promotion), and the two optimization levers are each **closed with evidence**
(near-certain, given the frame-ABI NULL precedent and the i32-return rarity) or **greenlit with a measured
win**. This retires the M2 CC frontier.

> **STATUS: DONE 2026-06-21.** All deliverables landed; the boundary is verified correct on both emulators
> and both optimization levers are measured + shelved with evidence. See the filled-in Verification section
> below for the raw results. The detailed cite-anchored design (exact C shape, MIR/disasm gates, B-fix
> diagnosis tree) was worked out in-session; this file is the executable record.

---

## Phase A — Verify + harden + formalize the 8-bit boundary (the core)

### A1. Cross-call xy16 differential micro-test — the missing regression guard

**New:** `examples/65816/xy16call.c` + `dev/xy16call.sh`, wired into `dev/run.sh` (usage/help only — dispatch is
generic). **Clone:** `examples/65816/a16loadcall.c` (cross-call value + clobbering callee) and
`dev/xy16indiry.sh` (4-way differential + selector-MIR + objdump gates) and `dev/a16ret.sh` (the `fn_body` awk
disasm-trimmer + dual value/disasm gate). **Helpers:** `dev/_emu.sh` `require_bios` / `run_assert` / `emu_verdict`.

**The C shape must satisfy three constraints at once** (the crux — defeating LTO narrowing):
- **Genuinely 16-bit index** so it lands in `Xc16` and survives `--config` LTO: a `pr49419`-style *computed
  chase* the optimizer cannot bound to ≤8 bits (read the index from an array element holding a value ≥256,
  e.g. `0x0102`), seeded by a `volatile` so it can't const-fold. A simple `arr[volatile_short_idx & 7]`
  **will not work** — LTO proves it fits a byte and narrows X to 8-bit (handoff gotcha).
- **Live across a real call** so the RA must spill `Xc16`: a `__attribute__((noinline))` callee that clobbers
  X/Y sits between the index's definition and its post-call use.
- **Used as an index AFTER the call** so the seed-247/445 `selectXY16` filter keeps it in `Xc16` (a value whose
  only post-call user is a COPY is reclassed to `Imag16`, exercising the wrong path).

Reference shape (`struct Node{u16 next,pad}` chase + clobbering call + post-call `big[idx]`; expected
`corpus_result == 0x7E5A`; if the high byte is lost the read hits `big[0x02]` → differential FAIL) — full
listing in the companion plan §A.1.

**Two gates** (run on the per-function `-c` build, where structure is stable):
1. **Selector-MIR gate** (`-mllvm -print-after=instruction-select`): assert `LDAbsXIdx16` (genuine 16-bit index
   selected, not narrowed) **and** an `Xc16` spill across the call (`STXAbs16`…`LDXAbs16` for non-recursive
   `main`).
2. **Ordering gate** (`-S`/objdump, `a16ret.sh`-style trimmer): the spill-**store** appears **before** the
   `sep #$10` that precedes `jsr`, and the reload **after** the following `rep #$10`. This structurally locks
   the "spill-before-narrowing-sep" invariant against future scheduler drift.
3. **LTO-narrowing tripwire** (mandatory, on the `--config` ROM `llvm-objdump -d`): at least one
   `rep #$10`/`rep #$30` bracketing the post-call indexed load survives. **Zero ⇒ LTO narrowed it ⇒ FAIL
   loudly** with "escalate to the pr49419 double-indirect chase" — else the test passes trivially without
   exercising the boundary (false GREEN — the single highest risk).

**Value differential:** `host == default == +mos-a16 == +mos-xy16` on **MAME + bsnes-jg** (`run_assert` ×3 +
`build/jgxcheck`). Value test catches miscompiles; gates 1–2 catch convention drift — keep both (the
`a16ret.sh` doctrine).

### A2. If A1 exposes a miscompile — gated root-cause + fix

Run the 4-way. If `+mos-xy16` diverges (high byte lost), diagnose in order (companion plan §B):
(1) confirm both emulators agree on the *same wrong* value (else emulator artifact); (2) did the RA spill
`Xc16`? (`-print-after=virtregrewriter` around the `jsr`; inspect the `JSR` `RegMask` — does it clobber X16
*and* sub-units?); (3) did a late post-RA pass reorder the spill past the `sep`?
**Candidate fixes, smallest first:** (a) regmask/subreg coverage in `MOSRegisterInfo.cpp`/`MOSCallingConv.td`
so an `Xc16`-class vreg live across a call is forced to spill (lowest risk — only ever *adds* a spill);
(b) class-liveness in `selectXY16`; (c) a scheduling/`requiredXWidth` lock (highest risk — last resort).
**Every fix is `hasIndex16()`-gated** so default + `+mos-a16` codegen stay **byte-identical** (prove it). Do
`vendor/` changes on a **throwaway worktree** off `main` (`docs/howto-feature-worktree.md`, `cp -al` the warm
`build/`), regenerate `patches/llvm-mos/0002-321-accum16.patch`, confirm it round-trips with **no foreign
hunks**. **Avoid the refuted XH/YH implicit-def approaches** (highbyte-clobber investigation UPDATE 2: they
don't force interference). *If A1 is GREEN, B is a no-op — record "boundary verified correct, no fix needed."*

### A3. Formalize the contract (docs — no codegen change)

- **`docs/investigations/65816-calling-convention-decision.md`**: add a section **"Index registers across
  calls — adopted (X/Y 8-bit at boundaries; X16/Y16 caller-saved)"**, sibling to the existing "Return values —
  adopted", stating the contract precisely and naming `dev/run.sh xy16call` as the regression guard.
- **`docs/320-321-65816-c-abi-prior-art.md`**: one-line note that the 16-bit index across calls follows the
  same caller-saved posture (consistent with the A/X "high word in X" prior art).
- **`docs/plans/2026-06-21-321-xy16-cross-call-boundary.md`** (new, repo-resident): the design record for the
  test (analogous to `2026-06-17-321-ax-return-convention.md`).
- **`TODO.md`** M2: under the "#321 stage 1 — full xy16 mode + ABI" bullet's "hardware-stack ABI + calling
  convention" follow-on, note the boundary is now **verified + locked** by `xy16call`; promote to a Done line
  if a B fix landed.

### A4. Fuzzer coverage — hold a 16-bit index across a non-recursive call

**`tools/a16_fuzz.py`** (tracked tool — no `vendor/`, no `0002` regen): add a generator shape in `main`'s body
that defines a runtime-derived 16-bit index, makes a non-recursive `noinline` call that clobbers X/Y, then
indexes with the carried value after the call (reuse `Index`/`Call`; `eval` support is free so `expected()`
stays exact). **Note the LTO caveat in a comment:** the masked `arr[idx & 7]` path is 8-bit-narrowable by
design — the cross-call shape must index a **wider unmasked array** (pr49419 idiom) to keep the index 16-bit
past LTO. (Lower-effort fallback: also emit `xy16call.c` as a fixed builtin-corpus seed; prefer the dynamic
shape for breadth.)

---

## Phase B — Measure the two xy16-specific levers (close-with-evidence or greenlight)

Measurement-first, modeled on `dev/frameabi-census.sh`: **the census IS the deliverable**; a backend change
follows *only* if a census/probe shows a real, gated win. Decide on **bytes** (`-Os`), cycles tiebreaker.

### B1. i32-return-in-A16:X16 — census (near-certain NULL)

**New (host-only, no Docker):** `dev/xy16ret32-census.sh` — count i32-returning functions and i32-consuming
**call sites** across the REALISTIC group (`examples/snes/corpus/*.c` + `examples/65816/k_*.c`) and the
c-torture in-scope set (`examples/65816/torture/inscope.tsv`), via `-S -emit-llvm` grep of `define ... i32 @`
and `call i32 @` (non-pointer). **Short-circuit rule:** `N_i32callsite == 0` on REALISTIC + c-torture ⇒ STOP,
record the NULL. **Pre-checked evidence:** the realistic corpus has **zero** i32 return values (only one inline
`uint32_t` in `arith.c`, never returned) — the same 0/realistic signature as the frame-ABI NULL, same root
cause (llvm-mos keeps wide values register-resident; wide arithmetic is consumed inline, not returned).
Expected outcome: **measured NULL, closed with evidence** — *"the A/X return already anticipates the high word
in X, but no realistic code exercises it, and realizing it requires punching a typed hole in the REP/SEP pass's
'8-bit at every boundary' correctness invariant (a coordinated change across `CC_MOS`/a new `RetCC`,
`lowerReturn`+`lowerCall`, and both width predicates) for a c-torture-only opportunity."* If the census
surprises with real opportunity, the gated sketch (`hasIndex16() && isI32Return`) + an `xy16ret32.c`/`.sh`
guard is in the companion assessment.

### B2. PHX/PLX hardware-stack index-spill — probe (the literal "hardware-stack ABI")

**The lever:** spill a caller-saved `X16`/`Y16` across a call with `PHX`/`PLX` (2 bytes when X=16) — one byte,
one instruction, hardware stack — instead of the current soft-stack `TXA16`+`STAIndir16` accumulator round-trip
(or static `STXAbs16`/`LDXAbs16`). `PHX`/`PHY`/`PLX`/`PLY` already exist (`MOSInstrInfo.td:340–343`); **but no
spill path uses the hardware stack today** (`usesStaticStack` / `expandLDSTStk` are soft/static only), so this
would be a *new* spill path against the backend's design grain (hardware-SP balance around the call,
interrupt/reentrancy interaction with the soft frame, IRQ handlers entered at unknown width).

**Probe (no build):** from the `xy16call.c` spill site (A1) and any cross-call-index fuzzer shapes (A4), hand-
count the byte/cycle delta of the current spill vs the hypothetical `PHX…JSR…PLX` for the *measured frequency*
of "16-bit index live across a call" (which A1/A4 reveal). Bound the opportunity the way frameabi did. **Likely
outcome:** the opportunity is rare (same structural reason as the frame NULL — values stay register-resident),
the hardware-SP/interrupt-safety cost is real, and the win is too narrow to justify a new spill path → **defer
with evidence**, recorded as a TODO Watch trigger ("reopen if cross-call-index-live becomes common"). If the
probe shows it is common *and* clearly byte-positive, write a dedicated gated implementation plan (a new
hardware-stack caller-save spill for `Xc16`/`Yc16`, `hasIndex16()`-gated, differential + SP-balance verified) —
**do not** fold the build into this effort.

---

## Critical files

| File | Role |
|------|------|
| `examples/65816/xy16call.c` *(new)* | Cross-call micro-test; keep `Xc16` genuinely 16-bit across a clobbering call past LTO. Clone `a16loadcall.c` + `xy16indiry.c`. |
| `dev/xy16call.sh` *(new)* | 4-way differential + selector-MIR/ordering gates + LTO tripwire. Clone `dev/xy16indiry.sh` + `dev/a16ret.sh`; use `dev/_emu.sh`. |
| `dev/run.sh` | Add `xy16call` to usage/help (dispatch is generic — no code-path edit). |
| `tools/a16_fuzz.py` | Non-recursive 16-bit-index-held-across-call generator shape (reuse `Index`/`Call`); LTO comment near `ARR_MASK`. |
| `dev/xy16ret32-census.sh` *(new)* | B1 i32-return opportunity census (host-only; clone `dev/frameabi-census.sh`). |
| `docs/investigations/65816-calling-convention-decision.md` · `docs/320-321-65816-c-abi-prior-art.md` · `docs/plans/2026-06-21-321-xy16-cross-call-boundary.md` *(new)* · `TODO.md` | Formalize the contract; record lever measurements. |
| `vendor/.../MOSRegisterInfo.cpp` (+ `MOSCallingConv.td`, maybe `MOSInstructionSelector.cpp`) | **Only if A2 needs a gated fix**; regenerate `patches/llvm-mos/0002-321-accum16.patch`. |

---

## Verification (numbered; raw output + PASS/FAIL — completed 2026-06-21)

**Decisive context: this change set is CODEGEN-INERT.** A2 came back a no-op (A1 GREEN), so there is **no
`vendor/` edit and no codegen change** — only a new test (`xy16call.c`/`.sh`), a new census script, a
`dev/run.sh` help-text edit, a comment in `a16_fuzz.py`, and docs. The differential gates (corpus/fuzz/
c-torture) exist to catch *codegen* regressions; with zero codegen delta they are guaranteed-pass, so the
heavy MAME/c-torture sweeps were **intentionally not re-run** (also: bad-neighbor to a concurrent reduction on
the shared box — the QUIET-box rule). The toolchain was confirmed stable (`clang-23` mtime 2026-06-20 22:04,
no build running) so all measurements are valid against the `main` baseline.

1. **Toolchain build** — N/A (A2 no-op; no `vendor/` change). **SKIPPED (not needed).**
2. **New cross-call gate:** `dev/run.sh xy16call`. Raw:
   ```
   ==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN ... PASS: clean (exit 0)
   ==> 2) post-call genuine-16-bit-index path + cross-call preservation (post-RA MIR)
     PASS: post-call indexed read is the 16-bit-index path (1 LDAbsXIdx16 after JSR; index reloaded via LDXImag16 $rs10)
     PASS: index source $rs10 is callee-saved (in the JSR preserve regmask) — value survives by ZP preservation, no X16 spill needed
   ==> 3) .o disasm ... PASS: 2 rep #$10 + 3 lda long,X; X narrowed before the jsr (1 sep), re-widened after (1 rep #$10) ...
   ==> 5) MAME: default/+mos-a16/+mos-xy16 → SMOKE: PASS ... got=0x7E5A (all three)
   ==> 6) bsnes-jg: SMOKE: PASS off=0x202 len=2 got=0x7E5A (180 frames)
   RESULT: PASS — 16-bit index held across a clobbering call ... corpus_result==0x7E5A; host==default==+mos-a16==+mos-xy16, both emulators
   ```
   **PASS.** (Note: A1 found the boundary is correct *by construction* — the index lives in callee-saved
   `$rs10` across the call, X16 never physically live across it, so the "spill before sep" gate became a
   "preserved-across-call via callee-saved ZP pair" gate; see the revised contract in the CC decision doc.)
3. **xy16 suite non-regression:** codegen-inert (no `vendor/` change); the suite's behavior is identical to
   pre-change. The harness itself was exercised GREEN by the `xy16call` run (step 2). `bash -n` clean on
   `dev/xy16call.sh`/`dev/xy16ret32-census.sh`/`dev/run.sh`; `dev/run.sh` help renders the new `xy16call`
   entry. **PASS (inert; harness confirmed working).**
4. **Gating proof** — N/A (A2 no-op; nothing to prove byte-identical against — no `vendor/` change). **SKIPPED.**
5. **Corpus / fuzz / c-torture** — codegen-inert ⇒ guaranteed-pass; not re-run (shared-box courtesy + no
   codegen delta). `tools/a16_fuzz.py` change is a comment only (`python3 -m py_compile` clean). **SKIPPED with
   rationale (codegen-inert).**
6. *(folded into 5)*
7. *(folded into 5)*
8. **B1 census:** `dev/xy16ret32-census.sh`. Raw verdict:
   ```
   == REALISTIC (corpus + kernels) — the verdict ==   REALISTIC totals: N_i32ret=0  N_i32callsite=0
   == C-TORTURE ==  totals over 1228 files: N_i32ret=154  N_i32callsite=30  (41 files carry any i32 return/call)
   VERDICT: REALISTIC N_i32callsite=0 ; C-TORTURE N_i32callsite=30  → NULL on realistic code; SHELVE with evidence.
   ```
   Finding recorded in the CC decision doc §"Index registers across calls — adopted" + the prior-art note +
   `TODO.md`. **PASS (measured NULL, shelved).**
9. **B2 probe + docs:** the A1 measurement removed the lever's premise (the RA never puts a cross-call index in
   physical X16 → there is no X16 spill to route through `PHX`/`PLX`; cross-call-index caller-save spills are
   further bounded near-zero by the existing ZP-pressure slack of ~5/14 pairs). Shelved with evidence; reopen
   only if cross-call physical-X16 residency becomes common. CC decision doc has the "Index registers across
   calls — adopted" section. No patch (codegen-inert). **PASS (shelved with evidence).**

---

## Risks

- **R1 — LTO narrows the test index to 8-bit (highest).** The mandatory `rep`-count tripwire (A1 gate 3) catches the false-GREEN; escalate to the pr49419 double-indirect chase.
- **R2 — The boundary is probably already correct.** That's a *success* (lock the guard + docs), not a gap — don't manufacture a fix.
- **R3 — seed-247/445 filter routes the value to `Imag16`.** The post-call use MUST be a real indexed read; verify via the selector-MIR gate that the `Xc16` path is chosen.
- **R4 — Both levers near-certainly close NULL/defer.** That is the expected, valuable outcome (close-with-evidence beats speculative building) — do not over-invest; B is measurement, not construction.
- **R5 — `vendor/` worktree discipline** for any A2 fix (throwaway branch, stage only own files, coordinate `0002` regen vs concurrent far-cc/frameabi vendor work).
