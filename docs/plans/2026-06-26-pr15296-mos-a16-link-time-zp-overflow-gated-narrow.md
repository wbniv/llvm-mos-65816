# Plan — pr15296 `+mos-a16` link-time ZP overflow: gated narrow-fix spike

## Context

`vendor/c-torture/execute/pr15296.c` (pointer/union/`intptr_t`, register-heavy) builds clean default-8-bit
and at `+mos-a16 -O0`, but **fails at link** under `+mos-a16 -O1/-Os`:

```
ld.lld: error: relocation R_MOS_ADDR8 out of range: 1043 is not in [-128, 255]; references section '.zp.noinit'
```

It is the lone remaining `+mos-a16` register-pressure XFAIL (`KNOWN_ISSUES["a16-zp-pressure-overflow"]` in
`tools/a16_fuzz.py:987-998`), deferred behind a Phase-3 RA-residency rework whose re-open trigger has not
fired (pr15296 is hand-reduced, explicitly *not* a trigger). The user chose to **spike a narrow fix, gated**:
attempt to clear the link overflow at low risk *without* the Phase-3 rework; land only if clean +
regression-safe + default-8-bit byte-identical, else fall back to re-affirming the deferral with evidence.

**Key reframe established during research (this is why a narrow fix is plausible):** the documented root
cause — "`+mos-a16` allocates so many `Imag16` ZP pairs that `.zp.noinit` grows past 256 B" — is
**mechanically refuted by the allocator code**:
- Imaginary registers are hard-capped at 32 bytes (`MOSRegisterInfo.cpp:69-77` reserves `RS16..RS127`);
- `MOSZeroPageAlloc` (the only pass that emits the `.zp.noinit`/`zp_stack` objects) is **capped at
  `ZPAvail`** — the SNES cfg sets `-mlto-zp=224` (`build/install/bin/mos-snes.cfg`), enforced by the
  no-op-if-unset guard (`MOSZeroPageAlloc.cpp:263`), the `assert(ZPAvail <= 256-32)` (`:267`), and the
  over-budget refusals (`:829`, `:841`);
- Frame indices not promoted to ZP stay absolute (`static_stack`, `R_MOS_ADDR16`), and every 16-bit class
  has a working soft-stack spill expansion with an offset≥256 pointer-materialization valve
  (`MOSRegisterInfo.cpp:564-596`).

So a **1043-byte** `.zp.noinit` cannot be intrinsic Imag16 pressure — it's almost certainly a **containable
allocation/accounting defect** (the 224 cap defeated/mis-accounted for pr15296's call-graph shape, or a value
given an 8-bit ZP addressing mode while its storage lives past 256). That makes the fix **lean F1**, makes
F3 (only-the-RA-rework) unlikely, and — because `MOSZeroPageAlloc.cpp` / `MOSStaticStackAlloc.cpp` /
`MOSFrameLowering.cpp` are **pristine upstream** (verified: the only patch mention of `MOSZeroPageAlloc` is
the `initializeMOSZeroPageAllocPass` registration context line, not a body hunk) — makes any fix a
**generic, upstream-worthy llvm-mos bug fix**, not a16-specific machinery.

## Approach — a gated spike on a throwaway worktree

A compiler-changing investigation → **throwaway worktree off `main`**, never the hot shared tree. The fix
(if any) must be **default-8-bit byte-identical** and regression-clean before it lands; otherwise the spike
concludes "F3 → re-affirm the deferral" and disposes of the worktree.

### Step 0 — worktree + warm toolchain (real-copy variant; needs a rebuild)

Per `docs/howto-feature-worktree.md` (real-copy/warm-build, not the hardlink variant — we edit
`vendor/llvm-mos`):
```
SLUG=a16-zp-overflow-spike; MAIN=/home/will/SRC/llvm-mos-65816; WT="$MAIN-$SLUG"
git -C "$MAIN" worktree add -b throwaway/$SLUG "$WT" main
cp -a  "$MAIN/vendor/llvm-mos" "$MAIN/vendor/llvm-mos-sdk" "$WT/vendor/"   # editable
cp -a  "$MAIN/build" "$WT/build"                                          # warm cmake + ccache
cp -al "$MAIN/vendor/bsnes-jg" "$WT/dev/roms" "$WT/"... (per the howto)
cd "$WT" && dev/run.sh corpus    # 7/7 sanity on the warm toolchain
```
Register the worktree in `docs/agent-handoff.md`'s Active table while live. Step 1's `-debug-only` trace
needs an **asserts** build (`dev/run.sh asserts-build`, reusing `build/.ccache`); run the final gate with the
**release** toolchain the corpora/fuzzer assume. After every rebuild, confirm `clang-23` mtime advanced
(stale build silently serves old codegen — the canonical gotcha).

