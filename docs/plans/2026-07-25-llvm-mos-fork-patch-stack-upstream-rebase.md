# llvm-mos fork patch-stack — upstream rebase + bootstrap-path fix

## Context

Triggered by trying to publish the already-gate-green `#102 cpu6502` SNES demo
([`docs/plans/2026-07-02-102-snes-cpu6502.md`](2026-07-02-102-snes-cpu6502.md)) to biohack.net. This
checkout (`/home/will/llvm-mos-65816`) has never had a built toolchain — `build/` and `vendor/` were both
empty — so publishing required a from-scratch `dev/run.sh toolchain` run, which exercises
`dev/toolchain.sh`'s `git clone` + `git apply patches/llvm-mos/*.patch` bootstrap path. That path failed.

## Root causes (two, independent)

1. **Upstream drift (expected, and good news):** two of our own upstream contributions have been
   **merged** into `llvm-mos/main` since this stack was last exercised fresh:
   - `patches/llvm-mos/0003-late-opt-txy-dead-flag.patch` → **PR #562**, merged as commit `9142aebae`
     ("`[MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY (#562)`").
   - `patches/llvm-mos/0008-mos-dp-arg-cc.patch` → **PR #563**, merged as commit `8be054612`
     ("`[MOS] Pass addrspace(1) (8-bit direct-page) pointer arguments in an 8-bit register (#563)`").
   Both patches now fail `git apply` because their fix is already present upstream. Per
   [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md)'s own note on `0003`:
   "drop once merged + the vendor pin bumps" — exactly this situation, now for both.

2. **Pre-existing tooling inconsistency (independent of drift):** `dev/toolchain.sh`'s bootstrap loop
   (`for p in patches/llvm-mos/*.patch; do git apply "$p"; done`) assumes every patch file stacks
   additively. That stopped being true once `dev/regen-patch.sh` (the **0002** regenerator) started
   mirroring the **entire live** `llvm/lib/Target/MOS` directory rather than a narrow delta — `0002`, as
   currently committed, already contains the full content of `0001`(MOS-dir part)/`0004`–`0015`
   (confirmed below), so reapplying those files on top of `0002` always double-inserts the same hunks
   and fails, upstream drift aside. This was undetected because `vendor/` is normally kept warm
   (hand-edited in place, snapshotted via `regen-patch*.sh`) and this from-scratch path likely hasn't
   been exercised since the stack was `0001`–`0007` (`TODO.md` 2026-06-22, "0007-fold-toolchain-rebuild").

   **Confirmed by grepping each patch's distinctive symbol against `0002`:**

   | Patch | Distinctive symbol | In `0002`? |
   |---|---|---|
   | 0004 far-cc | `MOSFarCCImag32` | ✅ yes |
   | 0005 far-ptr-value-legalize | (PF-as-value hunk, same file/region as 0004) | ✅ yes |
   | 0006 packed24 | `AS_FarPacked` | ✅ yes |
   | 0007 near-abs-bank-relax | `fixupNeedsRelaxationAdvanced` | ✅ yes |
   | 0008 dp-arg-cc | AS1 `CCIfPtrAddrSpace<1,...>` rule | ✅ yes (duplicate content — this is *also* now upstream, unlike 0003 it was never excluded from 0002's mirror) |
   | 0009 a16-pressure-incdec | `IncMB` | ✅ yes |
   | 0010 coalesce-rotate-ac | `shouldCoalesce` | ✅ yes |
   | 0011 scavenger-live-p-save | `saveScavengerRegister` | ✅ yes |
   | 0012 ldcimm-set-lowering | `LDCImm` | ✅ yes |
   | 0013 far-memops | `createFarMemLibcall` | ✅ yes |
   | 0014 far-ptr-phi-legalize | `legalizePhi` | ✅ yes |
   | 0015 coalesce-rc-undef | `checkRegMaskInterference` | ✅ yes |
   | 0016 scmp-ucmp-legalize | `lowerThreewayCompare` | ❌ **not** in 0002 — genuinely new |
   | 0017 a16-s64-unmerge-anyext | `legalizeUnmergeS64ToWords` | ❌ **not** in 0002 — genuinely new |

   Patches `0004`–`0015` remain valuable as **standalone, individually-reviewable upstream-PR
   artifacts** (several are explicitly tracked as "not yet pushed" PR-drafts in
   `docs/upstream-contribution-status.md`) — they must **not** be deleted, only excluded from the
   build-time apply loop.

   > ### ⚠️ Correction (2026-07-26) — the symbol-grep table above is MISLEADING
   >
   > The first build attempt with the curated list `0001 → 0002 → 0016 → 0017` **failed to compile**:
   > ```
   > MOSAsmPrinter.cpp:63:52: error: only virtual member functions can be marked 'override'
   >    63 |                                     uint64_t Size) override;
   > ```
   > **Why the table was wrong:** `dev/regen-patch.sh` mirrors **only** `llvm/lib/Target/MOS/` (its
   > `MOSREL`). So `0002` absorbs each patch's **MOS-backend-dir hunks only** — any hunk outside that
   > directory (generic LLVM, clang) is **not** in `0002`. The symbol grep found each distinctive symbol
   > *because the MOS-dir half was present*, and I wrongly read that as the whole patch being absorbed.
   >
   > Concretely, **`0006-320-packed24`** adds the **generic** `AsmPrinter::emitNonStandardSizedConstant`
   > virtual hook (`llvm/include/llvm/CodeGen/AsmPrinter.h` + the call site in `emitGlobalConstantImpl`
   > in `llvm/lib/CodeGen/AsmPrinter/AsmPrinter.cpp`), plus a `clang/lib/Basic/Targets/MOS.cpp` hunk.
   > `MOSAsmPrinter.cpp` *overrides* that hook and that override **is** in `0002` — so dropping `0006`
   > left an `override` with no base virtual. (An earlier note in this plan speculated upstream had
   > *removed* an API; that was **incorrect** — the hook is our own, and was simply never applied.)
   >
   > **Only two patches touch anything outside `llvm/lib/Target/MOS/`** (mechanically verified over all
   > patch files, ignoring `llvm/test/`): **`0001`** (already applied whole) and **`0006`**. `0015`'s
   > only non-MOS file is a lit test, irrelevant to a build.
   >
   > **Corrected build-time stack:**
   > **`0001` → `0002` → `0006`(non-MOS-dir hunks only, via `git apply --include=`) → `0016` → `0017`.**
   > Verified: all five apply cleanly against upstream tip `8be054612`, and the hook is present
   > afterwards in both `AsmPrinter.h` and `AsmPrinter.cpp`.

## Plan

1. Retire `0003`/`0008` from the patch directory (upstream-merged; matches the documented "drop once
   merged" intent). Note the merge commits in `docs/upstream-contribution-status.md` (flip their rows
   from OPEN → MERGED) and in the `Ready to post now` list.
2. Hand-resolve `0002`'s single remaining real conflict: its `MOSCallingConv.td` hunk re-inserts the
   AS1 8-bit direct-page pointer CC rule that PR #563 already landed upstream (near-identical content,
   comment-wording-only diff — confirmed byte-for-byte functionally identical: same register list, same
   behavior). Drop that duplicate insertion from `0002`, keeping the still-unlanded AS2 far-pointer CC
   variants (a)–(d).
