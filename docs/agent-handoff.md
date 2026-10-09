# llvm-mos-65816 — agent handoff: build/test mechanics & backend navigation

**Compiler pin, October 9:** bootstrap, lit and regeneration use `dev/llvm-mos-pin` (`f24948c7d1a4`). An existing July vendor checkout is preserved; the default build selects `vendor/llvm-mos-f24948c7d1a4` and `build/llvm-mos-f24948c7d1a4`. Explicit `LLVM_MOS_SOURCE`, `LLVM_MOS_BUILDDIR` and `LLVM_MOS_INSTALL` paths support isolated builds. Merged carries are removed from the aggregates and standalone stack; original closure artifacts for 0028/0055/0056 retain their hashes and have new vendor twins. [Rebase and validation record](pr-preparations/2026-10-09/pin-rebase/README.md). Compiler identities and measurements below remain dated evidence for their recorded builds.

Pin update: OpenAI Codex 0.162.0, model `gpt-6.1-sol`, `medium` reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.


**Pressure sets, October 1:** `0002` now carries the #320/#321 split's native-width pressure-set design. The new standalone patch `0071-mos-accumulator-pressure-set` follows `0070` in `dev/toolchain.sh` and `STANDALONE_MOSDIR`, and appends the 8-bit accumulator pressure set (limit 1) that the computed-carry scheduling of `0064`/`0067` relies on. `TESTRELS` now lists `native-width-default-pressure.ll` and `native-width-pressure-opt-level.ll`. The installed toolchain was rebuilt at 2026‑10‑01T03:06Z: `llc` `6f303945beb17ab3…`, `clang-23` `e532fbee9b788713…`, `lld` `0d74dddcab805faf…`. Default-mode code is 0.45–0.74% smaller at every level. [Plan](plans/2026-10-01-carry-pressure-contract.md#landing).

**Far-word rebase, September 30:** the 0069/0070 series is [rebased onto `06bc967d2668`](pr-preparations/2026-09-30/far-word-rebase/README.md) with unchanged patch bodies. The suites, the 228-case sensitivity check and all 58 MAME/bsnes configurations reproduce the September 28 bytes and clocks. The [independent review](pr-preparations/2026-09-30/far-word-rebase/independent-review.md) upholds 0069, 0070 and patches 9–11 but blocks filing. The far prerequisite has four defects that also reproduce downstream: [far-pointer argument exhaustion](defects/mos-far-pointer-arg-exhaustion.json), [far memory lengths above 65535](defects/mos-far-memop-length-truncation.json), [far accesses on non-65816 CPUs](defects/mos-far-access-non-65816.json) and [undef debug values after the far index fold](defects/mos-far-index-fold-dangling-dbg.json). It also has two extraction gaps (a trunc pattern and far-quad DWARF) and an `Imag32` collision with open #594 that needs a maintainer decision. The repairs go into the [#320/#321 split series](plans/2026-09-30-split-320-321-series.md) before the series is reviewed again.

**Native-word policy, September 28:** [0070 is installed locally](investigations/2026-09-28-far-word-policy.md) and enables bounded word indexing at `-O2`/`-O3`. The `-Os` Farblit gate retains its word fallback. The [working PR draft and evidence guide](pr-preparations/2026-09-28/far-word-index/README.md) now explain the policy, proof, measured tradeoffs, and limitations with diagrams. Upstream source is inspected at `26d7c2c1eebf`; the native/far prerequisites are absent there. [Three separate AI source reviews](pr-preparations/2026-09-28/far-word-index/independent-review.md) found no valid-input compiler correctness defect. The P2 weakness in 0069's opcode assertions is resolved: all 78 checks have explicit boundaries, all 156 wrong substitutions are rejected, and four focused regression files pass. The preserved checks accepted 104 of those substitutions. The [extracted candidate](pr-preparations/2026-09-28/far-word-index/upstream-series.md) now provides ordered patches on that exact base, an assertions build, expanded checks and separate frozen-IR replay evidence. Independent review of the complete compiler/ABI series and its listed contract limits remains pending. Update attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Worktree cleanup (2026-09-28)

At the user's request, 11 clean, idle worktree directories were removed to free disk space. **All existing branches and their commits were retained.** A missing directory in the table below is intentional; it does not mean the work was lost or merged. Older worktree paths elsewhere in this document and in dated reports describe the checkout at that time. Use `git worktree list` for the current checkout inventory and `git branch --list` for retained branches.

| Removed checkout | Retained branch | Commit at removal |
| --- | --- | --- |
| `/home/will/llvm-mos-65816-138-late-opt` | `throwaway/138-late-opt-crash` | `cef5953c82fe` |
| `/home/will/llvm-mos-65816-60fps` | `feature/60fps-video` | `d278d56be73b` |
| `/home/will/llvm-mos-65816-absdiff` | `wt/321-absdiff` | `e5c621bb0659` |
| `/home/will/llvm-mos-65816-dpy-publish` | `wt/321-dpy-publish` | `cd13fb33e6be` |
| `/home/will/llvm-mos-65816-exhirom` | `feature/exhirom-canaries` | `28ab9fbed7fb` |
| `/home/will/llvm-mos-65816-gallery-repro` | `throwaway/gallery-repro-bisect` | `95376890686e` |
| `/home/will/llvm-mos-65816-mixedwidth` | `wt/321-mixedwidth` | `020ad31d19ba` |
| `/home/will/llvm-mos-65816-snesgfx-virt-bench` | `throwaway/snesgfx-virt-bench` | `abfd36e15fa2` |
| `.scratch/carry-clang-docs` | `carry-upstream-clang-validation` | `a9bedfae31b9` |
| `.scratch/carry-publish` | `carry-scheduling-preparation` | `f7a1e06e54db` |
| `/tmp/snes-discovery-pr-simulations` | `cleanup-preserved/snes-discovery-pr-simulations` | `ff79e28475fa` |

The last checkout had a detached HEAD; its preservation branch was created before removal. Recreate any listed checkout with `git worktree add <checkout-path> <retained-branch>`. Branch tips can advance after this cleanup; the table records the original commits. Worktrees containing local changes, untracked work, or substantial ignored artifacts were retained, including the patched vendor source in `llvm-mos-65816-base8c`.

Cleanup also cleared disposable ccache entries in `build/.ccache`, `.scratch/carry-scheduling/build/.ccache`, and `/home/will/llvm-mos-65816-base8c/build/.ccache`; npm's `/home/will/.npm/_cacache`; and Rust incremental compilation data under `/home/will/.cache/s100-03-target/debug/incremental` and `/home/will/.cache/s100-13-verify-target/debug/incremental`. Sources, installed compiler binaries, build outputs, logs, and defect baselines were preserved. Future compilation or package installation may refill these caches. Available space on the main filesystem increased from about 4.3 GiB to 17 GiB during this pass.

Dependency review: the project guide, feature-worktree instructions, patch-series guide, and current upstream summaries still apply. Their compiler and publication claims are unaffected by removing these checkouts. Dated plans retain their historical paths, qualified by this cleanup inventory.

Cleanup and documentation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e526-d67a-7c62-aad4-98d6954231cf` (initial inspection used `medium`; deletion and documentation used `high`).

## Current compiler and publication status

**Carry-scheduler investigation:** [LLVM-facing report](investigations/2026-09-27-competing-carry-gate.md). The report compares 213,866 B of aggregate savings under `always` with 199,309 B under `gated`, and 39 versus six growing objects. It presents the 6.81% difference as a trade-off, without selecting an upstream default. A16 and ordinary-6502 subsets have no observed function growth; [Completed-output selection and three pressure-model trials](investigations/2026-09-27-carry-profitability-model.md) are now implemented and measured; broader testing of narrower gating remains an option. The downstream compiler still defaults to `always`. The local 5% threshold is historical planning context, not an LLVM acceptance criterion. Runtime retains the baseline-reproduced XY16 VLA mismatch. The object selector is an investigation prototype; its object-size criterion does not guarantee per-function or final-ROM size. No new scheduler default or upstream submission is selected. The generic pressure contract remains open. Final identities, 181 passing MOS tests and raw measurements remain retained. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

**XY16 `vlastack_sim` follow-up (2026-09-28):** The [canonical correctness record](defects/mos-xy16-stale-x-writer-reload.json) and [causal investigation](investigations/2026-09-28-vlastack-xy16-stale-reload.md) isolate the mismatch to `MOSInsertREPSEP` replaying an X writer after its source pair was overwritten. The preserved pre-gate compiler remains red (`0xD3BD`); the repaired compiler in `build/llvm-mos-install` returns `0xD77B` for the unchanged original input on both emulators. Patch `0002` now preserves X itself, with MIR, hard-stack/flags runtime and in-place-memmove checks. The full MOS suites retain five unrelated `opt` option-registration failures (fixed September 29: [record](defects/mos-near-nowrap-option-clash.json)). Repair and validation: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e5e8-7760-7383-a39a-629f539d24fa. Investigation and documentation: OpenAI Codex API agent 0.157.1, exact model ID unknown (GPT-6 family stated by the session), reasoning effort unknown; session 01a0e5a0-9b2c-7c81-9f0b-d154ff8783d9.

**Later September 28 range-proof integration:** [0069 is installed locally](investigations/2026-09-28-farblit-range-integration.md); `cp8` now uses Y8 in both modes. The current gate passes eight emulator assertions and 16 sensitivity tests. The following gate counts describe earlier builds; the standalone 0064 packet and publication status are unchanged. Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

**Farblit gate update (2026-09-28):** the [per-probe gate](investigations/2026-09-27-farblit-byte-load.md#completed-gate-update-2026-09-28) passes on preserved and installed compilers, with eight emulator assertions and 15 checker tests per toolchain. The following aggregate-count qualifications are dated evidence. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; session `01a0e529-62c6-7fc2-a0c6-357800272c63`.

**Earlier local compiler update (0066):** [0066 repairs farblit byte-load legalization](investigations/2026-09-27-farblit-byte-load.md) on top of 0065. Clang and the LTO linker in `build/llvm-mos-install` are refreshed; the preserved input passes. The MOS suites have 180 passes and two unsupported; eight farblit/pressure emulator assertions pass. The unchanged shell gate still fails aggregate opcode counts, retained as a separate follow-up. Candidate and ablation tools are in `.scratch/farblit-t4/`. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

**Current publication status:** PR #609 was withdrawn at the user's request at `2026-09-27T01:38:15Z`. Earlier review and validation results remain dated evidence. [Withdrawal record](pr-preparations/2026-09-26/0064-submission.json). Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`.

**September 27 near-index optimization:** [proof recovery after LSR](investigations/2026-09-27-near-index-overflow-proofs.md) is implemented locally in `0002`. The corpus saves 33,159 B across 1,197 paired builds; nine configurations grow and no new compile failures appear. The final build is preserved under `build/near-proof-recovery/final` and installed in `build/llvm-mos-install`. All 48 affected-corpus runtime checks and twelve near checks pass; the report records the remaining scope. **September 29:** the [upstream packet](pr-preparations/2026-09-29/near-index-proofs/README.md) extracts it onto `llvm-mos` `06bc967d2668` with independent review. Until the September 29 repair, any `opt` built from `0002` aborted at startup; that was the recorded [option collision](defects/mos-near-nowrap-option-clash.json), and the cause of the five `opt`-based MOS lit failures. `0002` and the extraction now name the pass `mos-near-nowrap-recovery`, and the downstream suites pass: 186 tests, 3 unsupported. A [prerequisite `preserveX` defect](defects/mos-xy16-preserve-x-p-save.json) is also open. Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

**September 27 near-decoder validation:** the [near-decoder repair](investigations/2026-09-27-near-y-decoder.md) is carried in `0002` and installed in `build/llvm-mos-install`. Fused Y accesses and a separate near-address wrap guard pass the original 62-work gallery, twelve runtime configurations, and 178 MOS tests (two unsupported). Preserved baseline, fusion-only, and final binaries remain in `build/near-y-fix/`.