### Step 1 (GATING) — empirical diagnosis: what is at offset 1043?

Everything branches on this; it is non-optional and gates Step 2. All read-only inspection of the failing
`+mos-a16 -Os` link of pr15296:
1. Confirm `-zp-avail=224` actually reaches the link line (`mos-clang … -###`) — rule out a config/driver
   surprise (the cheapest possible resolution).
2. `llvm-readelf -S` / the `-Wl,-Map` file: is `.zp.noinit` genuinely >1043 B, or is it small with a large
   reloc **addend**?
3. `llvm-objdump -dr` / `-Wl,--no-relax`: identify the symbol the out-of-range `R_MOS_ADDR8` targets —
   `zp_stack`/`*_zp_stk` (MOSZeroPageAlloc promotion), an absolute `static_stack`/`*_sstk` (→ a
   wrong-addressing-mode bug), a CSR ZP slot, or a user/runtime `.zp` object.
4. Rebuild-link with `-Wl,-mllvm,-debug-only=mos-zero-page-alloc` (asserts toolchain) and read the "Enacting
   assignments" dump (`MOSZeroPageAlloc.cpp:341-402`). **Compare the pass-believed `zp_stack` size against the
   linker's laid-out size** — a gap is the smoking gun for the call-graph accounting (`:799-891`) undercounting
   for pr15296's shape.

**Classify from Step 1:**
| Finding | Class |
|---|---|
| Reloc → `zp_stack`; pass-believed ≤224 but laid-out >256 (accounting gap), or the cap simply isn't enforced for this call-graph shape | **F1** |
| Reloc → an *absolute* symbol emitted with an 8-bit ZP reloc (a value forced into ZP addressing with no absolute fallback for that op) | **F2** |
| `zp_stack` legitimately needs >224 B for **correctness** with no degradable candidate | **F3** (architecturally unlikely) |

### Step 2 — the fix (branch on Step 1)

- **F1 — repair/enforce the ZP budget so the excess degrades to absolute.** Locus: `MOSZeroPageAlloc.cpp`.
  Either **(F1a)** correct the specific call-graph accounting term the Step-1 trace pinpoints
  (`NewZPSize`/`MaxZPSize`/`ZPOffset`, `:799-891`) so the `:841` guard reflects true laid-out extent, or
  **(F1b)** add a belt-and-suspenders check in the *enact* loop (`:341-401`): before
  `setStackID(…, MosZeroPage)` (`:397`) verify `ZPOffset + Offset + Size <= ModuleZPAvail`, else skip the
  promotion (the FI stays absolute `static_stack`). F1b is provably default-safe — it can only *remove* a
  promotion that wouldn't fit, and no current corpus reaches 224 B, so default-8-bit is untouched.
- **F2 — restore the absolute fallback for the forced-ZP op.** Locus: `MOSRegisterInfo.cpp`
  `eliminateFrameIndex` (`:412-424`) / the offending op's selection — relax it to the 16-bit absolute form
  (`R_MOS_ADDR16`) when its slot is `MosStatic`, mirroring the existing offset≥256 valve (`:564-596`). Gate
  on `hasAccum16()` only if the op is genuinely a16-specific.
- **F3 — no-go:** go to the no-go branch below.

### Step 3 — differential gate (rebuild, then verify from the worktree)

`dev/run.sh toolchain` (incremental; confirm `clang-23` mtime advanced), then:
- **(a) DEFAULT 8-bit byte-identical — the critical safety property.** The fix sits in generic (non-a16-gated)
  code, so prove default codegen is unchanged: compile every `examples/snes/corpus/*.c` + in-scope c-torture
  **without** `+mos-a16` with the stock-`main` vs fixed toolchain and `sha256sum`/`cmp` each pair. Any diff →
  narrow to F1b (cannot fire below 224) or add `hasAccum16()` gating. Identical = proven default-safe.
- **(b) Regression-clean:** `dev/run.sh corpus` (7/7); `corpus-a16` (host==default==+mos-a16); `torture --opt
  -Os` and `--opt -O1` pass-counts **non-regressing** on MAME + bsnes-jg; `fuzz 200 1` 0-mismatch/0-crash.
- **(c) pr15296 links clean AND runs correct:** both `-O1` and `-Os` link without the `R_MOS_ADDR8` error, and
  `host == default == +mos-a16 == +mos-xy16` on both emulators (it already runs through `tools/torture_run.py`).

### Step 4 — go / no-go