3. Bump the vendor pin: `dev/toolchain.sh` clones `llvm-mos/main` unpinned (by design, per
   `docs/howto-feature-worktree.md`'s "branch off the live tip" philosophy) — no explicit pin to bump in
   the script itself, but confirm the clone lands on current tip (`8be054612` or later) and that `0001`,
   `0002` (patched), `0016`, `0017` all apply cleanly there.
4. Fix `dev/toolchain.sh`'s bootstrap loop: replace the blind `for p in patches/llvm-mos/*.patch` glob
   with an explicit curated list — **`0001`, `0002`, `0006`(path-filtered to its non-MOS-dir hunks),
   `0016`, `0017`** (see the ⚠️ Correction above; the naive `0001/0002/0016/0017` list does not build)
   — with a comment explaining the two-tier model (`0002` = MOS-**dir**-only snapshot, so generic-LLVM
   and clang hunks must still be applied explicitly; standalone future-PR artifacts otherwise excluded)
   so this doesn't silently rot again as new patches are added.
5. Build the toolchain from the fixed bootstrap path (fresh clone, no warm cache) and confirm success.
6. Re-run the full differential gate suite to confirm the reconstructed tree is behaviorally identical
   to what `main` was building before: `dev/run.sh xcheck` (corpus, 4-way), the SNES demo battery smoke
   (`dev/run.sh cpu6502` is the actual trigger for this whole investigation), and spot-check a couple of
   the patches' own dedicated gates (`dev/run.sh coalesce...`, `a16regpress`, etc.) if time allows —
   full `torture`/`fuzz-csmith` sweeps are CI-scale and likely deferred to that job rather than repeated
   locally end-to-end.
7. ~~Regenerate `0002` via `dev/regen-patch.sh` from the now-live, fully-patched `vendor/llvm-mos` tree so
   the tracked patch file matches byte-for-byte (round-trip verified) and the manual hand-edit from step
   2 is captured by the real tooling, not left as a one-off manual diff.~~ **SKIPPED — would be actively
   harmful (2026-07-26).** `regen-patch.sh` rebuilds `0002` as an `rsync --delete` mirror of the *live*
   `llvm/lib/Target/MOS/` dir. That dir now contains `0016`'s and `0017`'s content (both patch
   `MOSLegalizerInfo.cpp` — verified present in the live tree), so regenerating would **absorb `0016`
   and `0017` into `0002`**, after which the build list would double-apply them and fail. The step-2
   hand-edit needs no such capture: it is minimal (one hunk header count + flipping an already-upstream
   block from added to context), and is **verified by construction** — the stack applies cleanly to
   pristine tip and the toolchain builds from it. Running the regen would be a *model change* (folding
   two more patches into the snapshot), not a neutral round-trip, and is out of scope here.
8. Publish `#102 cpu6502` to biohack.net via `/snes-rom-page` (the original ask).
9. Leave `0004`–`0015`'s individual "clean `git apply --check` against pristine" claims as a **known,
   flagged follow-up** — their pristine base has moved (was `c798c3141`, now past `8be054612`), so those
   claims are stale for upstream-posting purposes even though their content is still logically correct.
   Also flagged: 11 of the 12 per-patch `dev/regen-patch-000N.sh` scripts hardcode applying
   `0003-late-opt-txy-dead-flag.patch` and/or `0008-mos-dp-arg-cc.patch` as baseline steps (only the
   generic `dev/regen-patch.sh` handles a missing `0003` gracefully via its `[ -f "$P3" ]` guard) — now
   that both files are deleted, running any of `regen-patch-{0001,0004,0005,0006,0007,0009,0011,0012,
   0013,0014}.sh` will fail outright until they're updated to drop those two `git apply` calls. Not
   blocking today's work (none of them need to run for this rebase); add a TODO item.

## Verification

1. `dev/run.sh toolchain` (truly fresh — `rm -rf vendor/llvm-mos` first) succeeds end-to-end.

```
==> done in 9m 32s: clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)
TOOLCHAIN BUILD SUCCEEDED
```

**PASS** — fresh clone of upstream tip `8be054612`, corrected stack
(`0001 → 0002 → 0006`-generic `→ 0016 → 0017`). (9m32s = warm ccache from the two prior attempts; the
genuinely-cold first build was ~1h.)

2. `dev/run.sh xcheck` — host==default==a16==xy16 on MAME (+ bsnes-jg where wired), 0 mismatches.

`dev/xcheck.sh` fetches (pinned+sha256-checked) and builds the bsnes-jg core + `jgxcheck` harness
itself, so the bsnes-jg leg **was** obtainable on this box after all — done, and it now stays cached
for every future gate here.

```
==> bsnes-jg cross-check (independent of MAME)
  PASS  hello.sfc: SMOKE: PASS off=0x20 len=1 got=0x42 (ran 180 frames, bsnes-jg)
  PASS  far-run.sfc: SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far-bank1.sfc: SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_indir.sfc: SMOKE: PASS off=0x204 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_cast.sfc: SMOKE: PASS off=0x202 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_arith.sfc: SMOKE: PASS off=0x202 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_store.sfc: SMOKE: PASS off=0x205 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_memops.sfc: SMOKE: PASS off=0x202 len=1 got=0x74 (ran 180 frames, bsnes-jg)
  PASS  far_loop.sfc: SMOKE: PASS off=0x204 len=1 got=0xC9 (ran 180 frames, bsnes-jg)
  PASS  far_call.sfc: SMOKE: PASS off=0x201 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far_near_call.sfc: SMOKE: PASS off=0x201 len=1 got=0xE0 (ran 180 frames, bsnes-jg)
  PASS  far_tail.sfc: SMOKE: PASS off=0x202 len=1 got=0xCB (ran 180 frames, bsnes-jg)
  PASS  far_fnptr.sfc: SMOKE: PASS off=0x200 len=1 got=0xFF (ran 180 frames, bsnes-jg)
  PASS  far_indir_tail.sfc: SMOKE: PASS off=0x200 len=1 got=0xFF (ran 180 frames, bsnes-jg)
  PASS  packed24_e2e.sfc: SMOKE: PASS off=0x203 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  packed24_table.sfc: SMOKE: PASS off=0x200 len=1 got=0xA5 (ran 180 frames, bsnes-jg)
RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
```

**PASS — 16/16 far ROMs green on the rebased toolchain.** Note `packed24_e2e` and `packed24_table`
passing is the load-bearing evidence for §3 of the Correction above: those are exactly the ROMs that
exercise `0006`'s `emitNonStandardSizedConstant` hook (3-byte packed far pointer, `ADDR24_SEGMENT_LO/
HI/BANK` relocations). Their `0xF3`/`0xA5` prove the bank byte survives — i.e. the path-filtered `0006`
apply reconstructs that behaviour correctly, not just compiles.

⚠️ **Remaining gap: the MAME leg.** `SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored
Nintendo content; supply out-of-band)` — copyrighted Nintendo firmware that cannot be fetched. So this
is a **3-way** (host / default / a16 on bsnes-jg), not the full 4-way with MAME cross-confirmation. Drop
the IPL at that path to close it.

3. `dev/run.sh cpu6502` — `RESULT: PASS`, CRC `0xAC8A` (matches the plan's recorded gate value).

```
==> host oracle: cpu6502 gate_crc = 0xAC8A
==> built build/cpu6502.sfc (+mos-a16); corpus_result @ WRAM 0xadd
==> opcode dispatch probe (expect jump table in disasm)
    PASS  jmp_table=4  rep/sep=97