**0065 upstream preparation (2026-09-28):** the [review packet](pr-preparations/2026-09-28/0065/README.md) contains the native-only #321 prerequisites, 0063 and 0065 on upstream `26d7c2c1eebf`, with independent 0065 review. Fresh validation: 145 supported MOS tests, 486 function comparisons with 72 smaller and zero larger, loaded-pointer native fallback at 17 B versus 22 B, and six emulator assertions at `0xFA36`. The local completion record and installed compiler are unchanged. The PR is unposted; the #321 publication hold and #321/0063 merge prerequisites remain. Update: OpenAI Codex CLI 0.158.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e75a-a9ed-7372-9bac-b19b732a46a2`.

**Prior local compiler update (2026-09-27):** patch 0065 is committed and pushed to downstream `main` as [4d7136cb](https://github.com/wbniv/llvm-mos-65816/commit/4d7136cb15cf85a676b624a5892e5e8ce7ae0217) and implements the [broader near-store profitability work](plans/2026-09-27-broader-near-store-profitability.md) on top of the near-decoder repair. Preserved baseline/candidate tools and measurements are in `build/near-store-broad/`; the installed compiler is refreshed. The current MOS suite has 179 passes and two unsupported tests. No new failures or size increases occurred in the 412-input corpus; the new fixture is the only changed object (-35 B per native mode). At this dated checkpoint upstream #321 extraction and independent review remained separate; the September 28 packet above records their completion for 0065. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e0ee-df60-7d80-8629-5ad167a8c407`.

## Carry-scheduling publication

Compiler branch `mos-computed-carry-scheduling` is pushed at `155e209c4cee`.
The [0064 packet](pr-preparations/2026-09-26/README.md) retains exact upstream
validation, downstream costs and separate open follow-ups. The downstream
publication branch is `carry-scheduling-preparation`, based on `b3938bda`, in
`.scratch/carry-publish`. That publication left the shared checkout and installed compiler unchanged. [PR #609](https://github.com/llvm-mos/llvm-mos/pull/609) was closed at the user's request on September 27; its branch is retained at compiler commit `155e209c4cee`. The destination recheck is `26d7c2c1eebf`; local validation remains on `7bd67c0ae4e8`. Publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.

Publication history: PR creation was not authorized. The user subsequently directed that it remain open for their review and separately authorized the remaining repository commit/push work. The September 27 withdrawal request supersedes that earlier instruction to keep the PR open. Further publication requires user direction.

**September 27 validation update:** the user subsequently authorized updating
the PR body. Rebuilt upstream Clang at parent `7bd67c0ae4e8` and head
`155e209c4cee` passes 117 direct C-to-object pairs across three verified CPU
selections; paired disassembly and objects excluding `.comment` are identical.
The [validation record](pr-preparations/2026-09-26/0064-validation.md) also
corrects the original fixed-IR census to 39 distinct 6502 configurations.
Documentation and retained evidence are prepared on
`carry-upstream-clang-validation` in `.scratch/carry-clang-docs`; isolated
builds are in `.scratch/carry-clang-upstream`. Independent review remains
pending. Validation and documentation: OpenAI Codex CLI 0.157.1, model
`gpt-6-astra`, `xhigh` reasoning effort.

The separate null-emission crash recorded in the 0064 validation is fixed
locally by patch 0068. Its preserved IR passes diagnostic null emission on the
patched downstream build. The [standalone extraction](pr-preparations/2026-09-27/0068-validation.md) is now validated on upstream `26d7c2c1eebf`, with 21 null-output repairs, 24 identical ordinary outputs and 133 MOS passes / one unsupported. Independent review remains pending; the historical 0064 extraction is unchanged. See the [defect investigation](investigations/2026-09-27-mos-null-output-streamer.md).

Verbose reference for doing codegen work on this repo. The high-level orientation, the `vendor/` model, the
four governing lessons, and commit discipline are in the auto-loaded project
[`CLAUDE.md`](../CLAUDE.md) — read that first; this file is the mechanics it points to. (Per-task specifics
live in `docs/plans/YYYY-MM-DD-<topic>.md`.)

**Preparing an upstream submission?** Use the current
[posting packet](pr-preparations/2026-09-26/README.md) and its
[feature-held ledger](pr-preparations/2026-09-26/feature-held-packages.md) for
exact artifacts, reviews, base identities, and unresolved gates. The
[submission campaign plan](plans/2026-07-26-upstream-submission-campaign.md)
retains the dated July wave ordering and posting mechanics; its two-merged-PR
count is historical. Posting remains user-triggered. The reviewer-facing
synthesis of the patch stack — per-patch *need / patch / proof*, diagrams, appendices — is
[`65816-patch-series-review-guide.md`](65816-patch-series-review-guide.md) (with an
[LLVM primer](llvm-primer-for-65816-review.md) for readers new to LLVM). It is the "how to review this" map;
this file remains the "how to build/test/navigate it" mechanics.

**Patch model (two-tier, steady state since 2026-07-26):** `0002` is a comprehensive rsync mirror of
`llvm/lib/Target/MOS/` regenerated only by `dev/regen-patch.sh`; the fresh-clone bootstrap applies
**`0001 → 0002 → 0006`(non-MOS-dir hunks)** plus the **upstream-bound standalone fixes** that are applied
after `0002` and reverse-applied out of every `0002` regen (`STANDALONE_MOSDIR` in `dev/regen-patch.sh`;
`0010`, `0018`–`0025`, and `0003` via the baseline — the exact list and order is `dev/toolchain.sh`).
The remaining numbered patch files are **frozen upstream-PR artifacts** — never applied at build time,
never regenerated from the live tree (the per-patch `regen-patch-000N.sh` scripts are retired and exit 2
with an explanation). Fixes to fork features fold into `0002`; only stock-llvm-mos defects get standalone
artifacts.

**Need the 65816 ISA itself** (registers, addressing modes, opcode matrix, cycle counts, native/emulation
mode, `rep`/`sep`, `M`/`X` semantics)? [`65816-references.md`](65816-references.md) collects the canonical,
freely-linkable sources — WDC's current W65C816S datasheet first — and records the **link-don't-vendor**
licensing rule (datasheets are third-party copyrighted; the release tarball stays Apache-2.0/LLVM clean).

## Active worktrees (2026-06-26)

Completed profitability experiment: `throwaway/carry-profitability` in `.scratch/carry-profitability`, based on `b65bb853`; independent compiler source/build and frozen weighted-model tools are retained. Tested patches, measurements and the object-selector prototype accompany the [report](investigations/2026-09-27-carry-profitability-model.md). The installed compiler remains unchanged.

> **CONSOLIDATION 2026-06-25 (user-directed "collapse worktrees, get things on main").** The standing
> "retain worktrees until upstream merge" policy was **explicitly overridden** for this pass. Landed to
> `main` and **torn down (local worktree + branch; `origin/wt/*` remotes kept)**:
> `wt/321-snes-hwref` (HAL split + ref docs), `wt/321-mandel-zoom` (zoom demo), `wt/321-a16-pressure`
> (patch **0009**, regalloc deadlock fix — re-verified: a16regpress + corpus-a16 globals.c now pass),
> `wt/321-trig` (far array-subscript fix folded into **0001** + libfixmath/HiROM corpus — re-verified:
> k_trig32 `0x068A6933`, k_trig32lut HiROM `0x87F0B404`, both emulators). Also torn down (already-merged
> or superseded): `wt/320-far-tailcall`, `wt/320-near-abs-bank-relax`, `wt/321-mandelbrot`,
> `wt/321-s32-verify`, `wt/321-track-a`, `wt/dp-arg-cc`, `wt/321-xy16`, `wt/320-far-cc`,
> `wt/320-far-followups` (its far-cc round-trip sources + `far_sizeof` gate salvaged to `main`),
> `wt/321-frame-abi` (NULL verdict; the inert `0002` frame-feature spike preserved as a docs/plans/spikes
> patch). The rows below mostly predate that consolidation: rows it lists as torn-down are gone, but
> rows still marked **Worktree RETAINED** remain **live**. New worktrees (post-consolidation) are
> registered at the top of the table.

| Branch | Worktree | Task | Status |
|--------|----------|------|--------|
| `wt/display-first-frame-optin` | `/home/will/llvm-mos-65816-dispoptin` (+ a throwaway measurement tree `/home/will/llvm-mos-65816-dispoptin-base`, detached at `22f18cb`, holding the "before" half of the sweep) | **Per-drawable "first frame is complete" opt-in for `snesgfx` Display** ([plan](plans/2026-09-14-display-first-frame-optin.md)) | **✅ IMPLEMENTED + verified (2026-09-14), on the branch — NOT merged.** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain via `cp -al`; no `vendor/` rebuild). The safe shape of the blanket fix rejected in [2026‑08‑05](plans/2026-08-05-display-first-frame-forceblank.md), gated **twice**: a per-drawable `Drawable.first_frame_complete` (cleared by `drawable_reserve()`, set by a `reserve()` that painted its whole first frame *including CGRAM*) ANDed into `Display.ff_all` in `display_add` and guarding the first `scene_emit` — **all of it inside `#if SNESGFX_FIRST_FRAME_OPTIN`**, a macro each adopting demo defines before the snesgfx includes. The compile-time half is not tidiness: the runtime-only first cut (`59ca122`) cost **+4,823 B of `.text` across 121 demos, 117 of them growing**, to serve one scene — lesson 3's blanket-change trap. Adopters: `MandelLayer`, `CaDisplay`, `LifeGrid`, and `TitleLayer` (macro-gated CGRAM[0] backdrop write, which is what lets `1d-ca`/`life` fire at all). `mandel-oop` swaps its demo-local Option J latch for the shared mechanism at **5 → 5** post-title frames (the proof the gate fires — without it, deleting the latch would have restored 11) and comes out **44 B lighter**. **Verified:** SNESDQ PASS (241 sites, +1 reviewed); **118/118 non-adopting demos byte-identical**, only the 3 adopters move (net +124 B); `dev/bootblank.sh --firstframe` **0 new** nondeterministic; boot windows unchanged for all 117, `life` 362→361; `dev/m7blank.sh --gate` 12/12 ok; `dev/run.sh` mandel-oop `0x204F` / life `0xDDF1` / 1d-ca `0xAB2C`, MAME+bsnes-jg. **Note:** two byte-identical demos (`mvscrl`, `qsortviz`) flipped `--firstframe` verdict between runs — the instrument's documented two-draw stochasticity, not a change. |
| `wt/321-spirograph` | `/home/will/llvm-mos-65816-spirograph` | #11 **Spirograph (hypotrochoid) compiler-stress demo** ([plan](plans/2026-06-27-11-snes-spirograph-hypotrochoid.md)) | **✅ DONE + verified (2026-06-27).** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain via `cp -al`; no `vendor/` rebuild). Four curve families (hypo/epi/rose/Lissajous) bloom into a **NEAR 2bpp bitmap canvas** — new reusable `examples/snes/snesgfx/{bitmap_canvas.h` (set-pixel + Bresenham + capped dirty-tile DMA on BG3)`,text_layer.h` (BG3-cotenant tiled HUD, reuses `font8.h`)} — joypad-interactive with an on-screen `R/W/D/mode/petals` HUD. **No far pointers ⇒ full 5-way bar.** New `examples/65816/spiro.h` (shared curve math: sin/cos-LUT + 16×16→32 `__mulsi3` + gear-ratio `__udiv`), `examples/snes/spirograph.{c,h}`, `tools/spiro-sim.c`, `corpus/{spiro_sim.c` (0x32D4 curve math)`,spiro_ctrl_sim.c` (0x6A26 controller/HUD-format math, the deterministic-scripted equivalent of a JGX replay)}, `dev/spirograph.{sh,lua}`. **Verified:** `dev/run.sh corpus-a16` 9/9 (`host==default==+mos-a16==+mos-xy16` MAME+bsnes), `dev/run.sh spirograph` RESULT PASS (disasm gate `__mulsi3`+`__udiv`+`rep/sep`, bsnes 3× byte-identical, MAME+bsnes screenshots == host). SDK/example-level — no compiler change. **Worktree RETAINED** per policy; **PUBLISHED — live at [https://biohack.net/spirograph/](https://biohack.net/spirograph/) (biohack.net v1.0.78).** |
| `wt/321-trig-phase3` | `/home/will/llvm-mos-65816-trig-phase2` (dir named `-trig-phase2`; repointed to the phase-3 branch) | #321 **trig compiler-test Phase 2 + Phase 3** — Q2.14 CORDIC: direct `sin/cos/atan/atan2`, derived `tan/asin/acos`, hyperbolic `sinh/cosh/tanh` ([Phase 2](plans/2026-06-26-trig-phase2-q214-cordic.md) · [Phase 3](plans/2026-06-26-trig-phase3-derived-hyperbolic.md)) | **✅ BOTH PHASES DONE + LANDED + PUSHED (2026-06-26).** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain via `cp -al`; no `vendor/` rebuild). **Phase 2** = `k_trig16` `0x9446C734` — a fresh Q2.14 CORDIC with **zero arithmetic libcalls** (native-s16 shift-add, the deliberate inverse of Phase 1's s32-libcall payload). **Phase 3** = `k_trig16x` `0x759567C4` — derived `tan/asin/acos` (a Q2.14 divide/sqrt → `__mulsi3`/`__divsi3` fire) + hyperbolic `sinh/cosh/tanh` via **CORDIC hyperbolic mode**; the 32-bit hyperbolic reference derives from the now-compiled `fix16_exp`. Both `host==default==+mos-a16` on **MAME + bsnes-jg** + host cross-width accuracy PASS (CORDIC beats libfixmath on `asin/acos`). New `examples/65816/{cordic16.h,cordic16_tables.h,k_trig16.c,k_trig16x.c}`, `tools/{gen-cordic-tables.py,trig-accuracy.c,trig-accuracy3.c}`, `dev/{k_trig16.sh,k_trig16x.sh}`. Merges `c37660f` (P2) + `4377791` (P3), pushed (`5a424df`). SDK/example-level — no compiler change. **Worktree RETAINED** per policy. |
| `wt/321-mandel-zoom` | (torn down) | #321 **Mandelbrot ZOOM PYRAMID** (shelved demo) ([plan](plans/2026-06-25-321-mandelbrot-zoom-pyramid.md)) | **🗑️ REMOVED from `main` 2026-06-26** (user request; worktree + branch already torn down — see consolidation note above). Deleted the demo, `tools/mandel-bake-pyramid.c`, `platforms/snes-zoom/`, the run scripts, `jgxcheck.cpp` `JGX_ZOOM`, and the orphaned `loopfold-*` discovery scripts. The DEFAULT-8bit matrix-fold miscompile it surfaced is **fixed** (patch `0010`; upstream repro is the self-contained `coalesce-rotate-ac.mir` lit test). Plan + screenshots kept as history. |
| `wt/321-mandelbrot` | `/home/will/llvm-mos-65816-mandelbrot` | #321 **beefy SNES Mandelbrot demo** — the first *beefy* `+mos-a16` customer ([plan](plans/2026-06-24-snes-mandelbrot-beefy-demo.md)) | **✅ DONE (2026-06-25), all on the branch — NOT yet merged to `main`.** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain; SDK real-copied). A fixed-point Q5.10 Mandelbrot (`examples/65816/mandel.h`, shared by target + a host PNG renderer) driven through four green stages: **T1** differential gate `dev/run.sh k_mandel` (host==default==`+mos-a16`==`+mos-xy16`==`0x820B`, both emulators, `-verify` clean); **T2** on-console render `dev/run.sh mandel-shot` (fat-pixel Mode-1 BG; **real emulator screenshots from BOTH** — bsnes-jg framebuffer dump via `dev/jgxcheck.cpp`, MAME `video:snapshot` under Xvfb — on-screen CRC==host `0x9103`; `+mos-a16`==default pixel-identical); **T3a** `dev/run.sh mandel-far` (Mandelbrot far-stored into HIGH WRAM `$7E2000` via #320 `sta [dp]`, host==`+mos-a16`==`0x820B`); **T3b** `dev/run.sh mandel-mode7` (BIG 128×128 per-pixel via **Mode 7** + one 32 KiB **DMA**, screenshots both emulators, `0x75E8`). **Grew the SNES display HAL** (`platforms/snes/snes.h`: VRAM/BG/DMA/Mode-7 regs + `snes_ppu_reset_blank`), `tools/png_write.h`, `task mandel-mame` (host MAME window). **Docs:** rendering handoff [`handoffs/2026-06-24-snes-graphics-rendering.md`](handoffs/2026-06-24-snes-graphics-rendering.md), how-tos [`investigations/snes-emulator-screenshots.md`](investigations/snes-emulator-screenshots.md) · [`object-oriented-c-and-assembly.md`](investigations/object-oriented-c-and-assembly.md) · [`open-source-snes-libraries.md`](investigations/open-source-snes-libraries.md). Findings: `+mos-a16` is +21% bigger here (Lesson 2, multiply-bound); an all-inlined `+mos-a16` verifier crash (a16-regalloc family; shipped kernels use `noinline mandel_cell`). **Worktree RETAINED** (user policy); nothing on `main` yet — merge/push is user-triggered. |
| `wt/dp-arg-cc` | `/home/will/llvm-mos-65816-dp-arg-cc` | #561 DP-pointer-argument CC crash — the spike that turned the bug report into a fix | **✅ FIX DONE + upstreamed.** `addrspace(1)` (8-bit direct-page) pointer **argument** crashed the backend (CC gave it a 16-bit `RS` reg → illegal `(p1)=COPY $rs`). Fix = a `CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2..RC15]>>` rule (8-bit slot, mirrors the `0004` far rules + the i8 pool), placed before the generic `CCIfPtr`; covers returns too (no separate RetCC), varargs unaffected. Validated (incremental rebuild): crash gone across 5 DP-arg shapes on `mos6502`+`mosw65816`, correct codegen (`tax; lda 0,x` / store `sta 0,x`), **corpus 7/7**, new `llvm/test/CodeGen/MOS/dp-pointer-arg.ll` crashes pre-fix / passes post. **Fork patch `0008`** (`e0e8bd4`, applies on `0001`-`0007`). **Upstream [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563)** off clean `c798c3141` (`Fixes #561`, auto-closes on merge) — built via a `vendor/llvm-mos` `git worktree` at the pristine HEAD (network clone timed out). **RETAINED until merge**; on merge drop `0008` + bump the vendor pin. [issue body](320-upstream-dp-arg-cc-issue.md) · [PR body](320-upstream-dp-arg-cc-pr.md) · [plan §A](plans/2026-06-22-320-far-value-residuals.md). |
| `wt/320-far-followups` | `/home/will/llvm-mos-65816-far-followups` | #320 far-calls follow-ups — **combined plan+handoff: [plans/2026-06-21-320-far-calls-followups.md](plans/2026-06-21-320-far-calls-followups.md)** (read it to resume) | **(b) far→near DONE + SHIPPED to `main` (`5717f6b`)** — generic bank-0 thunk `__call_near_from_far`; verified `0xE0` MAME+bsnes-jg, corpus 7/7, gc'd from near ROMs. **(a) far fn pointers — BACKEND DONE + e2e VERIFIED both emulators (`579b911`, 2026-06-21):** the far indirect call works end-to-end on real silicon. Call MECHANISM `lowerCall(__call_indir_far)→JSL` + stub `jml (__mos_far_target)`; IR-rep #1. The deep p2-value `0004` sub-project is COMPLETE: ✅ L1 `copyCost` Imag32, ✅ L2 hint size-guard, ✅ **L3** (`selectUnMergeValues` byte→word subreg `sublo16/subhi16` for the `s32→2×s16` unmerge — the real crash; "SelectImm" framing was stale), ✅ **Gap A** (`&far_sym`→24-bit: `buildFarAddrWords` + `MO_ADDR24_*` → `#mos24bank`), ✅ **Gap B** (`G_STORE`/`G_LOAD p2`: list `PF` as a value type), ✅ **e2e** (`far_fnptr.c`+`.sh`: `far_leaf(0x5A)==0xFF` MAME+bsnes-jg, bank `$01`, a16-only like far_cast). Regression-clean (corpus 7/7, far_near_call+xcheck PASS). **✅ clang F2 DONE (2026-06-21):** the `far`/`long_call` MOS attribute (Attr.td `MOSFarCall` sharing `ParseKind="LongCall"` with `MipsLongCall`, interrupt-style) + a `CGExpr.cpp::EmitCall` intercept that rewrites a `far`-attributed call into the proven `store volatile ptrtoint(@__mos_far_<sym> AS2)`+`call @__call_indir_far` shape. `examples/65816/far_fnptr.c` rewritten to the **clean single-file `far` surface** (no asm/.set); `far_leaf(0x5A)==0xFF` MAME+bsnes-jg, corpus 7/7, csmith 36/40 0-mismatch, `-verify-machineinstrs` clean. **(a) is fully closed.** **✅ typed far-fn-ptr VARIABLE surface DONE (2026-06-21, [plan](plans/2026-06-21-320-far-fnptr-typed-variable.md)):** `far_fn_t fp = far_leaf; fp(0x5A)` — a `far` bit on `FunctionType::ExtInfo` (DeclOrTypeAttr riding the typedef) → `ptr addrspace(2)` via a ConvertType arm; decay materializes the p2 alias; indirect call ptrtoints the loaded fp. `far_fnptr_var.c` e2e `0xFF` both emulators, csmith 0-mismatch. **✅ `sizeof(far*)==4` DONE (2026-06-21, [plan](plans/2026-06-21-320-far-pointer-sizeof.md)):** `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm for far *function* pointers → `sizeof(FAR*)==sizeof(far_fn_t)==4`; new `far_sizeof.c` (far ptr in a struct) `0xD1` both emulators. **Also fixed a PRE-EXISTING crash it surfaced** (root-caused via revert; independent of the sizeof change): `far_indir` SIGSEGV'd because `isFarSymbol` treated any `.far*`-sectioned symbol as far — restricted the `.far*` section check to **functions** (`isa<Function>`), so a `.far_rodata` datum taken as a near pointer stays 16-bit (far_indir now `0xF3` both emulators); far functions unaffected. Whole far suite (12 ROMs) + corpus 7/7 + csmith 0-mismatch green. **✅ ALL LANDED on `main` (2026-06-21):** the (a) work (backend + F2 + typed-var + sizeof + the `far_indir` fix) folded into `0001` (a16-free), `0004` landed verbatim, and the lone a16-context-entangled (a) hunk (`MOSLegalizerInfo` PF-as-value) split out to new **`0005-320-far-ptr-value-legalize.patch`** — round-trip-proven to reproduce this FF tree exactly over `clang/`+`MOS/`. (The `MOSInsertREPSEP.cpp` delta was FF *stale* vs main's current `0002`, not (a) work — excluded.) See [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md). Full state + recipes: the combined doc. |
| `wt/320-far-tailcall` | `/home/will/llvm-mos-65816-far-tailcall` | #320 **far tail calls** ([plan](plans/2026-06-22-320-far-tail-calls.md)) | **✅ DONE + verified both emulators (2026-06-22).** Compiler-changing worktree (own `vendor/` + `cp -a` warm `build/`). New **`TailJML`** pseudo (→ `JMP_AbsoluteLong` `$5C`, `R_MOS_ADDR24`) + a far arm in `MOSLateOptimization::tailJMP`: `JSL <direct far global>; RTL → TailJML`, gated `isGlobal && .far_` so near→far (`JSL;RTS`) + the bank-0 thunks (external/non-`.far_` symbols) are auto-excluded — conservative (a misclass only misses a win). Far→far tail folds **5 B→4 B** (`jsl`+`rtl`→one `$5C`). a16-independent → regenerated into the worktree's **`0001`** (round-trips `0001..0007`; `MOSLateOptimization.cpp` added to `regen-patch-0001.sh` `FAR_FILES`); **LANDED on `main` (`4adda8b`, pushed) + toolchain/SDK rebuilt + `far_tail`/corpus re-verified 2026-06-23**. **Verified:** `dev/run.sh far_tail` (new; `far_outer` single fold + `far_pick` two-block conditional, execution-discriminating `0xCB`) on **MAME + bsnes-jg**; negative gate in `far_near_call.sh` (thunk tail NOT converted); `+mos-a16` `-verify` clean; corpus 7/7; far suite (12 ROMs) green; csmith fuzz 50 0-mismatch (default+a16 inert). Design + impl each adversarially reviewed by a 3-agent workflow (all ship; one test-strengthening + one comment fix applied). **Worktree RETAINED until upstream merge** (user policy); durable artifacts on `main`. **DISK RECLAIMED 2026-06-23** (`rm -rf vendor/ build/` — ~12 G freed; 12 G→5.2 M); worktree dir + branch kept — to reactivate, `cp -a` `vendor/llvm-mos`+warm `build/` back per [howto §compiler-changing](howto-feature-worktree.md). |
| `wt/321-s32-verify` | `/home/will/llvm-mos-65816-s32-verify` | #321 **verify 32-bit `long`/`int32_t`** ([plan](plans/2026-06-23-321-32bit-long-verification.md)) | **✅ DONE + verified (2026-06-23).** Hardlink/non-compiler worktree (no `vendor/`, no rebuild) — verifies the *existing* s32 codegen (2×s16 + 4×s8↔s32 (un)merge + `__mulsi3`/`__udivsi3`/`__umodsi3`). **(1)** `examples/65816/a16s32.c` + `dev/run.sh a16s32`: folds every s32 hazard into a 32-bit `corpus_result`; full 4-way `host==default==+mos-a16==0x50F2B870` on **MAME + bsnes-jg** (4-byte read; `long` has a default leg). WANT = host-oracle of the identical `uint32_t` arithmetic (`-DHOST_ORACLE`) + runtime drift-guard. **(2)** `tools/a16_fuzz.py` `--s32` track: seeded op-list over 4 `uint32_t` regs interpreted by BOTH a C emitter and the exact Python oracle (lockstep); gated so `--s32` off is byte-identical (30/30); `dev/run.sh fuzz --gen builtin --s32` → **40/40, 0 mismatch**; `dev/fuzz.sh`/`dev/run.sh` plumbing (csmith rejects `--s32`). 2-agent workflow review → **ship** (lockstep checked over 200k randomized op-lists, 0 drift; UBSan-clean). **LANDED on `main` (`0efd62f`, pushed 2026-06-23).** **Worktree RETAINED until upstream merge; DISK RECLAIMED 2026-06-23** (`rm -rf vendor/ build/` — hardlink worktree, freed its dir entries; 646 M→5.2 M); to reactivate, `cp -al` the toolchain/SDK/bsnes-jg back per [howto §Steps](howto-feature-worktree.md). |
| `wt/320-far-cc` | `/home/will/llvm-mos-65816-far-cc` | #320 Inc 4 Ph2: far-pointer calling convention — build all 4 ABI variants (a Imag32 / b Imag16+bank / c A:X+Y / d hw-stack) & measure ([plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md)) | **✅ DONE — `0004` LANDED on `main` (2026-06-21)** (round-trip-proven byte-identical to this worktree's `0004`). Compiler-changing worktree (own `vendor/` + warm-copied `build/`). All 4 ABI variants built + two-emulator measured; **variant (a) Imag32 won** and shipped as stacked **`0004-320-far-cc.patch`** (not `0001` — shares the `AnyRegBank`/`Ac16` line with `0002`); needed `Imag32` ∈ `AnyRegBank` (COPY-through class-constraint), round-trips `0xF3` MAME+bsnes-jg, default byte-identical, csmith 0-mismatch. The measure harness (`dev/farcc_*.sh`, `dev/measure-far-cc.sh`, `dev/probe-cycles.lua`) + the [measurement note](320-upstream-far-cc-measurement-note.md) landed too; losers stayed a measured spike. See [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md). |
| `wt/321-track-a` | `/home/will/llvm-mos-65816-track-a` | #321 xy16 **Track A**: `requiredXWidth` 8-bit-indexed-family hardening ([plan](plans/2026-06-21-321-xy16-track-a-requiredxwidth-indexed-family-hardening.md)) | **✅ DONE — landed `46a39e6` on `main`** 2026-06-21. Compiler-changing worktree (own `vendor/` + warm-copied `build/`). The §3 memory-gated catch-all (`(mayLoad‖mayStore)&&reads X/Y→XW_X8`) **+** §3a index-reading-branch clause (closes the `JMP (abs,X)` `JMPIdxIndir` jump-table residual; user-confirmed in scope). **Verified:** default+a16 byte-identical 75/75 (gating) + xy16 byte-identical 75/75 + csmith 247/445 ROM-identical (inertness); corpus 7/7; xy16 suite + k_isort PASS; fuzz csmith 101–500 **0 mismatch/0 crash** (a seed-488 MAME timeout was QUIET-box contention vs `wt/320-far-cc`, re-verified PASS in isolation); **torture 60/0/0** (de-XFAIL'd rows stay XPASS); `-verify-machineinstrs` clean; `0002` round-trips, 0 foreign content. RED test not constructible (X8-pinned + LTO-narrows) → code-inspection hardening like `55ec505`. Landed in `0002`, **pushed to `origin/main`** (`d551f73`). **Worktree RETAINED — do NOT tear down until the #321/#320 work merges upstream** (user policy 2026-06-21; applies to all worktrees). Durable artifacts already on `main`, so removal loses nothing, but keep it until then. |
| `wt/321-frame-abi` | `/home/will/llvm-mos-65816-frame-abi` | frame-ABI head-to-head: (a) DP-window + (b) stack-relative vs (c) soft-static ([plan](plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md)) | **RESOLVED — CONFIRMED-shelved (NULL)** 2026-06-20: A0 census found 0/13 realistic fns profit (frames are ~unused; locals live in `__rc`). A1–M not built. Durable artifacts (`frameabi_*`) **MERGED to `main`** `f114c42`; CC note ready to post (user-triggered). **Branch RETAINED until notified** (holds the inert, un-landed (a)/(b) `0002` spike) — do NOT tear down. |
| `wt/321-cmpval` | `/home/will/llvm-mos-65816-cmpval` | #321 ordering-as-value branchless materialization — the 16-bit-`rol` form (candidate A) ([plan](plans/2026-06-21-321-ordering-value-branchless-banked.md)) | **RESOLVED — WON'T-DO (net-negative)** `74f04f4` 2026-06-21. Compiler-changing worktree (own `vendor/` + warm `build/`). Candidate A BUILT in full (`ROLAcc16` + `LDAImm16` + `G_CARRY_BOOL16` + `selectCarryBool16` + `legalizeZExt` rewrite; `lda #$0000; rol a` at M16). Correct + `-verify-machineinstrs` clean + DEFAULT byte-identical (gated), **wins in isolated leaves** (uge_v 25→23) **but REGRESSES every realistic a16 program** — a16cmpaudit **+654 B** (both-widths) / **+78 B** (s16-direct-gated), whole a16 corpus **+340 B, ZERO wins** (worse than the 8-bit v1's +262). Diamond is optimal (folds inversion free; M8 tail matches ambient mode; keeps the bool in `X`, not an `Imag16` ZP slot → no spill cascade). Both 8-bit (v1) AND 16-bit (candidate A) forms now closed; **no `0002` change ships** (docs-only close-out). **Worktree TORN DOWN 2026-06-21** (net-negative spike, nothing to merge); the candidate-A implementation is preserved as a durable patch `docs/plans/spikes/2026-06-21-321-ordering-value-candidate-a-spike.patch` (the base for the deferred mode-agnostic lever if ever revived). |
| `wt/320-five-space` | _(torn down 2026-06-21)_ | packed-24 (AS3) — the five-space size-opt space ([plan §Build packed-24](plans/2026-06-21-320-five-address-space-model.md)) | **Increment A DONE; Increment B deferred → worktree TORN DOWN** 2026-06-21 (12G reclaimed, `dev/worktree-teardown.sh`). **A (3-byte TYPE)** built+verified (`AS_FarPacked=3` + datalayout `p3:24:8` + clang `getPointerWidthV` case 3 → `sizeof(packed*)==3`, `table[16]==48 B`, **corpus 7/7**). **B (codegen to USE)** blocked-then-DONE — superseded by `wt/320-packed24-incB` below (Increment B built on post-F2 `main`). Durable artifacts on `main`: Increment A patch `docs/plans/spikes/2026-06-21-320-packed24-incrementA.patch`, fixtures `examples/65816/packed24/`. |
| `wt/320-packed24-incB` | _(torn down 2026-06-22)_ | #320 packed-24 (AS3) **Increment B** — codegen to store/load/deref a 3-byte packed far pointer ([handoff](plans/2026-06-21-320-packed24-incrementB-handoff.md) · [plan §Build packed-24](plans/2026-06-21-320-five-address-space-model.md)) | **✅ DONE + verified 2026-06-21** (compiler-changing worktree off post-F2 `main`; own `vendor/` + warm-copied `build/`). F2 precondition gate PASS first (`sizeof(far*)==4`; far store/load/array/struct legalize clean). **Increment B was NOT the predicted s24-narrowing job** — two findings: (1) `CodeGenPrepare::optimizeLoadExt` crashed on the invalid `MVT::i24` for a 24-bit pointer load → fixed by `getPointerTy(AS_FarPacked)→i32` (the packed ptr's register form IS the 32-bit far form; memory footprint stays 3 B via datalayout); (2) the artifact combiner doesn't look through `inttoptr/ptrtoint`, so route `p3↔3×s8` via `G_MERGE/G_UNMERGE{PFP,S8}` (no `s24`), which **folds** against the adjacent unmerge/merge in every shape clang emits (cast→store, load→cast, packed→packed copy) → no 24-bit value reaches selection. Shipped as stacked **`0006-320-packed24.patch`** (regen: `dev/regen-patch-0006.sh`; NOT folded into 0001 — packed-24 edits files 0004/0005 also touch). **Verified:** `dev/run.sh packed24` (new) `corpus_result=0xF3` on MAME **and** bsnes-jg — far ptr targets **bank $01**, so 0xF3 proves the bank byte survives 3-byte packing; `-verify-machineinstrs` clean; **corpus 7/7**; far suite (bank1/cast/arith/store/call) PASS; `fuzz 50` 0-mismatch; storage **48 B vs 64 B (−16 B/−25%)** for a 16-entry table, ×3 index cost. New e2e `examples/65816/packed24/packed24_e2e.c` + `dev/packed24.sh`, wired into `dev/xcheck.sh`. **Follow-on static-init fix LANDED `a76bf18` (2026-06-22):** static-initialized far-ptr **TABLES** now link (per-entry `R_MOS_ADDR24_SEGMENT_LO/HI`+`_BANK` triple via a `MOSAsmPrinter` retag, not a single `R_MOS_ADDR8`) — `dev/run.sh packed24_table` `0xA5` both emulators, packed 24 B vs far 32 B; + `dev/measure-packed24.sh` (Task A: packed wins, break-even N≥1). **Worktree TORN DOWN 2026-06-22** (`dev/worktree-teardown.sh`, 12G reclaimed; all durable artifacts on `main` — `0006`, the fixtures, the regen/measure scripts). (`far_near_call` failed to *link* here — `__call_near_from_far` lives in the SNES platform lib the warm SDK predated; pre-existing stale-artifact, unrelated — moot now.) |
| `wt/320-near-abs-bank-relax` | `/home/will/llvm-mos-65816-near-abs` | #320 packed-24 productionization **Task B** → a **general 65816 near-abs fix** + the `regen-patch-0001.sh` tooling refresh ([plan](plans/2026-06-22-65816-near-abs-bank-relax.md); origin = [productionization handoff](plans/2026-06-21-320-packed24-productionization-handoff.md)) | **✅ DONE + LANDED/pushed to `origin/main` (2026-06-22).** Compiler worktree (own `vendor/` + `cp -a` warm `build/`). **`0007-65816-near-abs-bank-relax.patch`** (`ff02726`): `MOSAsmBackend::fixupNeedsRelaxationAdvanced` no longer bank-relaxes (abs→long) a **NEAR** (non-`.far`) symbol — every plain-symbol **A-register** near-global access was bloating to 4-byte absolute-LONG (`8f`/`af`/`6f`…, `R_MOS_ADDR24`); X/Y escaped (no long form) and lld doesn't shrink it, so it reached the **linked ROM** (~284 sites in the a16 examples; −1 B each). Gated on the `.far*` section (far stays long); rests on the same **DBR=0** invariant the STX/STY near abs-stores already need → a misclassification can only miss the win, never emit a wrong-bank access. Task B of the productionization handoff (Task A = the *other agent's* `0006` static-init reloc fix; Task C skipped — AS2 has no `__far`/typedef spelling to mirror). **Also landed:** `dev/regen-patch-0001.sh` fixed for the **7-patch stack** (recon+verify now apply full `0001..0007`; `FAR_FILES` = all **25** files `0001` touches, clang+llvm; round-trips the committed `0001` byte-for-byte) (`d5c5946`); the 6 a16 disasm gates made relaxation-form-tolerant (`Xf`→`X[df]`). **Verified:** full `0001–0007` **combined-stack** gate green on **both emulators** — corpus 7/7, packed24 `0xF3`, packed24_table static-init (packed 24 B vs far 32 B) `0xA5`, far suite (7), the 6 a16 gates end-to-end, csmith 50/1 0-mismatch (plan §5). **Worktree RETAINED until upstream merge** (user policy); durable artifacts all on `main`, so removal loses nothing. |
| `wt/321-csmith` | `/home/will/llvm-mos-65816-csmith` | Csmith differential fuzzer — Phases 0–5 DONE (s32 fixed; sampled CI wired `e865dff`) | ~~**MERGED** `dd5616b` → main 2026-06-19~~. **Consolidated reference** (mechanism + state + open follow-ups + the WDC816CC/Plum Hall motivation): [`investigations/csmith-differential-harness.md`](investigations/csmith-differential-harness.md). |
| `wt/321-xy16` | `/home/will/llvm-mos-65816-xy16` | xy16 index-register-mode implementation (Layers 1–5) | ~~**MERGED** `35604c7` → main 2026-06-18~~. ~~**OPEN:** Csmith seeds 247+445 `+mos-xy16`-only runtime miscompiles~~ **✅ RESOLVED `2d8ab51` (2026-06-20, on `main`).** cvise-reduced to an 8-line repro + root-caused: a non-index 16-bit value classed `Xc16` was loaded into X16 and left live across an 8-bit-index op whose narrowing `sep` zeroes the X/Y high byte. Fixed via **approach B** (`selectXY16`'s `G_LOAD16_ABS` emits the direct `LDXAbs16`/`LDYAbs16` only when the value is genuinely used as an index; else lowers through the accumulator). Verified 4-way both emulators + csmith 101–500 (0 mismatch/400) + c-torture 60/60; a16/DEFAULT byte-identical (gated). Arc + refuted A′/#2: [investigation](investigations/65816-xy16-index16-highbyte-clobber.md) · [plan](plans/2026-06-20-321-xy16-seed445-cvise-reduction.md). (Separate latent **Track A** `requiredXWidth` hardening remains a follow-up.) |
| `main` | `/home/will/llvm-mos-65816` | seed-42 regression: `legalizeICmp` EQ-swap leaked into non-a16 path | ~~DONE~~ `51a5bae` |
| `main` | `/home/will/llvm-mos-65816` | indir-dst copy fold (`*p = gg`): corpus trigger check | ~~CLOSED WON'T-DO~~ — 0/6 progs, 0 B, `f52d5b8` |

**2026-09-25 near-store follow-up:** OpenAI Codex’s absolute s16 argument-store
fix is integrated into the main working tree and installed compiler, with validation
complete. `.scratch/near-store` (`wt/321-near-store`) retains the independent
source/build and must be preserved. The [record](plans/2026-09-25-near-s16-store-residency.md)
contains measurements, reproduction commands, and Claude/Codex attribution.
`dev/run.sh a16storebytes` runs its host/default/a16/xy16 runtime differential.
The [indirect-store follow-up](plans/2026-09-25-near-indirect-s16-store-residency.md)
is also complete and integrated: plain setter 13→8 B, return case
15→12 B, plus atomic-store safeguards including a correction to the absolute fix.
Main and worktree compilers match; `a16indirectstore`, `a16storebytes`, and `a16abs`
pass. Census: no larger objects or new failures; full MOS lit retains its four
existing failures (162 pass, 2 unsupported). The pre-indirect compiler is preserved
in `build/indirect-store-review/baseline-install`; the worktree now contains the
combined fixes. See the focused record for hashes, exclusions, and attribution.

## Defect reproduction and closure

Before treating a failure as new, complete the workflow's prior-work audit across
records, reports, Git history, standalone/folded patches, source, and binary.
Extend the existing canonical record for another sighting; preserve its baseline
and append observations/additional runs. New records require a `prior_work`
audit under the pre-commit checker and lightweight defect-evidence CI workflow.

Follow [the evidence workflow](howto-defect-evidence.md) and the mandatory rules
in `AGENTS.md`. New compiler reports/status changes require a `docs/defects/*.json`
record. The active pre-commit hook validates staged evidence and rejects unsupported
fixed claims or changes to captured baselines. Passing current inputs means only
**not reproduced on this build** unless a causal red/green repair is established.

Current follow-up status: [narrow shifts](defects/shift64-narrow-count.json) and
[inline bitboard](defects/bitboard-inline-register-pressure.json) have causal
repair evidence. The [far-memset report](defects/mos-far-memset-wrong-bank.json)
is repaired by existing 0013. Use those canonical records for present work.

**Historical initial recheck:** the [2026-09-25 older-report recheck](investigations/2026-09-25-older-defect-recheck.md)
records 132 successful compiles and narrow-shift/inline-bitboard runtime checks.
Both historical failure reports remain not reproduced, with missing baseline
information explicit; reentrant remains a contract clarification. OpenAI Codex
performed the recheck and enforcement work; original credits are preserved.
`.scratch/older-defect-recheck` holds the isolated inputs/artifacts; main's
`build/older-defect-recheck` retains a copy. Compiler sources were not changed.

## Build / compile / disasm / test — the exact commands

- **Rebuild the toolchain after a `vendor/` edit** (Docker container; incremental): `dev/run.sh toolchain`.
- **`dev/run.sh build` rebuilds the SDK whenever the toolchain changes** (2026-10-01). ninja tracks neither the compiler
  nor the linker binary, so after a toolchain rebuild `build/install` used to keep libraries built by the previous
  compiler (the stamp was the install *path*, which never changes). The stamp in `build/.mos-toolchain` is now
  `<prefix> clang=<sha256> llc=<sha256> lld=<sha256>` ([`dev/toolchain-stamp.sh`](../dev/toolchain-stamp.sh), the one
  place it is defined; [`dev/build.sh`](../dev/build.sh) compares it); any difference wipes the SDK build tree and
  rebuilds it, so a toolchain rebuild is followed by `dev/run.sh build` (or `task release-sdk`) and nothing else.
  `dev/run.sh toolchain-stamp-check` proves the unchanged/changed/legacy-stamp cases against the real stamp block.
  `llc` here is the *installed* `build/llvm-mos-install/bin/llc`. It is not a distribution component, so
  `install-distribution` never refreshed it and it lagged `clang-23` (2026-10-02: installed `cf5355d3…` from 2026-09-28
  vs build tree `6f303945…`); `dev/toolchain.sh` now copies `build/llvm-mos/bin/llc` into the install dir after every
  build, so `build/llvm-mos-install/bin/llc` and `build/llvm-mos/bin/llc` are the same compiler after a toolchain build.
  The other lit tools (`opt`, `llvm-config`, `count`, `split-file`, `FileCheck`, `not`) are still build-tree only; nothing
  reads them from the install dir. The first build after this change finds the old path-only stamp and rebuilds once.
- **Ad-hoc commands in the dev container go through `dev/container.sh -- CMD`** (extra mounts with
  `-v HOST:CONTAINER`). It runs as the host user like `dev/run.sh` does; a bare `docker run` without
  `--user` runs as root and leaves root-owned files under `build/`, which breaks the next host-side
  build or install with `Operation not permitted`. `dev/run.sh` now repairs such files before building
  (`dev/container.sh --fix-owner` does it on demand).
  **Do not** start a second concurrent toolchain build (it clobbers `build/llvm-mos`). **GOTCHA:**
  `build/llvm-mos-install/bin/clang` is a symlink with a *stale mtime*; the real binary is **`clang-23`**.
  Confirm a rebuild took by checking `clang-23`'s mtime advanced (or `nm` it for a new symbol) — a stale
  build silently serving old codegen has burned this project before.
  **SECOND GOTCHA (2026-07-31, fixed 2026-09-24):** `dev/run.sh toolchain` used to install only the
  clang+lld distribution, leaving `build/llvm-mos/bin/llc` (and `opt`/`llvm-mc`/`llvm-objdump`/
  `llvm-readobj`/`llvm-readelf`/`llvm-config`/`count`/`split-file`/`FileCheck`/`not`) to go months stale after a green rebuild — it reproduced an
  already-fixed nondeterminism bug and produced a false 13-vs-9 lit reading during the 0040 work.
  `dev/toolchain.sh` now rebuilds that exact tool set (the ones `llvm/test/CodeGen/MOS` +
  `llvm/test/MC/MOS` RUN lines actually invoke) right after `install-distribution`, in the same
  container invocation, so a toolchain rebuild can no longer leave `llc` behind clang. Run lit itself
  with `dev/run.sh lit [PATHS...]` (refreshes the same tools first, then `llvm-lit -s` against the two
  MOS suites, or the given paths, under `/work`); see `dev/lit.sh`.
- **The upstream-shape validation build (`build/newton-postra-build`, assertions on) is a copy of
  `build/0029-cross-target-build`** and is driven in the container with its source mounted at the
  cached path: `dev/container.sh -v "$PWD/build/newton-postra-src:/work/build/register-exhaustion-src"
  -- cmake --build /work/build/newton-postra-build --target llc --parallel 8`. Its generated files
  were rewritten 2026‑09‑23 to name their own directory (the copy still said
  `0029-cross-target-build`, so the first `CMakeLists.txt` change made ninja regenerate into the
  *other* directory and loop on "manifest 'build.ninja' still dirty"); if a source-list change ever
  needs a reconfigure again, run `cmake -S /work/build/register-exhaustion-src/llvm -B
  /work/build/newton-postra-build` explicitly inside the container first. Lit there:
  `/work/build/newton-postra-build/bin/llvm-lit -s /work/build/newton-postra-build/test/CodeGen/MOS
  /work/build/newton-postra-build/test/MC/MOS` (the site config carries container paths).
- **Never run two `dev/run.sh corpus-a16` (or `corpus`) invocations concurrently — even in separate
  containers.** `tools/a16_fuzz.py`'s `evaluate()` compiles EVERY demo to the same fixed filenames
  (`build/fuzz-work/chk_default.sfc` / `chk_a16.sfc` / `chk_xy16.sfc`, plus their `.map`s), never one
  per demo name, and `build/` is host-mounted into every container (`-v "$ROOT":/work` in
  `dev/run.sh`), so two concurrent runs race on the same physical files on the host. The failure
  signature is unmistakable once you know it: a demo's reported hash for one leg (often
  `+mos-xy16@MAME` or `+mos-a16@bsnes`) is exactly some OTHER demo's *correct* expected hash — e.g.
  `life_sim` reporting `perlin_sim`'s `0xA72D` — because one process's fresh compile got read by the
  other's emulator run. **The corruption also survives non-concurrent re-runs**: a stale/partially-
  written `.sfc`/`.map` pair from the race stays on disk and keeps getting read until you delete it.
  Fix: `rm -rf build/fuzz-work build/fuzz-triage` before trusting a "still failing" `corpus-a16`
  result that doesn't look like a real codegen regression. Found 2026‑09‑15 chasing a false alarm
  after a `setjmp.S` fix (`docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md`).
- **Compile + MIR-verify on the host** (no container needed; `mos-clang` is the built compiler):
  ```
  build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs -c FILE.c -o /tmp/x.o
  ```
  Use the `-Xclang -target-feature -Xclang +mos-a16` form (the driver rejects `-mattr`). Clean exit = OK.
- **Round-trip regression gate (no container needed):** `dev/run.sh roundtrip` — for every
  `examples/65816/*.c` fixture, compiles `-c` (reference) and `-S`+`llvm-mc` (round trip) with the
  same clang and diffs the `.text` bytes, in all three modes (default 8-bit, `+mos-a16`, `+mos-a16
  +mos-xy16`); a divergence is a printer/parser asymmetry (the class patches 0044/0045 fixed — see
  [`investigations/2026-09-24-mos24-far-addressing-completeness-audit.md`](investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#64-nothing-tests-this)).
  `--far-only` narrows to the fast far/packed24 subset for quick iteration (that subset alone missed
  30 of 32 divergent fixtures in the last real regression this gate caught — never use it as the
  release check). Wraps `dev/probe-far-roundtrip.sh` (`dev/roundtrip.sh`). Needs `toolchain` first;
  runs directly on the host like `repro`/`fuzz`, not dispatched through Docker.
- **Disasm / size:** `build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/x.o`;
  `… --section-headers /tmp/x.o` → per-function `.text.<name>` byte size. In an unlinked `.o`, zero-page
  operands all print as `$0` (relocation placeholders) — for symbolic operand names compile to assembly
  (`-S`).
- **MIR:** add `-mllvm -print-after=legalizer` / `-print-before=legalizer` / `-print-after-all` (to stderr).
- **Emulator / differential tests** (Docker; **run on a QUIET box** — concurrent docker/MAME load flakes
  MAME's settle window → false failures that pass on re-run): `dev/run.sh <name>`. The a16 suite:
  `for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done`. Corpus:
  `dev/run.sh corpus` (expect `7/7`). Differential fuzzer: `dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]`
  (**Csmith is now the default**; builtin selectable via `--gen builtin`). With Csmith: expect `0 mismatch,
  0 crash` — a handful of seeds legitimately SKIP (Csmith `main` diverges before `corpus_result` is set,
  so `--gc-sections` drops it). Example: `dev/run.sh fuzz 50 1` → `~46 PASS, 0 xfail, ~4 skip (0 mismatch)`
  on seeds 1–50. Builtin (all 4-way oracle): `dev/run.sh fuzz --gen builtin 50 1` (expect `50/50, 0 mismatch`).
  **Full harness reference** (mechanism, oracle soundness, CI, open follow-ups, and the WDC816CC/Plum Hall
  motivation): [`investigations/csmith-differential-harness.md`](investigations/csmith-differential-harness.md).
  - **The "QUIET box" rule is a MAME/fuzzer rule, not a bsnes-jg one.** The **bsnes-jg leg** (`build/jgxcheck`)
    is *deterministic* — fixed frame count + direct WRAM read, no Lua bridge / settle window — so its
    verdict is load-insensitive (and it needs no SPC700 BIOS). A **bsnes-jg-only** confirmation of the
    second oracle can therefore run on a contended box; run it **serial** (one core) to stay a light
    neighbor to any concurrent MAME. Today the jgxcheck leg only runs *after* MAME inside each
    `dev/a16*.sh`; the planned MAME-skipping `JG_ONLY` guard + `dev/run.sh xcheck-suite` makes the
    second-emulator-only pass a first-class target —
    [plan](plans/2026-06-19-second-emulator-jg-only-confirmation.md).
- **Running `dev/run.sh` from a feature worktree** (the Docker run mounts a single root, so the `CLAUDE.md`
  env-override trick is host-side only): hardlink the prebuilt `build/` in with `cp -al` — full procedure in
  [`howto-feature-worktree.md`](howto-feature-worktree.md).
- **External C suite (gcc c-torture):** host prereq `dev/fetch-torture.sh` (pinned gcc-14.2.0,
  sha256-verified → gitignored `vendor/c-torture/`) + `python3 tools/torture_filter.py` (host-only
  compile/link filter → `examples/65816/torture/{inscope,unsupported}.tsv`, **1288/1779 in-scope** (the
  full suite as of the 2026-06-26 vendoring: top-level + `ieee/` 60 in-scope + `builtins/` 55 as the
  `builtins-multifile` bucket); `mos-clang` runs **directly on the host**, no Docker). Then the emulator differential gate:
  `dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--sample N [--sample-seed S]] [--no-bsnes]`
  (`tools/torture_run.py`; `--sample N` = a seeded pseudo-random subset of N tests, reproducible — the
  sampled-CI selector) — DEFAULT build is the oracle, so a non-PASS default ⇒ **SKIP** and any FAIL is a real defect; known a16 crashes
  (incl. `a16-zp-pressure-overflow`) ⇒ XFAIL. The earlier 17 a16/xy16 runtime miscompiles are all FIXED
  (frame-index `f2d65c2`, `requiredXWidth` `55ec505`, load-fold-across-call `86c2602`); the **full ieee/
  vendoring (2026-06-26) surfaced one NEW `+mos-xy16` defect** — the fp **compare-as-select** ("cmove")
  miscompile, `xfails.tsv` rows `ieee/fp-cmp-8.c` + `fp-cmp-8l.c` + `pr38016.c` (same body, one root cause;
  root-cause+fix is a follow-up). A new FAIL outside those rows is a regression.
  [plan](plans/2026-06-19-321-c-torture-execute-differential-suite.md).
- **xy16 codegen gotcha — LTO narrows small index loads to 8-bit.** The 16-bit-index pseudos
  (`LDAbsXIdx16`/`LDIndirYIdx16`) only survive to the linked ROM when the index is *genuinely* 16-bit-wide
  (e.g. `pr49419`'s `t[x]` double-indirect computed chase). A simple `arr[volatile_short_idx]` legalizes to
  `G_LOAD_ABS_IDX16` per-function (so `xy16ops`/`xy16indiry` PASS, non-LTO `-c`) but **under `--config` LTO it
  narrows back to 8-bit X** when the value provably fits — a valid optimization. Consequence: you can't
  reproduce an X=16-ambient bug with a minimal global-array test through the (LTO) differential harness;
  reach for a computed-index chase or use the c-torture rows.
- Long ops: background them and monitor; don't block on `sleep`.
- **CI** (`.github/workflows/smoke.yml`, `workflow_dispatch`-only): **four jobs.** `smoke` boots the corpus
  in MAME; `xcheck` builds the from-source toolchain (cached) + SDK, then `dev/run.sh xcheck` (bsnes-jg) and
  the secret-gated `dev/run.sh corpus-a16`. **`torture` + `fuzz-csmith`** (added 2026-06-21, `e865dff`) run
  the #321 c-torture (Phase 3) + Csmith (Phase 5) differential fuzzers — both `needs: xcheck` (reuse its
  cached toolchain) and run the same **4-way** gate (host==default==a16==xy16 on MAME + a16 on bsnes-jg).
  `torture` runs in-container (fetches the suite, seeded `--sample`); `fuzz-csmith` runs **host-side** (installs
  MAME, builds `vendor/csmith`, host `MOS_TOOLCHAIN`). A `workflow_dispatch` **`mode`** input picks `sampled`
  (default; seeded subset) or `full` (whole c-torture suite + csmith 1..500); **`sample_seed`** makes the
  subset reproducible. A commented `schedule:` block (auto-selects `full`) is ready for when public. All
  secret-gated (skip — don't fail — without the SPC700 BIOS). Dispatch: `gh workflow run snes-smoke`
  (`-f mode=full` for the whole sweep). **Monitor a run with `task ci-watch` / `dev/ci-watch.sh
  [RUN_ID|--once]`** — streams step transitions + a heartbeat + the final verdict and exits with the run's
  conclusion (background it; GitHub exposes in-progress step *logs* only in the web UI, so ci-watch tracks
  structure, not log text). The `smoke`/`xcheck` legs are proven green: run 27823207476 (2026-06-19, cold
  ~1h46m; cached thereafter); `torture`/`fuzz-csmith` are locally green (sampled 4-way), on-runner dispatch
  pending.

### Soft-stack overlap guard in the bsnes-jg probe — a gate can now fail with "soft stack overlaps static data"

On the SNES platform static data and the C soft stack share low WRAM (`ram` = `$0200-$1FFF`, `__stack = $2000`
in `platforms/snes/link.ld`, stack growing down) and nothing links the two. A program whose frames reach below
the end of static data silently overwrites its own variables: the dither `-O3` hang
([record](defects/snes-soft-stack-static-data-collision.json), [investigation](investigations/2026-10-01-dither-o3-soft-stack-collision.md)),
and rdiff (`e3bb5a62`) before it. **`build/jgxcheck` now measures it on every run**, so every gate with a bsnes-jg
leg fails loudly instead of hanging or reading a wrong CRC.

- **What it reads.** The core carries [`dev/bsnes-jg-wramwatch.patch`](../dev/bsnes-jg-wramwatch.patch), a WRAM
  write watch (empty by default: one compare per WRAM write; `dev/xcheck.sh` applies it and rebuilds the core and
  harness). [`tools/stackguard.h`](../tools/stackguard.h) arms it on `__rc0`/`__rc1`, the soft-stack pointer, and
  commits a new SP **only when the `__rc1` store lands**: `MOSFrameLowering::offsetSP` writes the low byte first, so
  an instruction-boundary sample would see a torn pair up to 255 B *below* the true SP in every epilogue that
  carries (`dev/stackguard-check.sh` has a control for this). Bounds are never hard-coded: `__rc0`, `__stack` and
  `__heap_start` come from `<rom>.elf` (the SDK driver leaves `foo.sfc.elf` beside `foo.sfc`), else the lld map
  `<stem>.map`; end of static data = max(`__heap_start`, end of any allocated section in `[$0100, __stack)`).
  **Margin = min SP − end of static data; negative fails.**
- **How a gate fails.** The verdict is folded into the `SMOKE:` line, because the corpus engine and most gates read only
  that line, and a result that happens to match must not hide an overlap:
  `SMOKE: FAIL off=0x1CE7 len=2 got=0x0000 want=0x80C4 stackguard: soft stack overlaps static data by 231 B (program=dither, config=-O3 default)`
  (or `SMOKE: FAIL (… got=0x80C4 matched, but stackguard: …)`), plus a block on stderr naming the minimum SP, the
  function it was reached in, the bounds source and the ROM, and **exit code 4** when the value check had passed.
  With no overlap (or no ELF/map beside the ROM) stdout, stderr and the exit code are byte-identical to the stock
  harness. Knobs: `JGX_STACKGUARD=0` off, `=require` a missing ELF/map or an unpatched core is itself a failure,
  `JGX_STACKGUARD_ONLY=1` run the frames and report only the guard verdict, `JGX_STACKGUARD_LOG=<file>` append
  one TSV record per run (program, config, status, min SP, static end, stack top, margin, pc, function, bounds source),
  `JGX_PROGRAM` / `JGX_CONFIG` label the message (the config is otherwise inferred from the ROM's name and directory).
  `dev/run.sh` forwards `JGX_STACKGUARD` and `JGX_STACKGUARD_LOG` into the container.
- **Gate wiring.** Any gate that runs `$JGX` and honours its exit status or `SMOKE:` line is covered with no edit,
  *provided its `build/jgxcheck` was rebuilt against the patched core*: `rm build/jgxcheck && dev/run.sh xcheck`
  (a harness linked against a stale core prints `stackguard UNAVAILABLE` on stderr and checks nothing). The corpus
  engine (`tools/a16_fuzz.py check`, i.e. `dev/run.sh corpus-a16`) opts in explicitly: its a16 bsnes-jg leg is asserted
  overlap-free, and the **default and xy16 ROMs, which it value-checks only on MAME, get a stack-only bsnes-jg run**
  (`STACKGUARD_ALL_CONFIGS=0` turns that off). The fuzz/Csmith/torture callers of the same engine run with the guard off
  and stay bit-identical. Gates with no jgxcheck leg (the compile-only probes) and MAME-only gates (`dev/run.sh corpus`) are
  not covered.
- **Regression check:** `dev/run.sh stackguard` (`dev/stackguard-check.sh`) proves the dither `-O3` ROM committed with the
  record fails (231 B, min SP `$1EC7` against `__heap_start` `$1FAE`), the `-O2` ROM does not, a synthetic VLA overlap is
  caught by its ELF even though its result matches, the guard is byte-silent on a clean ROM, the torn-pair control holds,
  and the corpus engine fails an overlapping program in all three configurations. Its link-time legs (5) need only
  `mos-clang` and the installed SDK: the 85f7972a dither is rejected at `-O3` and links with `--defsym=__soft_stack_min=0`,
  the boundary is exact (`=82` links, `=83` fails; a synthetic gap of 256 B links, 254 B fails), each of the five installed
  SNES linker scripts enforces it, and the generated platforms carry the lines. `SDK_INSTALL=<dir>` points it at another SDK
  (run against a pre-reserve SDK it fails 8 legs, which is the red baseline).
- **Sweep (2026-10-01):** `dev/stackguard-sweep.py corpus|demos|report` runs the guard across every corpus program
  (83 x default/a16/xy16, `-Os`) and every demo gate (154, `JG_ONLY=1`) and prints the margins smallest first.
  **608 runs, no overlap.** Margins: median 7,228 B; 2 under 256 B (dither 76 B at the pre-move source, msquares 246 B),
  4 in 256-1,023 B, 192 in 1,024-4,095 B, 407 at 4,096 B or more. 207 runs never touched the soft stack. The deepest
  soft stacks are the two ISR demos (`irqgate` 569 B, `dpbank` 305 B, both in `nmi`; an ISR reserves 256 B extra for the
  torn-SP case). Records, per-program table and toolchain identity:
  [`evidence/2026-10-01-snes-soft-stack-collision/guard-sweep/`](defects/evidence/2026-10-01-snes-soft-stack-collision/guard-sweep/README.md).
  The link-time reserve (the record's proposed fix 2) can size its `__soft_stack_min` from these depths.
- **Link-time reserve (2026-10-01): every SNES linker script requires `__soft_stack_min = 256` bytes between static data
  and `__stack`.** `platforms/snes*/link.ld` (and the scripts `tools/snes-cartcanary.py emit-platform` generates) carry
  `PROVIDE(__soft_stack_min = 256);` and `ASSERT(__heap_start + __soft_stack_min <= __stack, …)` right after `__stack`
  (rationale comment in [`platforms/snes/link.ld`](../platforms/snes/link.ld)). A program that leaves less fails at link
  with `soft-stack reserve violated: static data ends at __heap_start, leaving fewer than __soft_stack_min bytes below __stack (shortfall = __heap_start + __soft_stack_min - __stack; …)`:
  the shortfall is `__heap_start + 256 - $2000` (the map and `llvm-nm <rom>.elf` give `__heap_start`). Fixes: move big
  buffers out of low WRAM (the dither fix, `07f4fe2f`, put them behind the WRAM port in high WRAM), shrink
  `.data`/`.bss`/`.noinit`, or `-Wl,--defsym=__soft_stack_min=N` for one link (0 turns it off). `__heap_start` is the end of
  `.noinit` and so of all static data in low WRAM (`.data`, `.bss`, `.noinit`); only a `.ram`-section user would be
  missed (none exists). **It bounds the static side only**: it proves nothing about how deep the frames go, so a program
  with 300 B of room and 400 B of frames still collides; the runtime guard above is what measures depth, and only in
  gated runs. 256 B was chosen because the smallest gap of the 279 programs swept is msquares at 338 B (the deepest soft
  stack is `irqgate`, 569 B, which has far more room). The installed scripts are `build/install/mos-platform/<p>/lib/link.ld`,
  refreshed by `dev/run.sh build`; `dev/run.sh stackguard` links the evidence's 85f7972a dither (82 B of room) and the boundary
  cases against them.

### Never force-blank outside boot — and the v-blank budget

**Standing rule for every SNES program here: do not blank. Clear the screen instead, and transfer to
VRAM/CGRAM/OAM only during h-blank and v-blank.** The one permitted force-blank is the boot window —
the console powers on blanked (`INIDISP = $8F`), drawables do their bulk `REG_VMDATA` setup inside it,
and the first `display_frame()` releases it. It is never re-asserted.

Why it matters concretely: `display_frame` used to bracket the DMA in force-blank so an over-long
transfer "succeeds at any vcounter". A flush that outran the remaining v-blank then left force-blank
asserted into active display, **blanking the top scanlines** — a visible flicker. That was a real
shipped bug (`1dd9317`).

With force-blank gone, staying inside the window is the queue's job:

- **`UPQ_VBLANK_BUDGET` = 5100 B** — 38 v-blank lines × 1364 master cycles = 51,832, at 8 master
  cycles/byte = 6,479 B, less ~20% for per-job setup. `upq_flush` spends at most this much and leaves
  the rest queued; a job bigger than the budget splits and resumes via `UpqJob.sent`.
- The `RDNMI` clear sits **after** `scene_emit`: emit can span a v-blank, and consuming that stale
  flag would start the flush in active display.
- **`display_add` must precede the first `display_frame`** (`reserve()` bulk-writes VRAM). `Display.late_add`
  records a violation.

**Gate: `JGX_BLANKSCAN=1 build/jgxcheck <rom> <db> <off> <len> <want> <frames>`** — scans every frame
for leading all-black rows of the active picture and fails (exit 3) on a one-frame spike above *both*
neighbours (`JGX_BLANKSCAN_ROWS`, default 4). One emulator run covers all frames. Comparing against
the *higher* neighbour is deliberate: the title's gravity exit ramps the black band 0→224 over ~40
frames, and every frame of that ramp beats its predecessor without being a local maximum. Run it on
any demo whose upload volume or frame pacing changes.

A spike must also sit on a **quiescent baseline** — the window `±JGX_BLANKSCAN_WIN` (default 5)
around it, excluding the candidate, must span less than `JGX_BLANKSCAN_QUIET` (default 8) rows.
Excluding the monotonic ramp was not enough: an **apex**, where a descending and an ascending ramp
meet, is a local maximum by construction. `lsystem` hit exactly that — `canvas_clear()` dirties all
256 tiles while `CANVAS_FLUSH_TILES` caps the flush at 64/frame, so the clear crawls top-down over 4
frames while the regrowth restarts from the trunk. Locally that apex is indistinguishable from bleed
(shoulders 143/142, a 6-row excursion between them), so no threshold on the 3-point comparison can
separate them; only the wider window shows the sweep. **Know the cost:** a genuine bleed inside a
wipe/fade/scene change is now missed. Suppressions print their window spread, never silent.
`JGX_BLANKSCAN_SELFTEST=1 build/jgxcheck` (no ROM needed) pins the discrimination on synthetic
series. See [the plan](plans/2026-07-30-blankscan-quiescence-gate.md).

**The conversion list is now closed (2026-08-05).** The live half — `snesgfx/m7title.h` and the Mode 7
demo `main()`s — was converted to the handoff contract below. The other half never needed converting:
`snesgfx/splash.h` (`splash_show`) and `splash16` in `title_layer.h` had **zero consumers**, having been
superseded twice over — `splash_show`'s call sites were replaced by the BG2 `TitleLayer` in `b6ef256`,
and `splash16`'s by `m7splash_begin`/`m7splash_end` in `8ac159f` ("align title effects with display
modes"). Neither helper was itself contract-violating; the frames the contract recovers live in *caller*
code, and there were no callers. Both surfaces were **deleted** rather than converted, so nothing regenerates
the item. See [the close-out](plans/2026-08-05-splash16-forceblank-conversion.md).

**`snesgfx/m7title.h` + the Mode 7 demo `main()`s — converted 2026-08-05.** The old wording here said
they "re-open the window". They do not: `m7splash_end()` returns with `INIDISP = $80` still asserted
and a following `display_init()` re-asserts an *already-open* window at zero frame cost. The black
panel was purely the **wall-clock of the work executed inside the window** — measured at **720 frames
across eight demos**, worst `mandel-float` at 350 (5.8 s of soft-float ground in the dark, directly
against its own source comment) and `mandel-double` at 215. The fix is the **handoff contract** now
written at the top of `snesgfx/m7title.h`: compute goes *between* `m7splash_begin()` and
`m7splash_end()` behind the visible title; only PPU registers and DMA may sit between `end()` and the
blank release; progressive reveal goes after the release, in v-blank. Total is now **22 frames**, and
the floor — the Mode 7/CGRAM mode switch that genuinely needs blanking — measures **1 frame**.

**Gate: `dev/m7blank.sh --gate`** — entropy-pinned `JGX_FRAMESCAN` timeline per demo, reconstructing
every frame from the change events, checked against a committed per-demo force-blank budget (exit 4
when over). `--probe` builds with `-DM7BLANK_PROBE` so `m7_show()` / `display_frame()` paint CGRAM[0]
white at the release: without it a picture scan cannot separate "still blanked" from "released onto
black art", and several demos bloom onto a deliberately black backdrop (`buddha`'s "no hits"). The
demo set is derived from `grep -l m7splash`, not hardcoded — the "seven" above was already stale at
twelve. See [the plan](plans/2026-08-05-mode7-splash-forceblank-floor.md).

### Title-card tooling (host-side, not `dev/run.sh` targets)

The demo title card (`examples/snes/snesgfx/title_layer.h`) has two failure modes no WRAM gate value
can see, so both get their own check:

- **`dev/title-charset.sh`** — every title string in `examples/snes/*.c` against the glyphs actually
  drawn in the *generated* `font8.h` (line0) / `font16.h` (line1). A character with no art renders as
  a **space, silently**; that shipped for months (`G_FCOPYSIGN` read as `G FCOPYSIGN` in six demos,
  `Z^2 + C` lost its caret). Exits non-zero on any offender; `--list` shows empty font slots. **Run it
  before the gate when adding a demo** (the `snes-demo` skill lists it as a required step). Fonts
  cover ASCII `0x20..0x5F` with **no empty slots**; `_title_glyph` folds `a-z`→`A-Z` at render time,
  so only `` ` `` `{` `|` `}` `~` are unrenderable. Fix by drawing the glyph in
  `tools/gen-font{8,16}.py` and regenerating — slots inside the range cost **zero bytes** (the tables
  are fixed-size over the whole range). Extending past `0x5F` is +512 B / +2048 B and widens the
  title's VRAM clobber by 5 KB — bundle that with the eventual lowercase glyphs.
- **`dev/title.sh [FRAMES...]`** — builds a probe ROM that runs only `title_begin16`→`title_end` and
  snapshots it at each frame into `build/title-sheet.png` (labelled contact sheet). Frame N means the
  same animation instant every run, which a real demo's pre-loop compute would smear.
  `TITLE_LINE0` / `TITLE_LINE1` override the strings. Use it whenever the banding or motion changes:
  the regression class is a line's *wrapped* tilemap copy bleeding into the other line's HDMA band
  (both lines arriving from both edges), and it is only visible mid-slide.

### Verifying a published web player page headlessly (Playwright) — the gotchas

Both sites run the ROM in `@wbniv/bsnes-jg-player` (`app.js` + a bsnes-jg WASM core). When a plan
step says "test live navigation on the published page", drive it with the cached Playwright
(`~/.npm/_npx/*/node_modules/playwright`, Chromium headless) and read the **ROM's own state**, not
just pixels. Learned the hard way on the nav-chevron plan (2026-08-04 → 2026-09-14 records):

- **Read WRAM through the player.** `window.__bjg` is the Emscripten module; `__bjg._bjg_wram()`
  + `__bjg.HEAPU8` is the same MainRAM pointer the fidelity self-check uses. Symbol offsets come
  from `build/<rom>.map` (`gallery_canceled` `0x3f`, `gallery_current_asset` `0x472`, …). A mean-luma
  "did the screen cut" heuristic is fine as secondary evidence but cannot tell *why* nothing moved.
- **`page.keyboard.press()` is down+up within ~1 ms** — the ROM latches the pad once per NMI, so on a
  loaded host (the headless core ran at 8–12 fps at load ≈ 24) the press is simply never sampled.
  Hold it: `keyboard.down` → 150 ms → `keyboard.up`. Chevron clicks are safe because the player
  itself holds the synthetic bit for a 120 ms pulse.
- **Count emulated frames, not wall-clock.** Wrap `__bjg._bjg_set_input` (called once per core
  frame) to count; budget the observation in frames (the console gate's press@1000 → index@2503 is
  the reference) or the run silently under-observes on a slow host.
- **Settle past the title card.** The gallery shows `PACK UNPACK LZSS GALLERY` (mean luma ≈ 22) for
  the first ~10 000 frames and ignores navigation there; wait for a held artwork (luma > 40, stable)
  before injecting input, or every condition reads "no cut".
- **"No errors" is not evidence the ROM started.** The player's boot `.catch` writes its error into
  `#banner`, and the async `showProvenance()` then **overwrites** it — so check `#status` reaches
  `running <rom>.sfc` and that the `.sfc` was actually requested. The indri.studio freeze
  (player `100f4b51…`: `clearTouchNav` closure-scoped, called from `stopLoop()` → `ReferenceError`
  on every boot) hid behind exactly that.
- **Compare the two sites' `ENGINE_VERSION` first.** Same package `1.0.0` label, different bytes:
  the sync CLI stamps per-file sha256s, and a site whose `pnpm-lock.yaml` pins an older
  `github:wbniv/bsnes-jg-wasm#npm-package` tarball commit is one `pnpm update @wbniv/bsnes-jg-player
  && pnpm run sync-engine` away from the fix — no package release needed if `origin/npm-package`
  already carries it.
- Keep the harness scripts in the scratchpad *and* paste them into the plan record; the 2026-08-04
  harnesses were lost and had to be rebuilt for the re-run.

## The correctness gate + micro-test pattern

The bar is the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. New value-level behavior gets a
`examples/65816/a16<name>.c` + `dev/a16<name>.sh` micro-test (pattern: a `corpus_result` the test asserts
across host/default/a16 on both emulators, often with a disasm gate, e.g. native `cmp` present and no 8-bit
`cpx/cpy`), wired into `dev/run.sh`, and is exercised by the fuzzer (`tools/a16_fuzz.py`). Use
`examples/65816/a16eqval*.c` + `dev/a16eqval*.sh` as templates. Close the script with
`emu_verdict "$rc" "<pass detail incl. an emulator-agreement clause>"` (from `dev/_emu.sh`), **not** a
hand-rolled `echo "RESULT: …"` — the helper prints `RESULT: FAIL`/`PASS` and, under `JG_ONLY`
(`dev/run.sh xcheck-suite`, the bsnes-jg-only pass), rewrites the "both emulators" claim so a MAME-skipped
run stays honest.

**Gating discipline — the fuzzer guards the DEFAULT build too.** Every `+mos-a16` change must be gated so it
*cannot* alter non-`+mos-a16` codegen — and that includes **operand canonicalizations / helper predicates**,
not just instruction defs and selection. A green a16 suite is **not** sufficient: the differential fuzzer
compiles each program *both* default and `+mos-a16` and compares to the host oracle, so an a16 helper that
leaks into the 8-bit path surfaces as a `default@MAME ≠ host` mismatch. Concrete bite (seed-42, fixed in
`0002` 2026-06-18): an EQ-only operand swap in `legalizeICmp` was guarded by a predicate that did **not**
check `hasAccum16` (nor `Pred==EQ`), so a non-EQ `<`/`>` compare in the *default* build hit
`std::swap(LHS, RHS)` and reversed the comparison →
[plan](plans/2026-06-18-321-seed42-legalizeicmp-swap-fix.md). Gate on the **same predicate that enables the
feature behavior** (e.g. `NativeS16Eq` = `hasAccum16 && Type==S16 && Pred==ICMP_EQ`), not a looser
operand-shape test.

**Attributing a fuzzer/regression finding to a patch (or single hunk) — isolated-worktree + ccache
bisection.** When a differential mismatch must be pinned to a specific patch/hunk and MIR diffing is
inconclusive (state-sensitive bug, byte-identical post-legalize IR), bisect with *builds*: spin a detached
worktree of `vendor/llvm-mos` at pristine upstream (`git -C vendor/llvm-mos worktree add --detach <dir>
<HEAD-sha>`), `git apply` a chosen *subset* of `patches/llvm-mos/*.patch` hunks (filter a patch to specific
files/hunks with `awk` on the `diff --git` / `@@` headers; revert one with `git apply -R`), build into a
**separate** `build/` dir with `CCACHE_DIR=$PWD/build/.ccache` reused (each incremental rebuild is minutes,
not the 30–90 min cold build — LLVM TUs hit ccache, only the changed MOS target recompiles + relinks), and
run the one-program differential (`dev/run.sh fuzz 1 <seed>`) on each. The unpatched `/opt/llvm-mos` in the
dev container is the correct-value oracle. **Never** build a subset into the shared `build/llvm-mos` (it
clobbers the toolchain other agents use). Trust the build result over any plausible mechanism — two
"obvious" causes (a concurrent edit; the register topology) were each refuted this way before the real
one-line cause was found.

## Measurement methodology (size/speed claims)

- Compare **native-`+mos-a16` vs 8-bit-`+mos-a16` on the *same* C shape** — toggle only the feature gate.
  Never compare `+mos-a16` vs non-`+mos-a16` (that conflates the value's ALU/load codegen with the change
  under study). Often the *current* `+mos-a16` output already IS the 8-bit baseline for the shape (the gate
  doesn't fire yet) — capture it, make the change, rebuild, diff.
- Decide on **bytes** (the `-Os` target), cycles as tiebreaker; report both. Hand-count 65816 cycles if
  needed (DP=0 assumption; the *delta* is usually insensitive to the DP penalty).
- **Addressing/DBR contract (don't over-generalize the `inc abs` note).** Near data is bank-0 low WRAM
  ($0200–$1FFF). The **8-bit `abs` path is DBR-relative** (`R_MOS_ADDR16`, reads `DBR:addr`); the **native-16
  `long` path is DBR-independent** (`R_MOS_ADDR24`). So data access is a *mix*, not uniformly
  DBR-independent. The crt0 establishes **DBR=0 explicitly** (`phk; plb` in `.init.50`) so the 8-bit `abs`
  globals + MMIO writes land in bank 0; gate `dev/run.sh crt0native`. See
  [native-mode-crt0-xy16 plan](plans/2026-06-18-321-native-mode-crt0-xy16.md). Full power-on→`main()`
  walkthrough: [snes-bootup-sequence](snes-bootup-sequence.md).
- **Measure in realistic 16-bit-ambient context, not just isolated leaf functions.** A leaf function pins
  the ambient accumulator mode at 8-bit and over-charges `rep`/`sep` to the op under study; real `+mos-a16`
  code holds `M=0` across sustained compute. (This regime difference has flipped measured conclusions
  here.)

## Navigating the backend (grep — don't trust line numbers; `vendor/` is multi-agent)

Line numbers drift because `vendor/` is edited by multiple agents — **grep for symbol/string anchors.**
Under `vendor/llvm-mos/llvm/lib/Target/MOS/`:

- `MOSLegalizerInfo.cpp` — GISel legalization: `legalizeICmp`, `legalizeAddSub`, `legalizeLoadStore16`, the
  `+mos-a16` gates (e.g. `NativeS16Eq`); also the `hasAccum16()`-gated s32↔s16 rules
  (`G_ANYEXT`/`G_TRUNC`/`G_MERGE_VALUES`/`G_UNMERGE_VALUES`) so `+mos-a16` handles `int32_t`/`long`. **Wide
  scalars under a16 narrow to s16 (not s8), so s32 is 2×s16** — new wide merge/unmerge shapes need rules:
  the direct **4×s8→s32 `G_MERGE_VALUES`** is custom-legalized (`legalizeMergeS32FromBytes`) into the legal
  2-level form (`merge→s16 ×2, then →s32`) because `selectMergeValues` only takes a 2-source merge. The
  symmetric **s32→4×s8 unmerge** is custom-legalized the same way (`legalizeUnmergeS32ToBytes`, landed
  `cbc31da`, refined `2bfe4f3`) and is one of the hottest custom rules in the backend — an instrumented
  sweep of the 112 corpus slices measured **385 fires across 52 slices** (sources: `G_MERGE_VALUES` 208,
  `G_SEXT` 145, `G_ZEXT` 32). It forms only when a narrower value is **extended to s32, run through
  arithmetic, then split into bytes** — never from an already-32-bit source, since the artifact combiner
  folds unmerge-of-load/constant/merge first. Regression-gated hermetically by `dev/run.sh a16unmerge`.
  *(This line previously read "still `unsupported` (no seed hit it yet)" — stale since `cbc31da`; that
  stale text is what mis-justified Round 7's #122, withdrawn 2026-08-03.)* *Gotcha:* a whole-module frozen
  `.ll` is a poor regression fixture for these — it over-triggers by compiling runtime fns (`__adddf3`, s64)
  with `+mos-a16`, which the real link doesn't; use the deterministic Csmith seed as the gate instead.
- `MOSInstructionSelector.cpp` — selection: `select*`, the `m_CmpNZ*` / `CmpNZ*_match` matchers, operand-fold
  helpers (`getImm16Operand`, `foldableAbsLoad16`/`foldableIndirLoad16`). **A16 load-fold helpers MUST guard
  against intervening clobbers:** folding a load into a later ALU/compare operand re-reads memory at the
  *user's* point, so `noStoreBetween(Def,User)` bails if any `mayStore`/`isCall` sits between (else a load
  folded across a call reads the mutated value — the pr34768 miscompile). Upstream 8-bit folds use
  `shouldFoldMemAccess` (AA-precise) for this, but it bails on *volatile* loads which the #321 corpus folds
  single-use; `noStoreBetween` is the volatile-tolerant tailoring. Any new a16 fold helper must replicate it.
  **Upcoming — Phase 2 greenlit 2026-06-20:** the split will be unified in `canFoldLoadIntoUser(Dst,Src,AA)`:
  volatile-bail becomes a single-use clamp; `foldableAbsLoad16`/`foldableIndirLoad16`/`noStoreBetween` are
  deleted. Phase-1 instrument-and-count found 43 volatile-recovery sites + 7 AA-precision sites across 2615
  compiles. Until landed: "any new fold helper" still means `noStoreBetween` + single-use.
  [plan](plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md).
- `MOSInstrPseudos.td` + `MOSInstrInfo.cpp` — pseudos: `CmpBrImag16` (Imag16-resident LHS),
  `CmpBrImm16` (const RHS), `CmpBrAbsAbs16` (both-global), `CmpBrAbsImm16` (global LHS + const RHS),
  `CmpBrImagAbs16` (computed LHS + global RHS); + their post-RA expansion (`expandCmpBr16`).
- `MOSInsertREPSEP.cpp` — M-flag (accumulator 8/16) **and** X-flag (xy16 index 8/16) mode tracking across
  blocks (parallel lattices + the `rep`/`sep` placement). `requiredXWidth(MI)` is the per-instruction
  index-width classifier — it must return `XW_X8` for every op that reads/writes an index reg (X/Y) at
  8-bit intent (loads/stores/transfers/push-pull **and** the value ops: compares `CMPImm`/`CMPImag8`/
  `CMPAbs` and register `INC`/`DEC` of X/Y) so they don't run in a stray X=16 ambient. Adding a new
  8-bit index op? Add it here. Whole file is `hasAccum16()`-gated; X-lattice work is `HasIndex16`-gated.
- `MOSLateOptimization.cpp` — post-RA peephole: `threadAccum16` eliminates redundant `STAImag16 R;
  LDAImag16 R` round-trips between dependent native-s16 ops (A16-threading Phases 0–1–1.5 done).
- `MOSRegisterInfo.td` — register classes: `GPR` = {A,X,Y}, `Ac16` = {A16}, `Imag8`/`Imag16` = the
  zero-page imaginary registers (`$rc*` / `$rs*`).

Harness/tests: `examples/65816/`, `dev/run.sh` + `dev/*.sh`, `tools/a16_fuzz.py`.
