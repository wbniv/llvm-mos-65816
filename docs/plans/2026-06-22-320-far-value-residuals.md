<!-- HISTORY: snapshots in docs/plans/.history/ (regen-md-history hook). -->

# #320 far-value residuals — the dp→near (DP-arg) upstream crash + default-8-bit far-ptr storage (a16-gated by design)

**Status:** PLANNED (2026-06-22) · **Issue:** #320, ROADMAP M1 · **Type:** close-out, two parts.
**(A)** draft + queue an **upstream issue** for the dp→near crash (no fork patch; posting user-triggered).
**(B)** confirm default-8-bit far-ptr storage is **a16-gated by design**, record the evidence, **close** it.
**No `0002` / codegen change in either part.**

This plan closes the two **Residuals** bullets on the M1 *#320 far-pointer DATA-VALUE type* TODO item. The
desirable far-value work (store/load/array/struct a far pointer, `sizeof==4`, far→near cast) was **built by
the F2 agent and landed on `main`** (`0001` + `0004` + `0005`), verified under `+mos-a16`. What's left are
the two things that were explicitly *out* of that scope:

> **(a)** `dp→near` cast = pre-existing UPSTREAM bug ("Copy Instruction illegal with mismatching sizes",
> crashes w/o `-verify`) → an upstream issue to draft, not a fork fix.
> **(b)** far-ptr storage under default 8-bit is still un-legalized (a16-gated by design — likely fine).

Evidence harness for both: [`dev/measure-far-ptr-value-state.sh`](../../dev/measure-far-ptr-value-state.sh)
over the committed fixtures in
[`examples/65816/far-value-evidence/`](../../examples/65816/far-value-evidence/).

---

## The two residuals, measured (2026-06-22, this turn)

### A — "dp→near" is actually a DP-pointer-**argument** upstream crash

The fixture `c2_dp_to_near.c` is `char d(char DP *p){ return *(char*)p; }` with
`DP = __attribute__((address_space(1)))`. Reduction probe (plain `mos6502`, `-verify-machineinstrs`,
this turn) shows the dp→near *cast* is incidental — **the trigger is the DP pointer argument itself**:

| probe | result |
|-------|--------|
| `char d(char DP *p){ return *p; }`  *(DP arg, deref, no cast)* | **FAIL** |
| `char d(char DP *p){ return *(char*)p; }`  *(the c2 fixture)* | **FAIL** |
| `int  d(char DP *p){ return (int)(__INTPTR_TYPE__)p; }`  *(DP arg, no deref)* | **FAIL** |
| `char d(void){ static char DP *p; return *p; }`  *(DP **local**, not arg)* | OK |
| `char d(char *p){ return *p; }`  *(near arg — control)* | OK |

**Root cause (visible in the IRTranslator MIR).** A DP (`addrspace(1)`) pointer is **8-bit** (datalayout
`p1:8:8`), but the MOS calling convention passes the pointer argument in a **16-bit `RS` register pair**, so
arg materialization emits a size-mismatched physical-register copy:

```
%0:_(p1) = COPY $rs1                    ; <-- illegal: Def Size = 8, Src Size = 16
%1:_(p0) = G_ADDRSPACE_CAST %0:_(p1)
%2:_(s8) = G_LOAD %1:_(p0)
$a = COPY %2:_(s8)
RTS implicit $a
```

**Three faces of the same defect** (all on plain `mos6502 -Os`, no 65816, no `+mos-a16`):

- **`-verify-machineinstrs` (release):** `*** Bad machine code: Copy Instruction is illegal with mismatching
  sizes ***` … `instruction: %0:_(p1) = COPY $rs1` / `Def Size = 8, Src Size = 16` →
  `fatal error: Found 1 machine code errors.`
- **asserts build, no `-verify`:** `Unexpected physical register copy.` →
  `UNREACHABLE executed at vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp:1146` — inside
  `MOSRegisterInfo::copyCost` → `getRegAllocationHints`, i.e. it aborts during **register allocation**
  (`RAGreedy`), not codegen.