**GO** iff: (1) default objects byte-identical pre/post; (2) corpus 7/7 + corpus-a16 clean + torture
non-regressing both emulators + fuzz 0-mismatch; (3) pr15296 links + runs correct at `-O1` *and* `-Os`;
(4) the change is minimal/localized to the diagnosed locus with **no** `shouldCoalesce`/RA-residency rework
(if it needs that, it is F3 by definition → NO-GO).

### Step 5 — branches

**On GO:**
- **Patch:** if the fix is in `MOSZeroPageAlloc.cpp` (pristine, generic) → a **new standalone**
  `patches/llvm-mos/0013-mos-zp-alloc-budget-fix.patch` + a `dev/regen-patch-0013.sh` modeled on
  `dev/regen-patch-0011.sh` (baseline = pristine + `0001..0012`, diff restricted to the touched file,
  round-trip-verified). **Do not fold into `0002`/`0009`.** If F2 lands in `MOSRegisterInfo.cpp` and is
  `hasAccum16()`-gated, regenerate `0002` via `dev/regen-patch.sh`.
- **Flip the gate:** drop `KNOWN_ISSUES["a16-zp-pressure-overflow"]` (`tools/a16_fuzz.py:987-998`, its own
  comment mandates removal so the signature hard-FAILs on regression) + the `torture_run.py` classification;
  pr15296 becomes a hard PASS at `-O1/-Os`.
- **Docs:** correct the refuted "Imag16-saturation" mechanism in
  `docs/investigations/65816-a16-regalloc-pressure-failure.md` (§ Related manifestation, ~`:154-171`) with the
  real cause + §RESOLUTION; drop the "lone remaining XFAIL" line in `docs/implementation-status.md:50`; close
  the bullet in `TODO.md`; note in `docs/plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md`
  that pr15296 no longer motivates Phase 3 (orthogonal fix, like `0009`/`0011`).
- **Upstream:** if F1 (generic, default-reproducible with ≥256 B of promotable candidates), add a
  ready-to-post row to `docs/upstream-contribution-status.md` — this is **upstream-standalone-testable**
  (unlike the AS2 fixes); draft the reduced default-8-bit repro.
- **Teardown:** merge durable artifacts to `main`, then `dev/worktree-teardown.sh throwaway/$SLUG --yes`.

**On NO-GO (F3):** run `dev/measure-zp-pressure.sh` over the corpus, confirm real code stays well under the
~10/14-pair trigger, record dated evidence; **keep** the XFAIL; update the investigation doc with the spike's
**negative finding + the corrected mechanism** (so the next attempt doesn't re-chase the refuted framing);
re-affirm that hand-reduced pr15296 does not itself fire the Phase-3 trigger; teardown the worktree.

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSZeroPageAlloc.cpp` — cap (`:263/:267/:829/:841`), call-graph
  accounting (`:799-891`), enact loop (`:341-402`) — **primary F1 locus, pristine upstream**
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` — imag-reg reservation (`:69-77`),
  `eliminateFrameIndex` (`:412-424`), spill fallback valve (`:564-596`) — **F2 locus**
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSFrameLowering.cpp` — static-stack (absolute) fallback (`:248-260`)
- `tools/a16_fuzz.py` (`:987-998`) + `tools/torture_run.py` — XFAIL gate flip on success
- `docs/investigations/65816-a16-regalloc-pressure-failure.md` (`:154-171`) — mechanism correction (either branch)
- `dev/regen-patch-0011.sh` — template for a standalone `0013`; `dev/measure-zp-pressure.sh` — no-go evidence

## Verification (summary)

The differential gate of Step 3 is the spec: **default-8-bit byte-identical** (the headline safety proof),
corpus 7/7, corpus-a16 clean, c-torture `-O1`/`-Os` non-regressing on MAME + bsnes-jg, fuzzer 0-mismatch, and
**pr15296 links + runs correct at `-O1` and `-Os` on both emulators**. The go/no-go in Step 4 gates the land.

## Risks

- **Default-8-bit regression** is the headline risk (fix in generic code). Proof obligation: the Step-3a
  byte-diff. Mitigation if it fires: narrow to the F1b enact-guard (cannot fire below 224 B) or add
  `hasAccum16()` gating.
- **Demoting a hot a16 value to absolute** (slower) — caught by corpus-a16 + fuzz + the `a16*` micro-gates +
  `dev/measure-a16-threading.sh`; the cap only demotes the overflow that couldn't be placed anyway.
- **Mis-locating the defect** — Step 1's pass-belief-vs-linker-layout comparison is the guard; it directly
  distinguishes F1a / F1b / F2 / F3 before any edit.
- **Asserts vs release divergence** — diagnose with asserts, gate with release.
