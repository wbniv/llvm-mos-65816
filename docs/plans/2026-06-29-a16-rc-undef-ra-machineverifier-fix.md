# `a16-*-rc-undef` — fix the `$x = COPY $rcN` "undefined physical register" MachineVerifier failure

**Status:** CAUSE #1 FIXED + SHIPPED (2026-06-30, commit `f1af264`; newton demo rebuilt + deployed to
[biohack.net/snes/newton/](https://biohack.net/snes/newton/), tag `v1.0.146`). **CAUSE #2 — IN PROGRESS**
(RA-interference fix, `throwaway/rc-undef-fix` worktree). The single `rc-undef` symptom turned out to be
**two distinct defects** sharing the same MachineVerifier error. Both were proven with an **asserts
toolchain** (`build/llvm-mos-asserts`, `-debug-only=regalloc` join traces) on a lifted minimal repro
(`examples/65816/rcundef.c` = `newton_step`).

**Cause #1 — register-coalescer copy-hint (FIXED).** The coalescer folds a value read **straight out of a
call-clobbered imaginary register** (`vreg = COPY $rcN`) into an **Imag16 pair** (a sub-register copy) that
**outlives the clobbering call**; the pair inherits the physical-`$rcN` allocation hint and the allocator
re-binds it to `$rcN` across the clobber → the disconnected `$x = COPY $rcN` def→use. Fixed in
**`MOSRegisterInfo::shouldCoalesce`** (fork patch `0002`): refuse exactly that coalesce (direct
`COPY $rcN` unique-def, live across a call clobbering `$rcN`, into a sub-register of an Imag16). Keeps a
COPY → the value gets its own spillable vreg. **Correctness-safe by construction** (refusing a coalesce can
never change a value) and **tightly gated**: it changes only **4 / 34** corpus programs (`newton_sim`,
`boids_sim`, `raycaster_sim`, `sort-race_sim` — all math-heavy; all stay `-verify` clean + differential
green), the other 30 are **byte-identical**.

**Cause #2 — dead read of an `undef` sub-register lane of a partial `Imag16` pair (DEFERRED — deep RA).**
A *different* shape: `lsystem_sim.c` (all levels) and `newton_sim.c` **at `-O1`** (in `newton_gate_crc`)
hit the same verifier message but with **no `$rcN` copy anywhere** in the value's def/use chain during
coalescing — so `shouldCoalesce` cannot target it (the only coalescer rule that masks it perturbs
**22–25 / 34** corpus programs — the forbidden blanket change, lessons #2/#3). Root-caused precisely
(2026-06-30, asserts `-debug-only=regalloc` on `lsystem_sim.c main`):

- The failing `$x = COPY killed $rc11` (6000B) is a **dead** copy — its `$x` is overwritten 16 bytes later
  (6016B) before any use. It is a leftover use of `%1759`, a 16-bit value passed to `__mulsi3` whose **low
  byte is defined** (`$rc10 = COPY $rc6`) and whose **high byte is `undef`** (the `undef %N.sublo:imag16 =
  COPY …` sub-register idiom marks the sibling lane undef).
- RA assigns `%1759` to `$rs5` (`$rc10:$rc11`) and *tracks the undef high lane as live* from the
  `undef`-def point to the dead 6000B read (trace: `assigning %1759 to $rs5: … RC11LSB [5980r,6000r)`), but
  **no instruction materializes the high lane**. When the virtual subrange is lowered to the **physical**
  `$rc11`, the `undef` attribute is lost (physreg reads carry no undef flag), so the dead full-pair read of
  `$rc11` looks like a use of an undefined physical register — which the verifier rejects. The value is a
  genuine don't-care (the copy is dead), so the code runs correctly (`0x79C3`).
- **Rewriter level (2026-06-30, deeper):** MOS *does* enable sub-register liveness
  (`MOSSubtarget::enableSubRegLiveness() == true`, `Imag16` has disjunct `sublo`/`subhi`), and the
  `VirtRegRewriter` *does* mark undef sub-register reads (`VirtRegMap.cpp` `readsUndefSubreg` →
  `MO.setIsUndef(true)`). The reason it misses this case: a **live-range-split full-pair `COPY`**
  (`%1759 = COPY %x`, both lanes, single def at 5980r) propagates the **undef `subhi` lane as a *live*
  value**, so `readsUndefSubreg` finds a live subrange overlapping the `subhi` lane mask at the read and
  returns `false` (not undef). I.e. the splitter/copy-insertion does **not** carry the lane's `undef`-ness
  through the inserted COPY, defeating the rewriter's existing undef-marking downstream.

This is a **generic-LLVM RA / sub-register-`undef`-liveness** issue (live-range splitting of a
partially-undef pair; the `undef %N.sublo` idiom is pervasive), not MOS-specific behavior. A safe fix is
either (a) carry the `undef` lane through the split/spill `COPY` (SplitKit / InlineSpiller) so the
downstream read is recognized undef, (b) make `readsUndefSubreg` trace the subrange value to its `undef`
origin, or (c) eliminate the dead pair-extract copies before verification — all deep, toolchain-wide, and
**risky to attempt on a shared compiler** for a *code-correct* (latent-only) defect.

**Fix attempt (2026-06-30, candidate (b), reverted).** Implemented a bounded, conservative
`VirtRegRewriter::lanesUndefAt` that traces a spuriously-"live" lane back through full-register virtual
split COPYs to an `undef` origin and feeds it into `readsUndefSubreg` (only ever proves *more* lanes undef
→ correctness-safe; corpus differential as the net). It did **not** clear the witnesses: both are
**loop-carried**, so the `subhi` subrange's reaching value at the read is a **PHI-def** at the loop header,
and the tracer conservatively bails on `isPHIDef()`. Proving PHI undef-origin means recursing across **all**
predecessors **including the loop back-edge** (needs a visited-set + careful slot/lanemask handling) — a
materially larger and riskier change.

**Second attempt (2026-06-30, "globally undef", reverted).** A `laneGloballyUndef` that scans **all** of a
sub-range's value numbers (PHIs skipped as forwarders, COPYs traced one hop, cycles cut by a visited-set) —
sidestepping the loop-PHI problem. Instrumented to log why it bails: for the failing values (`%1759`,
`%1756`, `%1757`) the bails are **conservative**, *not* genuine real-defs — `%1756` is a **sub-register
COPY def** (`dstSub=subhi`) the tracer refuses to invert, and `%1759`/`%1757` have a VNInfo whose def slot
is **valid but maps to no instruction** (`phi=0 defValid=1`, an obscure split-product subrange value). (The
`STAImag16` real-defs the log also shows belong to *other* vregs, correctly not-undef.) So the fix is
**close** — the lane really is path-undef and the blockers are tracer conservatism — but finishing it safely
needs intricate **sub-register lane-mask composition** through subreg COPYs plus handling that obscure
VNInfo, where a wrong lane computation is a **silent miscompile** the corpus might not exercise. For a
*code-correct* (verifier-only) defect that trade is wrong, so it was reverted.

Net: three attempts (rewriter path-sensitive; rewriter global; both informed by the SplitKit `defFromParent`
lane logic) converge on the same conclusion — this is a genuine **generic-LLVM RA feature** (path-sensitive,
loop-aware, subreg-lane-precise undef propagation), not a safe bounded downstream patch. All edits were
isolated to the throwaway worktree's `vendor/llvm-mos/llvm/lib/CodeGen/VirtRegMap.cpp` (generic CodeGen, in
no fork patch) and fully reverted; the shipped Release toolchain never carried any of them. Best done
upstream. Until it lands `lsystem_sim.c` keeps
its `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]` XFAIL and `newton_sim.c -O1` is out of the battery's
verify surface (everything is `-Os`). (`-join-liveintervals=false` masks it only because disabling the
coalescer leaves the dead copies as separate vregs the dead-MI pass then removes.)

| witness | `-O0` | `-O1` | `-Os` | which cause |
|---|---|---|---|---|
| `examples/65816/rcundef.c` (min repro = lifted `newton_step`) | ✅ | ✅ | ✅ | #1 fixed |
| `newton_sim.c` | ✅ | ⚠️ #2 | ✅ | #1 fixed (`-Os`); `-O1` is #2 |
| `lsystem_sim.c` | ✅ | ❌ #2 | ❌ #2 | #2 deferred (XFAIL kept) |
| `gouraud_sim.c` (demo #69 — int32 barycentric-divide raster) | ✅ | ❌ #2 | ❌ #2 | #2 deferred (code bit-exact correct) |
| `msquares_sim.c` (demo #71 — int32 edge-interpolation divide) | ✅ | ❌ #2 | ❌ #2 | #2 deferred (code bit-exact correct) |

**New witnesses (2026-07-01, Round-4 demo battery).** `gouraud_sim.c` (#69) and `msquares_sim.c` (#71)
reproduce Cause #2 at `-O1`/`-Os` under BOTH `+mos-a16` and `+mos-xy16` (`-O0` clean — the classic
pressure signature), measured `Using an undefined physical register` (`renamable $x/$a = COPY killed
renamable $rcN`). Both are **code-correct**: the full differential is green
(`host==default==+mos-a16==+mos-xy16` — `0xC5E9` / `0x86A7` on bsnes-jg). These **broaden the known
trigger population**: before Round 4 the deferred-Cause-#2 witnesses were an L-system (`lsystem_sim.c`)
and heavy soft-float slices; #69/#71 show it is readily hit by **ordinary high-register-pressure
`int32`-divide kernels** (a per-pixel barycentric/edge-crossing divide with a live rotation/interpolation
set) — i.e. common integer-graphics code, not an exotic corner. They are caught by their own demo gates
(`dev/run.sh gouraud` / `dev/run.sh msquares`, 5-way differential) and classified XFAIL by
`tools/a16_fuzz.py` `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]`; no action beyond this record until the
generic-LLVM RA fix lands upstream.

`newton_sim.c` at `-Os` is the **ship/verify** level (`tools/a16_fuzz.py` + every demo/corpus build use
`-Os`); its `-Os` XPASS guard fires → the **newton** XFAIL drops. The newton ROM **changes bytes** (the fix
refuses a coalesce → different registers) while preserving the value (`0x4D8B`, 5-way differential), so the
demo is genuinely rebuilt + republished.

**Durable record (the standalone write-up of the whole two-cause arc):**
[`docs/investigations/2026-06-30-65816-a16-rc-undef-two-causes.md`](../investigations/2026-06-30-65816-a16-rc-undef-two-causes.md).

## Context

Under `+mos-a16`/`+mos-xy16` at `-O1`/`-Os`, high-register-pressure functions emit a
`renamable $x = COPY killed renamable $rcN` where the `$rcN` (a **zero-page imaginary 16-bit register
pair**, e.g. `$rc3`, `$rc11`) has **no visible definition** on the path reaching the COPY. The
MachineVerifier rejects it (`*** Bad machine code: Using an undefined physical register ***`, exit 70),
aborting `-verify` builds. **The emitted code runs CORRECTLY** (the value is genuinely in `$rcN` at
runtime — verified: both demos' 5-way differential is exact: newton `0x4D8B`, lsystem `0x79C3`), so this is
a **verifier false-positive / def-tracking gap**, not a miscompile.

It has been an open issue since the #2 Newton demo shipped (2026-06-27) with `newton_sim.c` registered as
`KNOWN_ISSUES["a16-newton-step-rc-undef"]` + a `KNOWN_ISSUE_REPROS` XFAIL in `tools/a16_fuzz.py`. The #23
L-System demo independently reproduces the same class (in `main`, after the demo's string-rewrite + bracket
stack inline), confirming it is **not** newton-specific.

## It's the REGISTER COALESCER (decisive, 2026-06-29)

`-mllvm -join-liveintervals=false` (disable the coalescer) → **`newton_sim.c` `-verify` CLEAN** at
`-Os`/a16. So the disconnected def→use is **created by the register coalescer**, not the core RA — which
means the fix is **low-risk**: refusing a coalesce in `MOSRegisterInfo::shouldCoalesce` is *always* safe
(it only costs a copy, never correctness), and the **corpus-byte-identical** check is the safety net for
narrowing the rule. This is the same hook + risk profile as the committed `0010-coalesce-rotate-ac` fix.

**The bad coalesce (hypothesis, from the MIR):** a value live **across a `$rcN`-clobbering libcall**
(`JSR __mulsi3 … implicit-def $rc3`, with the `mos_csr` regmask) gets coalesced **into that `$rcN`**, so
its def is destroyed by the call yet a later block reads it — the coalescer's interference check isn't
treating the call's `implicit-def`/clobber of the imaginary `$rcN` pair as conflicting with the
cross-call-live value. Candidate fixes (lowest-risk first): (a) a `shouldCoalesce` refusal when coalescing
a value into an `Imag8/Imag16` ($rc) class across a clobbering call (query `LIS`); (b) ensure libcalls'
`implicit-def $rcN` / the CSR regmask correctly mark the imaginary pairs clobbered so the standard
interference check rejects the join.

**Next step to land it:** an **asserts build** (`dev/run.sh asserts-build`) → `-debug-only=regalloc`
join trace pins the exact `vregX ↔ $rcN` join → write the narrow `shouldCoalesce` refusal → re-verify
`newton`+`lsystem` `-verify` clean **and** corpus disasm byte-identical + torture + fuzz, then drop both
XFAILs and add `dev/run.sh rcundef`. (This Release toolchain has no asserts, so the trace needs that build.)

## Root cause — PINNED (2026-06-29, post-virtregrewriter MIR of `newton_step`)

It is **not** a cosmetic stale-liveins issue — the verifier is **correct**. Exact site (`-Os`, a16):

```
bb.9:   ... JSR __mulsi3 ... implicit-def $rc3      ; last def of $rc3
        renamable $rc24 = COPY $rc3                  ; read (not killed)
bb.10:  liveins: $rc29, ...   (NO $rc3)              ; $rc3 NOT live-in
bb.11:  liveins: $rc29, ...   (NO $rc3)
bb.12:  liveins: $rc29, ...   (NO $rc3)
        renamable $x = COPY killed renamable $rc3    ; <-- USE with NO reaching def
```

The RA **ends `$rc3`'s live range at bb.9** (not propagated into bb.10/11/12's liveins), yet emits a
**use of `$rc3` in bb.12**. There is **no def of `$rc3` reaching that use** on the dataflow — it only
produces the right answer because the physical `$rc3` happens to retain the bb.9 value undisturbed across
bb.10/11 (no intervening reuse). So this is a **disconnected def→use** — a high-pressure **live-range
splitting / spill** of an imaginary-register value where the **reload that should re-define `$rc3` before
the bb.12 use is missing**. It is a **latent miscompile hazard** (if the RA had reused `$rc3` in bb.10/11
it would be a real wrong-answer), which is exactly why the MachineVerifier rejects it — and why the right
fix is at the **RA live-range / spill-reload** level, not a liveins recompute (recomputing liveins can't
add `$rc3` because no def reaches the use). **RA-level change ⇒ miscompile-risk ⇒ must re-verify the corpus
byte-identical + torture + fuzz before trusting it.**

## Diagnosis (path)

- The bad COPY appears **after the Virtual Register Rewriter** (the last `IR Dump After` before the verifier
  aborts is `Virtual Register Rewriter`; the Greedy RA assigns the value, the rewriter materializes the
  physical `$x = COPY $rcN`).
- `$rcN` are **imaginary** registers (zero-page pairs with `sublo`/`subhi` sub-registers, the soft
  accumulator/index spill pool). Hypothesis: a **partial/sub-register def** of the pair (e.g. defining
  `$rcNlsb` / `$rcN.sublo` only, or a def on a sibling path) is not recognised by the verifier's liveness as
  defining the **full** `$rcN` read by the COPY — so the full-pair use looks undefined even though every
  byte is in fact defined at runtime. This is the sub-register-liveness / `implicit-def` tracking corner the
  MOS backend's imaginary-register model has to get exactly right.

## Plan

1. **Minimal repro.** Reduce `newton_sim.c` (or a synthesized high-pressure a16 function) to the smallest
   function that emits `$x = COPY $rcN` with an undefined `$rcN`, surviving `-Os`. Add it as
   `examples/65816/rcundef.c` (a `dev/` differential + `-verify` gate, like `xy16inplace`).
2. **Pin the pass + the missing def.** Dump MIR before/after Greedy RA and the Virtual Register Rewriter;
   identify where `$rcN`'s def is (sub-register? other block? folded into a `LDImag16`/spill?) and why the
   verifier doesn't see it reaching the COPY.
3. **Classify the gap** — one of:
   a. RA/rewriter emits the COPY before/without a corresponding `$rcN` def (a real def-insertion bug);
   b. a sub-register def (`$rcNlsb`) isn't marked as (partially) defining `$rcN`, so the verifier treats the
      super-register read as undefined (a `Register{Info,Bank}`/sub-reg-liveness modelling gap);
   c. an `implicit-def`/`undef` flag is missing on a reload/spill of the imaginary pair.
4. **Fix at the root** in `vendor/llvm-mos/llvm/lib/Target/MOS/` (likely `MOSRegisterInfo`, the
   rewriter/RA glue, or `MOSInstrInfo` copy/spill lowering) on the **`throwaway/rc-undef-fix` compiler
   worktree** (own `vendor/` + warm `build/`). Conservative: a misclassification must only ever add a def /
   mark liveness correctly, never change emitted bytes on the corpus.
5. **Verify.** `newton_sim.c` + `lsystem_sim.c` both `-verify` clean at `-O0/-O1/-Os` (a16 + xy16);
   `dev/run.sh newton` + `dev/run.sh lsystem` still PASS with unchanged hashes (`0x4D8B`/`0x79C3`); corpus
   7/7; xy16 suite; torture; fuzz csmith N×2 (0 mismatch / 0 new crash); the disasm is **byte-identical** on
   the corpus (proving the fix is inert — only adds liveness/def info). Regenerate `0002` (round-trips, 0
   foreign content).
6. **Drop the XFAILs.** Remove `a16-newton-step-rc-undef` from `KNOWN_ISSUES` + both `KNOWN_ISSUE_REPROS`
   rows (newton + any lsystem entry) in `tools/a16_fuzz.py` so a recurrence **hard-FAILs**; add the new
   `dev/run.sh rcundef` `-verify` gate as the regression guard.

## Files (anticipated)

| File | Purpose |
|---|---|
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOS*.cpp` (TBD) | the def-tracking / sub-reg-liveness fix (→ `0002`) |
| `patches/llvm-mos/0002-321-accum16.patch` | regenerated |
| `examples/65816/rcundef.c`, `dev/rcundef.sh` | minimal repro + `-verify` regression gate |
| `tools/a16_fuzz.py` | drop the `rc-undef` KNOWN_ISSUES + REPROS XFAILs |
| `TODO.md` | close the open `a16-newton-step-rc-undef` investigate item |

## Verification steps

1. Minimal repro `-verify`-fails on the current toolchain (a16 + xy16, `-O1`/`-Os`), clean at `-O0`.
2. MIR diagnosis pins the missing-def site + the gap class (a/b/c above).
3. After the fix: repro + `newton_sim.c` + `lsystem_sim.c` all `-verify` clean (a16/xy16, all opt levels).
4. `dev/run.sh newton` (`0x4D8B`) + `dev/run.sh lsystem` (`0x79C3`) PASS, hashes unchanged.
5. Corpus disasm byte-identical (fix is inert); corpus 7/7; xy16 suite; torture; fuzz 0-mismatch.
6. XFAILs dropped; `dev/run.sh rcundef` is green and a recurrence hard-FAILs.

## Risk / scope note

This is a **deep RA / sub-register-liveness** fix in the imaginary-register model — potentially intricate
and uncertain. It is **code-correct already** (verifier false-positive), so the impact of *not* fixing it is
only that `-verify` builds of two demos need an XFAIL. Worth fixing (it blocks the clean `-verify` bar and
is a real modelling gap), but a candidate to **timebox**: if the root cause proves to be a large RA rework,
fall back to the documented XFAIL (newton precedent) and keep this plan as the standing fix-it ticket.