- **release build, no `-verify`:** SIGSEGV in `MOSLateOptimization::runOnMachineFunction` (the illegal copy
  survives to a later pass that dereferences a class it can't reconcile).

**It is pristine upstream, not our fork.** Stock `llvm-mos/llvm-mos` already carries `p1:8:8` in its MOS
datalayout (`gh api .../MOSTargetMachine.cpp` → `e-m:e-p:16:8-p1:8:8-…`); our `0001-320-far-addrspace.patch`
only **adds** `p2:32:8` (the far space). The DP space, the calling convention, and the
`MOSRegisterInfo.cpp:1146` abort site are all upstream. The repro needs **no** `+mos-a16` and **no**
`mosw65816` — it fires on the base 6502 target. ⇒ **upstream issue, not a fork fix.**

> Note: `c1_far_to_near.c` (far→near, `addrspace(2)`) also asserts, but in `CallLowering::buildCopyFromRegs`
> on our **fork's** 32-bit far pointer — that is *not* this upstream bug and is **out of scope** here (it's
> part of the far-value-type completion, already tracked under the M1 item). Part A is **only** the DP
> (`addrspace(1)`) argument crash.

### B — default-8-bit far-ptr storage is un-legalized (by design)

The far-value machinery the F2 agent built — listing `PF` as a storable value type, the `4×s8 ↔ s32` byte
bridge in `MOSLegalizerInfo` (`0005`) — is **gated behind `+mos-a16`** (a far pointer is a 32-bit value;
manipulating it as bytes is what 16-bit-accumulator codegen is for). Under **default 8-bit**, storing or
loading a far pointer is therefore **not legalized**:

- `s1_store_far_global.c` (`G_STORE p2`) → `verify-FAIL`
- `s2/s3/s4` (load / array / struct, `G_LOAD p2`) → `unable to legalize … G_LOAD … (p2)` (clean fatal
  compile error)

This is the intended posture: **far pointers are a 65816 / banking capability; a program that stores them is
already in `+mos-a16` territory.** A default-8-bit-only program has no reason to hold a 32-bit far pointer as
a value. The residual question to **close** is the safety property — that the default-8-bit path produces a
**clean compile-time diagnostic, never a silent miscompile** — plus a one-time check that there is no
realistic 8-bit-only use case being foreclosed.

> ⚠ **Local-toolchain caveat.** The checked-in `build/llvm-mos-install` is the **pre-F2** toolchain
> (`clang … c798c31…`); on it `s1`–`s4` fail under **both** columns because `0005` isn't built in. To
> measure the *current* (post-F2) residual — "OK under `+mos-a16`, fails only default-8-bit" — Part B must
> run against a **current-`main`** toolchain (rebuild, or the retained `wt/320-far-followups` /
> `wt/320-packed24-incB` install). Part A is unaffected: the DP bug is upstream and reproduces on the
> pre-F2 build exactly as above.

---

## Goal / non-goals

**Goal.** (A) File a high-quality, still-live upstream issue for the DP-pointer-argument calling-convention
crash, with a 2-line minimal repro that a maintainer can trigger on a stock build (no fork features), and
wire the tracking so the queue reflects it. (B) Confirm the default-8-bit far-storage gap is by-design and
safe (clean diagnostic, no miscompile, no real 8-bit use case), record the verdict, and close the bullet.