==> bsnes-jg: render + assert (build/cpu6502-jg.png)
SMOKE: PASS off=0xADD len=2 got=0xAC8A (ran 1000 frames, bsnes-jg)
    SKIP MAME (no SPC700 IPL)

RESULT: PASS — 6502/65C02 CPU Disassembler+Simulator on SNES; gate_crc=0xAC8A host==+mos-a16
jgxcheck: wrote /work/build/cpu6502-jg.png (256x224 from native 512x240, yoff=0)
```

**PASS, with real runtime execution.** The `+mos-a16` ROM ran 1000 frames on the cycle-accurate
bsnes-jg core and produced `0xAC8A` at WRAM `0xADD` — identical to both the host oracle and the value
recorded pre-rebase on 2026-07-02. The disasm probe also reproduces the recorded shape exactly
(`jmp_table=4`, `rep/sep=97`), so the 256-entry `switch` still lowers to a genuine jump table.

**Visual check** (`build/cpu6502-jg.png`, read back): renders correctly — `0019 CMP` highlighted yellow
in the Waldo-16 disassembly listing with the **CMP** gate lit in the panel (highlight and lit gate
agree, which is the demo's whole invariant), register strip `A:42 X:04 Y:00`, PC `$001B`. Matches the
screenshot recorded in the #102 plan.

**Incidental finding:** `corpus_result` moved from WRAM `0x70` (recorded 2026-07-02) to **`0xadd`** on
the rebased toolchain — confirmed in `build/cpu6502.map` and in the gate's own `off=0xADD`. Benign (a
layout difference), but it is the offset any `--selfcheck` wiring must use now.

4. ~~`dev/regen-patch.sh` round-trip — `RESULT: PASS`.~~ **N/A — step 7 skipped, see above.**

5. cpu6502 published + live at `https://biohack.net/snes/cpu6502/`.