**Non-goals (established position — do not expand).**
- **No fork-side fix for the DP crash, and no fix PR.** Fixing the DP-argument calling convention (give
  `addrspace(1)` an 8-bit arg slot, or widen the DP pointer's register handling) is a change to the generic
  MOS CC across all subtargets — **maintainer territory**, like the scavenger N/Z issue. We file, we don't
  patch. (And the DP space is not even exercised by #320/#321 codegen — far is `addrspace(2)`.)
- **No legalization of default-8-bit far storage.** It is a16-gated by design (Part B's job is to *confirm
  and record* that, not to remove the gate). If Part B finds the 8-bit diagnostic is *ugly* (a crash rather
  than a clean error), the most we'd consider is a friendlier compile-time rejection — gate/defer that as a
  separate polish item; it does **not** block the close.
- **No `0002` / codegen change in this plan.** Docs, tracking, and at most a tracked repro `.c` + harness.

---

## Worktree discipline

This is **measurement + drafting**, and the repros are already minimal (Part A is 2 lines, captured this
turn; Part B is the existing fixtures). No `vendor/` or `0002` edits → **no compiler worktree needed.**

- **Part A** confirmation (asserts backtrace, upstream-still-live check) is **read-only host-side** compiles
  to `/dev/null` — fine on `main`'s working copy (no tree dirtying). The repro needs no cvise.
- **Part B** needs a **post-F2 toolchain**. Prefer reusing the retained `wt/320-far-followups` install over a
  fresh rebuild; if neither is current, `dev/run.sh toolchain` on `main` rebuilds it (F2 is landed in
  `0001`/`0004`/`0005`). A rebuild is not an investigation — no throwaway branch required.

Writing this plan, the issue body, and the doc/TODO edits happen on `main` as normal plan-first work.

---

## Part A — file the DP-argument upstream issue

1. **Search upstream first — don't file a dup.** Look for an existing issue covering the DP / `addrspace(1)`
   argument crash before drafting:
   ```
   gh search issues --repo llvm-mos/llvm-mos "address space" "calling convention" --state all
   gh search issues --repo llvm-mos/llvm-mos "mismatching sizes" COPY --state all
   ```
   If one already covers it → record its URL, skip the draft, just cross-link from our TODO/status and
   **stop**. Otherwise continue.

2. **Pre-flight: bug still live HERE.** Re-confirm all three faces on the current pin so we file something
   real (commands as run this turn; capture fresh output for the issue body):
   ```
   CLANG=build/llvm-mos-install/bin/mos-clang
   F=examples/65816/far-value-evidence/c2_dp_to_near.c
   # release + -verify  → "Copy Instruction is illegal with mismatching sizes"
   $CLANG --target=mos -mcpu=mos6502 -Os -std=c23 -mllvm -verify-machineinstrs -c $F -o /dev/null
   # release, no -verify → SIGSEGV in MOSLateOptimization
   $CLANG --target=mos -mcpu=mos6502 -Os -std=c23 -c $F -o /dev/null
   # asserts, no -verify → UNREACHABLE MOSRegisterInfo.cpp:1146 "Unexpected physical register copy"
   build/llvm-mos-asserts-install/bin/mos-clang --target=mos -mcpu=mos6502 -Os -std=c23 -c $F -o /dev/null
   ```
   Confirm source still pristine-upstream: `grep -c 'p1:8:8' patches/llvm-mos/0001-320-far-addrspace.patch`
   shows `0001` only touches the `p2:32:8` addition, and the `MOSRegisterInfo.cpp:1146` UNREACHABLE +
   `copyCost` are absent from `0002`–`0007`.

3. **Pre-flight: bug still live UPSTREAM** (the issue targets `llvm-mos/llvm-mos` main, which may have
   moved). Confirm `p1:8:8` is still in the upstream datalayout and the `copyCost`/`Unexpected physical
   register copy` site still exists:
   ```
   gh api repos/llvm-mos/llvm-mos/contents/llvm/lib/Target/MOS/MOSTargetMachine.cpp \
     --jq '.content' | base64 -d | grep -n 'p1:8:8'
   gh api repos/llvm-mos/llvm-mos/contents/llvm/lib/Target/MOS/MOSRegisterInfo.cpp \
     --jq '.content' | base64 -d | grep -n 'Unexpected physical register copy'
   ```
   Still present → file. Gone/changed → **STOP**, record the upstream SHA/line, note any issue/PR that may
   have fixed it; do **not** post.

4. **Lock the minimal repro.** Use the reduced 2-line form (sharper than the c2 fixture — no cast needed):
   ```c
   #define DP __attribute__((address_space(1)))
   char d(char DP *p){ return *p; }   // 8-bit addrspace(1) ptr arg → illegal (p1)=COPY $rs
   ```
   This is the issue's primary `## Reproduce`. (Keep `c2_dp_to_near.c` as the in-repo evidence fixture; it
   already lives under `far-value-evidence/` and is exercised by `measure-far-ptr-value-state.sh`.)

5. **Draft the issue body** → `docs/320-upstream-dp-arg-cc-issue.md` (mirror the structure of
   [`docs/321-upstream-scavenger-nz-issue.md`](../321-upstream-scavenger-nz-issue.md)):
   - **Title:** *"[MOS] Calling convention passes an `addrspace(1)` (8-bit direct-page) pointer argument in a
     16-bit register → illegal size-mismatched COPY (`Def Size = 8, Src Size = 16`)"*.
   - **Summary / crux:** the MOS CC materializes a DP pointer arg into a 16-bit `RS` reg, but `p1:8:8` makes
     the pointer 8-bit; the resulting `%vreg(p1) = COPY $rs` is size-mismatched.
   - **Reproduce:** the 2-line C above + the exact `mos-clang --target=mos -mcpu=mos6502 -Os` command (no
     fork features). Note it is **independent of `+mos-a16`/`mosw65816`** — base 6502 target.
   - **Three faces:** the `-verify` rejection (with the MIR snippet), the asserts `UNREACHABLE
     MOSRegisterInfo.cpp:1146` backtrace (RA `copyCost` path), and the no-verify release SIGSEGV in
     `MOSLateOptimization`. Use the fresh Step-2 output.
   - **Likely fix directions** (maintainer-facing): give `addrspace(1)` an 8-bit argument slot in the MOS
     CC, or coerce/truncate at arg materialization so the `(p1)` vreg is fed an 8-bit value — leave the
     choice to the maintainer.
   - **Note:** the reporter's fork (`+mos-a16`, far `addrspace(2)`) does **not** use the DP space, so this is
     reported as a generic upstream defect, not a fork-blocker.

6. **Queue it in `docs/upstream-contribution-status.md`** — add a new *Ready to post now* item (next number)
   mirroring item 4's format: the one-line description, the `--body-file docs/320-upstream-dp-arg-cc-issue.md`
   path, the exact `gh issue create` command, and bump the TL;DR count (`2 PRs + 2 issues …` → `… 3 issues`).

7. **Post (USER-TRIGGERED — do not auto-run).** On the user's go, strip any leading status comment, then:
   ```
   gh issue create --repo llvm-mos/llvm-mos \
     --title "[MOS] Calling convention passes an addrspace(1) (8-bit direct-page) pointer argument in a 16-bit register — illegal size-mismatched COPY" \
     --body-file docs/320-upstream-dp-arg-cc-issue.md
   ```
   Capture the returned **issue number + URL**.

8. **Same-turn bookkeeping after posting:**
   - `docs/upstream-contribution-status.md`: move the new item to a posted state (record `#NNN` + URL +
     date); update the TL;DR and *Verified state* counts.
   - `TODO.md`: add/flip the Upstream/Contribution item to `[x]` with the issue link.
   - The M1 *#320 far-pointer DATA-VALUE* item: replace residual (a)'s "→ an upstream issue to draft" with
     "→ filed upstream #NNN" + the link.

---

## Part B — close default-8-bit far storage as a16-gated-by-design

1. **Get a post-F2 toolchain.** Use the retained `wt/320-far-followups` install if current, else
   `dev/run.sh toolchain` on `main`. Sanity: `s1_store_far_global.c` under `+mos-a16` must now be **OK**
   (proves F2's `0005` is in the build) — otherwise the toolchain is stale and Part B's verdict is invalid.

2. **Re-measure the residual** against that toolchain:
   ```
   CLANG=<post-F2 mos-clang> bash dev/measure-far-ptr-value-state.sh
   ```
   Expected post-F2 shape: `s1`–`s4` / `c1` / `z1` **OK under `+mos-a16`**, and the **default** column still
   `verify-FAIL` / `no-legalize`. That split *is* the "a16-gated by design" residual.

3. **Confirm the safety property — clean error, never a silent miscompile.** For each default-8-bit far
   storage fixture, check the **no-`-verify`** behavior:
   ```
   for f in s1_store_far_global s2_load_far_global s3_array_far s4_struct_far; do
     <post-F2 clang> --target=mos -mcpu=mosw65816 -Os -std=c23 \
       -c examples/65816/far-value-evidence/$f.c -o /dev/null; echo "$f exit=$?"
   done
   ```
   - `no-legalize` cases (`s2`/`s3`/`s4`) already abort with a clean `fatal error: unable to legalize` — a
     **compile-time rejection**, which is the safe outcome. Record it.
   - For `s1` (the `G_STORE p2` *verify-FAIL* case): determine whether, **without** `-verify`, it (i) still
     errors cleanly, or (ii) crashes / would miscompile. If (i) → safe, record and close. If (ii) → note it
     as the *same class* as the Part-A DP crash (an un-legalized op surviving to a later pass), but still
     a16-gated-by-design; capture it as a **separate, low-priority** "friendlier 8-bit far-store diagnostic"
     follow-up — do **not** let it block the close (no realistic 8-bit-only program stores a far pointer).

4. **One-time use-case check.** Confirm no realistic default-8-bit-only path wants far-pointer storage: far
   pointers exist to address >64 KB across banks, which is a 65816 capability, and any program using them is
   built `+mos-a16`. Record this as the rationale (mirror the zero-bank/AS4 "dominated, null by worth"
   close-out style — a measured/argued verdict, not a deferral).

5. **Record the verdict + close.** Write the by-design conclusion into the M1 *#320 far-pointer DATA-VALUE*
   TODO item (residual (b) → "**closed: a16-gated by design** — storage works under `+mos-a16` (F2);
   default-8-bit is a clean compile-time rejection; no 8-bit-only use case; evidence
   `dev/measure-far-ptr-value-state.sh`"), and append a one-line note to the
   `far-value-evidence/README.md` "Reading" section so the fixture table reflects the post-F2 reality (the
   table is the pre-F2 snapshot). No fork patch. Per *close-net-negative-findings-not-defer*: this is an
   answer ("don't legalize 8-bit far storage"), not backlog.

---

## Outcome (executed 2026-06-22)

**Part A — DONE (drafted + queued; posting user-triggered).** No dup upstream; the crash root-caused to
`MOSCallingConv.td:65` `CCIfPtr<CCAssignToReg<[RS1..RS7]>>` (= `CCIf<"ArgFlags.isPointer()">`,
address-space-blind) assigning the 8-bit `addrspace(1)` pointer arg a 16-bit `RS` home. Issue body
`docs/320-upstream-dp-arg-cc-issue.md`; queued as item 8 in `docs/upstream-contribution-status.md`. Fix
direction uses the real `CCIfPtrAddrSpace<AS,…>` LLVM class (verified to exist).

**Part B — DONE (closed, a16-gated by design).** Method deviated from Steps B.1–B.2 for a real reason and
reached a stronger conclusion:

- **The plan's post-F2-rebuild path was blocked.** Both retained worktree installs are gone, and `vendor/`
  is a *stale shared partial* — a `c798c31` clone with the backend patches applied as working-tree edits but
  **missing `0005`** (MOSLegalizerInfo.cpp:378 is the pre-F2 `{S8, S16, PZ, P}` form). It can't be safely
  re-cloned (would destroy any concurrent worker's edits) and a from-scratch Docker LLVM rebuild is
  disproportionate for a no-code-change by-design close.
- **The verdict is `0005`-invariant, so the rebuild is unnecessary.** A far pointer is a **32-bit value**;
  moving it to/from memory bytes needs the `s32↔bytes` bridge (`G_MERGE/G_UNMERGE {S32,S8}`), which is
  **entirely `hasAccum16`-gated** (MOSLegalizerInfo.cpp:152–169 — `B.unsupported()` in the `else`). `0005`
  only adds `PF` to the `{G_LOAD,G_STORE}` *custom* set, which under 8-bit reroutes the failure from
  "`unable to legalize G_STORE (p2)`" (pre-`0005`) to "`unable to legalize` the downstream `s32` merge/store"
  (post-`0005`) — **same kind** (a clean Legalizer `report_fatal_error`), different named instruction. I
  measured the post-`0005` constituent ops directly on the pre-F2 build: `ptrtoint PF→s32` is legal (line
  134, ungated) and a plain `uint32_t` store/load is fine under 8-bit, **but** reconstructing/decomposing a
  far pointer's `s32` to/from bytes fails cleanly (`unable to legalize G_MERGE_VALUES {S8,S32}` /
  `G_UNMERGE` at the Legalizer). The `+mos-a16` *win* half (`s1`–`s4`/`z1`/`c1` OK) is the F2 agent's
  recorded verification (`wt/320-far-followups`, 2026-06-21).
- **Safety confirmed:** all four real fixtures under default 8-bit (no `-verify`) abort at the Legalizer
  with `unable to legalize` and **emit no object** — a deterministic compile-time rejection, not a
  miscompile, and categorically unlike the dp→near crash (which *survives* the legalizer as a legal-looking
  illegal COPY and SIGSEGVs in `MOSLateOptimization`). No realistic 8-bit-only use case (far pointers ⇒
  banking ⇒ 65816 ⇒ `+mos-a16`). **Closed by design; no fork fix.**

## Verification

1. **DP-arg crash reproduces upstream-clean (Part A core claim).** `c2_dp_to_near.c` and the 2-line repro
   both FAIL on plain `mos6502 -Os -verify-machineinstrs` with "Copy Instruction is illegal with mismatching
   sizes / Def Size = 8, Src Size = 16"; the DP-**local** and near-arg controls pass.

   ```
   # 2-line repro, plain mos6502 -Os -verify-machineinstrs:
   # After IRTranslator
   bb.1 (%ir-block.1):
     liveins: $rs1
     %0:_(p1) = COPY $rs1
     %1:_(s8) = G_LOAD %0:_(p1) :: (load (s8) from %ir.0, addrspace 1)
   *** Bad machine code: Copy Instruction is illegal with mismatching sizes ***
   - instruction: %0:_(p1) = COPY $rs1
   Def Size = 8, Src Size = 16
   fatal error: error in backend: Found 1 machine code errors.

   # reduction probe (plain mos6502 -verify):
   #   char d(char DP *p){ return *p; }            FAIL    (DP arg, no cast)
   #   int  d(char DP *p){ return (int)(intptr)p;} FAIL    (DP arg, no deref)
   #   char d(void){ static char DP *p; return *p;} OK     (DP local, not arg)
   #   char d(char *p){ return *p; }               OK      (near arg — control)
   ```
   **PASS** — the trigger is the `addrspace(1)` pointer *argument*; the dp→near cast is incidental.

2. **It's upstream, not fork.** `0001` only adds `p2:32:8` (DP `p1:8:8` is stock); `gh api` confirms
   `p1:8:8` and the `MOSRegisterInfo.cpp` "Unexpected physical register copy" site still present upstream.

   ```
   # upstream MOSTargetMachine.cpp:76 : e-m:e-p:16:8-p1:8:8-i16:8-...           (p1:8:8 is stock)
   # upstream MOSRegisterInfo.cpp:1059: llvm_unreachable("Unexpected physical register copy.");
   # upstream MOSCallingConv.td:65     : CCIfPtr<CCAssignToReg<[RS1..RS7]>>,
   # upstream HEAD == our pin c798c31 (2026-04-23) → bug is live upstream.
   # asserts build (ours): UNREACHABLE MOSRegisterInfo.cpp:1146 (copyCost → RAGreedy)
   # release no-verify (ours): SIGSEGV in MOSLateOptimization
   # grep -c copyCost/'Unexpected physical register copy' in 0002-0007 patches = 0
   ```
   **PASS** — base `mos6502`, no fork features; crash site & datalayout are pristine upstream.

3. **Issue artifacts exist + queued.** `docs/320-upstream-dp-arg-cc-issue.md` written; a new *Ready to post
   now* item (#8) with the exact `gh issue create` in `docs/upstream-contribution-status.md`; TL;DR bumped
   (`2 issues` → `3 issues`, `seven` → `eight`).

   **PASS** — both files written; no dup found (`gh search issues` → only the broad #320/#32 meta-issues).

4. **Part B split (a16 OK / 8-bit FAIL) + the `s32↔bytes` bridge is a16-gated.** The `+mos-a16` win half is
   F2-recorded (`s1`–`s4`/`z1`/`c1` OK on `wt/320-far-followups`, 2026-06-21). The 8-bit-fail half is
   measured here; the bridge gating is source-verified.

   ```
   # MOSLegalizerInfo.cpp:152-169 — the ONLY s32<->bytes (un)merge, fully under hasAccum16:
   if (STI.hasAccum16())  B.legalFor({{S32,S16}}).customFor({{S32,S8}});
   B.unsupported();                                  # <- else: no s32 path at all
   if (STI.hasAccum16())  B.legalFor({{S16,S32}}).customFor({{S8,S32}});
   B.unsupported();
   # anchor (pre-F2 build, default 8-bit):
   #   uint32_t store / load            OK   (plain i32 mem ops work on 6502)
   #   far-ptr value -> s32 -> bytes    FAIL "unable to legalize G_MERGE/G_UNMERGE {S8,S32}" @ Legalizer
   ```
   **PASS** — 8-bit far storage is un-legalized because the 32-bit far value's byte bridge is a16-only;
   the verdict is `0005`-invariant (see Outcome). Exact post-`0005` instruction not re-measured by rebuild
   (vendor stale; rebuild disproportionate) — established by measured equivalents + source.

5. **Default-8-bit far storage is a clean compile-time rejection (no miscompile).** Each `s*` fixture
   without `-verify` aborts at the Legalizer with `unable to legalize`; none emits an object file.

   ```
   s1_store_far_global   unable to legalize: G_STORE %0:_     | Running pass 'Legalizer' | no object
   s2_load_far_global    unable to legalize: %0:_ = G_LOAD…   | Running pass 'Legalizer' | no object
   s3_array_far          unable to legalize: %8:_ = G_LOAD…   | Running pass 'Legalizer' | no object
   s4_struct_far         unable to legalize: %1:_ = G_LOAD…   | Running pass 'Legalizer' | no object
   ```
   **PASS** — deterministic Legalizer rejection, no object, no crash; unlike the dp→near (Part A) crash that
   survives to `MOSLateOptimization`.

6. **Bullets closed.** M1 TODO item: residual (a) → upstream issue drafted+queued (Upstream/Contribution
   item, posting user-triggered); residual (b) → "closed: a16-gated by design" with evidence pointer.
   `far-value-evidence/README.md` Reading note added.

   **PASS** — see Bookkeeping below (TODO + README edited this turn).

---

## Bookkeeping (same-turn discipline)

- **TODO.md** — Upstream/Contribution: add **"File the DP-pointer-argument calling-convention upstream
  issue"** (user-triggered; issue, not a PR), pointing to this plan + `docs/320-upstream-dp-arg-cc-issue.md`.
  M1 item: update residual (a) (→ filed/queued) and residual (b) (→ closed by-design) in place.
- **docs/upstream-contribution-status.md** — the new issue item (drafted → ready-to-post; → posted after
  user go), TL;DR + *Verified state* counts in sync.
- **docs/320-upstream-far-pointer-note.md** — if it enumerates far-value gaps, cross-link the DP-arg issue
  and note the default-8-bit storage by-design close.
- **far-value-evidence/README.md** — one-line note that the table is the pre-F2 snapshot; post-F2, `s*`/`c1`/
  `z1` pass under `+mos-a16`, and `c2` (DP-arg) is filed upstream.
- Commit only this plan + the docs/TODO edits (and, if Part B.3 yields one, a tracked repro/harness). Never
  stage `vendor/`, a foreign patch, or `docs/transcripts/`.