**PASS — and it turns out it was already published.** The #102 plan's "Publish to biohack.net pending"
note was **stale**: the page, ROM, preview and manifest selfcheck (`off=0xADD len=2 want=0xAC8A
frames=1000`) were all already committed and deployed on biohack.net by `aff09db` / tag `v1.0.254` (the
full-screen-layout redesign). Verified live:

```
page: HTTP 200            https://biohack.net/snes/cpu6502/
rom:  HTTP 200  (32768 bytes)
<title>6502 CPU Simulator — bioHACK•NET</title>
```

**The strongest result of this whole pass** — the ROM built by the *rebased* toolchain is
**byte-identical** to the one built by the *old* toolchain that is currently deployed:

```
live deployed : c0df7cfd195ba8bb
site repo copy: c0df7cfd195ba8bb
fresh rebuild : c0df7cfd195ba8bb
```

Bit-for-bit reproducibility across the upstream bump + patch-stack rebase is much stronger evidence of
behaviour preservation than the gate CRC alone (a CRC match only constrains one 16-bit observable; this
constrains all 32768 bytes). Nothing needed publishing; TODO corrected instead.

## Out of scope (this pass)

- Regenerating `0004`–`0015`'s individual patches against the new pristine base (flagged as follow-up,
  item 9 above).
- Posting any new/updated upstream PRs (`0003`/`0008` are already posted+merged; nothing new to post
  from this work — it's fork-side bookkeeping).
