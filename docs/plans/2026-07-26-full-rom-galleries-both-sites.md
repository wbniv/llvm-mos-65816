# Full ROM galleries on both biohack.net and indri.studio

## Context

User asked "are all the SNES ROM demos published?" — audit found 111/111 curated demos live on
[biohack.net/snes/](https://biohack.net/snes/), with 3 source files unaccounted for:

| `examples/snes/*.c` | Status |
|---|---|
| `buddha.c`, `invaders.c`, `wireframe.c` | already published, different slugs (`buddhabrot`, `space-invaders`, `3d-wireframe`) |
| `hello.c` | M0 smoke test (solid-green + WRAM sentinel) — **excluded**, not a showcase demo (user confirmed) |
| `mandel-oop.c` | `snesgfx` OOP-vs-procedural verification twin of `mandel-display` — real visual demo, just never published |
| `mandel-display.c` | the canonical M2 far-pointer tester — published, but only on **indri.studio** (single embedded player), not biohack.net |

**Also found while spot-checking URLs: 4 demos are live but off-convention.** `bitweave`,
`uarteye`, `pcooker`, `borrowlad` (the newest batch, Round 6 Clusters D/E) sit at top-level
`src/pages/{slug}.astro` → `/{slug}/`, not `src/pages/snes/{slug}.astro` → `/snes/{slug}/` like
every other demo. This is the exact same drift the 2026-07-02 "Location sweep" fixed for 14 earlier
demos (`docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md` §Published-location
audit) — it just crept back in for demos added after that sweep. **Currently live and broken**:
`/snes/index.astro`'s gallery cards link every demo to `/snes/${slug}/`, so these 4 cards 404 from
the gallery today. Full audit confirms exactly these 4 (plus `404.astro`/`claude.astro`, which are
legitimate non-demo pages, not strays). Fixed as part of Step 1 below.

indri.studio's current SNES surface is structurally different from biohack.net's: one embedded
player (`EmulatorEmbed.astro`, hardcoded to `mandel-display`) inline on the `/apps/llvm-mos-65816/`
product page, plus an orphaned standalone `/apps/llvm-mos-65816/play/` page. No gallery, no
per-demo pages, no index. biohack.net is a true gallery: `/snes/` index (card grid, category
filter chips) + one `/snes/<slug>/` page per demo (111 hand-written `.astro` files from
`page-template.astro`).

**User's decision (asked via `AskUserQuestion`):** build indri.studio out to a **full per-slug
gallery mirroring biohack.net's layout and function** (not just a picker bolted onto the single
player) — same URLs-per-demo shape, same player-plus-controls-plus-verify page anatomy — restyled
to indri.studio's brand (grey + neon-purple, Tailwind, `Base.astro`). **Keep the existing
`llvm-mos-65816.mdx` intro text and `EmulatorEmbed`** on the product page; expand the copy to
explain why 113 demos exist and link to the new gallery. `hello.c` stays unpublished everywhere.

**Target: 113 demos, live and identical in content on both sites** (111 existing + `mandel-display`
+ `mandel-oop`).

**Update 2026-07-26 — the fork is now public.** `wbniv/llvm-mos-65816` flipped from private to
public on GitHub (secrets sweep run first: no credential patterns, no `.env`/key files tracked,
`docs/transcripts/` — the one thing this repo's `CLAUDE.md` says never commit — is untracked, so it
wasn't exposed; clean). **Confirmed live**: `curl -s https://api.github.com/repos/wbniv/llvm-mos-65816`
→ `"private": false, "visibility": "public"`. Reason: also serves as a concrete followup to an
Anthropic security block hit in a *different* session while bisecting when certain compiler bugs
were introduced — the user wants the full commit history public and linkable so it can be
referenced in that report. This directly simplifies the bug-provenance section below: gallery pages
now link straight to the fixing commits instead of naming the patch with no link.

## Bug provenance — compiler bugs these demos found

Several Round-6 demos exist specifically to re-stress a previously-caught backend bug from a new
angle; a few originals (`qsortviz`) caught the bug themselves. These deserve a "this demo caught
a real compiler bug" callout on their gallery page. **Scope, per user direction: only bugs in the
*pre-existing* llvm-mos/65816 compiler — not incompleteness in code *we* wrote while building the
`+mos-a16`/`+mos-xy16` accum16 feature itself** (that's expected in-progress work, not a "the
compiler was already broken" finding). Of the 6 fork patches referenced by demo copy in `TODO.md`,
that excludes two:

- **`0002`'s xy16 REP/SEP fix** (demos `lsystem` #23, `ovmove` #93, `rotslab` #94, `permscat` #95,
  `ropeedit` #96) — the defect is in `MOSInsertREPSEP::placeIntraBlock`, **a pass we wrote** for the
  `+mos-xy16` feature. Our own new code, not a pre-existing compiler bug. **Excluded.**
- **`0017`'s a16 s64 unmerge/anyext glue** (demo `dhmix` #61) — upstream-contribution-status.md is
  explicit: "the #321 fork added s32↔s16/s8 glue but not the s64 level" — again our own new code's
  incompleteness, not the existing compiler. **Excluded.**

The remaining 4 patches are genuine pre-existing-compiler bugs (analogous to the two already-merged
upstream fixes, #562/#563 — also discovered via our #321 testing, but the defect lived in
pre-existing generic code, not code we wrote): `0010`'s register coalescer and `0016`'s
G_SCMP/G_UCMP legalizer gap are bugs in **default-8-bit / fully-generic** codegen, unrelated to our
feature; `0011`/`0012` live in pre-existing generic scavenger/MC-lowering code that our new
16-bit-accumulator code paths happened to be the first to exercise.

**None of these 4 are posted upstream yet** (`docs/upstream-contribution-status.md`: all "not yet
pushed... to mint"), so every fix link below is a commit on **our fork**
(`github.com/wbniv/llvm-mos-65816` — **now public**, see the update note above) rather than a
public upstream PR. Since the fork is public, these links resolve for site visitors — the gallery
pages link the fix commit directly alongside the bug/fix prose (no more "name the patch, no link"
restriction).

| Patch | Bug (pre-existing compiler) | Fix | Fix commit | Demos | Reduced repro |
|---|---|---|---|---|---|
| **`0010`** coalesce-rotate-Ac | Default-8-bit (**no** `+mos-a16` needed) silent miscompile: the register coalescer merges two shift/rotate-referenced values into the A-only `Ac` class, stranding a loop-carried CRC byte in `Y` while the back-edge `ROL` reads a stale `A` — an inlined CRC16 bit loop under register pressure. Both `-verify-machineinstrs`/`-verify-coalescing` pass clean (silent, not a crash). | `MOSRegisterInfo::shouldCoalesce` refuses the join when `NewRC==Ac` and both operands are rotate-referenced, + a `-run-pass=register-coalescer` lit test. | [`b75dd46`](https://github.com/wbniv/llvm-mos-65816/commit/b75dd46) | `crcwall` #105, `lfsr2` #106, `bitweave` #107, `uarteye` #108 (Round 6, Cluster D — 4 angles on the same coalescer bug) | No committed minimal repro (a cvise-reduced `min.c` lived only in `/tmp/crc-fuzz/`, not checked in) — [investigation](investigations/2026-06-26-coalesce-rotate-ac-fix-validation.md) has the fuzzing methodology; the `crcwall` demo itself is the checked-in regression guard. |
| **`0011`** scavenger live-`$p` | `+mos-a16`/`+mos-xy16` backend **crash**: a 16-bit compare keeps N/Z live across a frame-carry spill, forcing the carry-flag pseudo-register `$p` to be preserved across an *unbalanced* range — but `$p` (register class `Cc`) has no GPR home, so `saveScavengerRegister` emits an illegal `STImag8 $p` / reads an undefined `$p`. The scavenger logic predates accum16; our new 16-bit compare pattern was the first to hit its `$p`-has-no-home gap. | Route `$p` hard-stack-neutrally through a dead index register into `RC17`; drop the stale `assertNZDeadAt`. | [`a320cbd`](https://github.com/wbniv/llvm-mos-65816/commit/a320cbd) | `pcooker` #109 (Round 6, Cluster E) | [`examples/65816/a16scavnz.c`](../../examples/65816/a16scavnz.c) — `dev/a16scavnz.sh` runs it as a standalone gate (`0x22A6`). |
| **`0012`** `LDCImm` set lowering | Pre-existing `MOSMCInstLower` switch over the `LDCImm` immediate only handled `0`→`CLC` and `-1`→`SEC`; a *set* i1 carry reaching MC as literal `1` (e.g. the carry-in for a 16-bit `SBC`) hit `llvm_unreachable` (asserts-abort; release-build UB that happened to still emit `SEC`). Surfaced once `0011` let compilation reach MC lowering. | Lower any nonzero i1 as `SEC` (differential-neutral). | [`a320cbd`](https://github.com/wbniv/llvm-mos-65816/commit/a320cbd) | `borrowlad` #110 (Round 6, Cluster E) | Inline 2-line repro in [`docs/upstream-ldcimm-set-lowering-pr.md`](../upstream-ldcimm-set-lowering-pr.md#reproduction): `volatile unsigned short a=0xDC13,b=0x1234,out; int main(void){out=(unsigned short)((unsigned)a-b); for(;;){}}` — not separately checked in as a file. |
| **`0016`** G_SCMP/G_UCMP legalize | **Fully generic gap, all 3 modes** (default-8-bit too — nothing to do with accum16): libc `qsort`'s standard spaceship-comparator idiom `(x>y)-(x<y)` canonicalizes to `G_SCMP`, which `MOSLegalizerInfo` had **zero rule for**, at any width — `unable to legalize G_SCMP` abort, every mode, both `-fno-lto` and LTO. | One line: `getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();`, routing to LLVM's built-in `lowerThreewayCompare`. | [`3c2c7a5`](https://github.com/wbniv/llvm-mos-65816/commit/3c2c7a5) | `qsortviz` #46 (**originating** — [plan](../plans/2026-06-30-46-snes-qsortviz.md)), `spaceship` #97, `ucmprank` #98, `trimerge` #99, `keycmp64` #100 (Round 6, Cluster B — signed/unsigned/control-flow/chained-s64 angles) | [`examples/65816/a16scmp.c`](../../examples/65816/a16scmp.c) (+ sibling `a16eqvalg.c`/`a16abscmp.c` micro-repros in the same dir). |

Per-demo plan links (for pulling the exact bug/fix prose the user asked for into each gallery
page's data entry): `crcwall`→[plan](../plans/2026-07-02-105-snes-crcwall.md),
`lfsr2`→[plan](../plans/2026-07-02-106-snes-lfsr2.md),
`bitweave`→[plan](../plans/2026-07-02-107-snes-bitweave.md),
`uarteye`→[plan](../plans/2026-07-02-108-snes-uarteye.md),
`pcooker`→[plan](../plans/2026-07-02-109-snes-pcooker.md),
`borrowlad`→[plan](../plans/2026-07-02-110-snes-borrowlad.md),
`qsortviz`→[plan](../plans/2026-06-30-46-snes-qsortviz.md),
`spaceship`→[plan](../plans/2026-07-02-97-snes-spaceship.md),
`ucmprank`→[plan](../plans/2026-07-02-98-snes-ucmprank.md),
`trimerge`→[plan](../plans/2026-07-02-99-snes-trimerge.md),
`keycmp64`→[plan](../plans/2026-07-02-100-snes-keycmp64.md).

**Data model addition (Step 2 below):** each of these 11 demo entries in `snes-demos.ts` (and the
2 biohack.net pages get the same, for `qsortviz` if not already present) gains an optional
`bugFound: { patch, summary, fixSummary, fixCommitUrl, demoPlanLink, reproPath? }` —
`summary`/`fixSummary` text drawn verbatim/condensed from the table above and each demo's own plan;
`fixCommitUrl` links the public fork commit directly (safe now the repo is public). The other 102
demos (including `lsystem`/`ovmove`/`rotslab`/`permscat`/`ropeedit`/`dhmix`, excluded per the scope
note above) get no `bugFound` field.

## Why a data-driven route for indri.studio, not 113 hand files

biohack.net's 111 pages are genuinely hand-written (bespoke copy, `page-template.astro` scaffolded
once per demo, `snes-rom-page` skill). Re-authoring 113 near-duplicate `.astro` files for
indri.studio would (a) duplicate content that already exists in biohack.net's pages verbatim, and
(b) create 113 files that drift the moment one site's copy changes. Instead: extract each demo's
`{slug, title, desc, keys, category, controls[], selfcheck}` from biohack.net's existing
`src/pages/snes/*.astro` files into one data module
(`src/data/snes-demos.ts`, shared import), then **one** dynamic route
(`src/pages/apps/llvm-mos-65816/snes/[slug].astro`) renders every page, plus one index
(`src/pages/apps/llvm-mos-65816/snes/index.astro`) renders the gallery. Same rendered URLs and
markup shape as biohack.net; one template instead of 113 — this is normal data/template separation
for a 113-row catalog, not gratuitous abstraction.

## Mockups

### indri.studio gallery index — `/apps/llvm-mos-65816/snes/`

Mirrors biohack.net's `/snes/` card grid (thumbnail + title + one-line "keys" blurb, category
filter chips across the top), restyled to indri.studio's grey/neon-purple brand and `Base.astro`
chrome (site header/footer instead of biohack.net's).

```
┌────────────────────────────────────────────────────────────────────┐
│  indri.studio                                    [ nav: Apps  Docs ]│  ← Base.astro chrome
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   SNES Demo Gallery                                                 │
│   113 in-browser Super Nintendo demos compiled from C with the      │
│   llvm-mos-65816 toolchain — each a stress-test for the compiler's  │
│   16-bit-accumulator codegen. Every ROM verified against MAME and   │
│   bsnes-jg. Click any card to play.          ← expanded intro copy  │
│                                                                      │
│   [All] [Fractals] [Physics] [Cellular] [Motion] [Algorithms]       │
│   [Rendering] [Signals] [Bignums] [Ciphers] [Classics]  ← chips     │
│                                                                      │
│   ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │
│   │[ thumb ]  │ │[ thumb ]  │ │[ thumb ]  │ │[ thumb ]  │          │
│   │ png 256×  │ │ png 256×  │ │ png 256×  │ │ png 256×  │          │
│   │ 224,      │ │ 224 ...   │ │ 224 ...   │ │ 224 ...   │          │
│   │ purple▶   │ │ purple▶   │ │ purple▶   │ │ purple▶   │          │
│   │ overlay   │ │ overlay   │ │ overlay   │ │ overlay   │          │
│   ├───────────┤ ├───────────┤ ├───────────┤ ├───────────┤          │
│   │ Mode 7    │ │ Blossom   │ │Mandel OOP │ │6502 Sim   │          │
│   │ Self-run· │ │ Self-run· │ │ Self-run· │ │ Self-run· │          │
│   └───────────┘ └───────────┘ └───────────┘ └───────────┘          │
│   ... (113 cards, wraps to N columns responsive, same as biohack)  │
│                                                                      │
├────────────────────────────────────────────────────────────────────┤
│  footer                                                              │
└────────────────────────────────────────────────────────────────────┘
```

### indri.studio per-demo page — `/apps/llvm-mos-65816/snes/<slug>/`

Same anatomy as a biohack.net demo page (hero + centred player + controls table + notes),
restyled: purple accent (`--rp-accent: #b026ff`), indri.studio fonts/`Base.astro` instead of
biohack.net's Dune Rise + dark-orange cyberpunk chrome.

```
┌────────────────────────────────────────────────────────────────────┐
│  indri.studio                                    [ nav: Apps  Docs ]│
├────────────────────────────────────────────────────────────────────┤
│   ← Back to SNES gallery                                            │
│                                                                      │
│   Blossom                                    [ Games & Classics ]   │  ← rp-title / category chip
│   Barry Martin's Hopalong strange attractor, rendered live on the   │
│   Super Nintendo... (verbatim from biohack.net's copy)              │  ← rp-lede
│                                                                      │
│        ┌──────────────────────────────┐                             │
│        │                              │                             │
│        │     [ 256×224 canvas ]       │   ← centred, natural aspect │
│        │                              │                             │
│        └──────────────────────────────┘                             │
│        loading core…      [Verify fidelity] [Fullscreen]            │
│        ← ↑ ↓ → pan · Q/W zoom · X/A attractor · Shift colour ·      │
│        Enter reset                                                  │
│                                                                      │
│   Controls                                                          │
│   ┌────────────┬─────────────────────┐                              │
│   │ Keys       │ Action              │                              │
│   ├────────────┼─────────────────────┤                              │
│   │ ← ↑ ↓ →    │ Pan the view        │                              │
│   │ Q / W      │ Zoom out / in       │                              │
│   │ ...        │ ...                 │                              │
│   └────────────┴─────────────────────┘                              │
│                                                                      │
│   Built in C with an LLVM/65816 SNES toolchain, verified pixel-for- │
│   pixel against two emulators. Hit Verify fidelity to reproduce...  │
├────────────────────────────────────────────────────────────────────┤
│  footer                                                              │
└────────────────────────────────────────────────────────────────────┘
```

### One of the 11 bug-found demo pages — e.g. `/apps/llvm-mos-65816/snes/crcwall/`

Same anatomy, plus one extra section (below Controls, above the closing note) — only present when
the demo's data entry has a `bugFound` field. Links `fixCommitUrl` (the fork is public now, so this
resolves for visitors).

```
│   Controls                                                          │
│   ┌────────────┬─────────────────────┐                              │
│   │ ...        │ ...                 │                              │
│   └────────────┴─────────────────────┘                              │
│                                                                      │
│   Compiler bug this demo guards against                          │  ← NEW section
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │ Default-8-bit silent miscompile (register coalescer, patch    │ │
│   │ 0010): two rotate-referenced values got merged into the       │ │
│   │ A-only `Ac` class, stranding a loop-carried CRC byte in Y     │ │
│   │ while the back-edge ROL read a stale A. Both LLVM's normal    │ │
│   │ verifiers passed — this was silent, not a crash. Fixed by     │ │
│   │ teaching the coalescer to refuse that join. This demo runs    │ │
│   │ three interleaved bit-serial CRCs (8/16/32-bit) under the     │ │
│   │ exact register pressure that triggered it, as a standing      │ │
│   │ regression guard.                                             │ │
│   │                                            [ View the fix → ] │ │  ← fixCommitUrl
│   └──────────────────────────────────────────────────────────────┘ │
│                                                                      │
│   Built in C with an LLVM/65816 SNES toolchain, verified pixel-for- │
│   pixel against two emulators. Hit Verify fidelity to reproduce...  │
├────────────────────────────────────────────────────────────────────┤
│  footer                                                              │
└────────────────────────────────────────────────────────────────────┘
```

### llvm-mos-65816.mdx product page — expanded intro (existing `EmulatorEmbed` untouched)

```
  SNES C Compiler
  Write modern C — boot it on a Super Nintendo.

  An optimizing, open-source C compiler for the WDC 65816 ... (existing text, unchanged)

  [ EmulatorEmbed: mandel-display, live, Verify fidelity ]   ← unchanged, untouched

  ...why 113 demos exist... (NEW paragraph, expands on existing text — doesn't replace it)
  Beyond this single Mandelbrot demo, the toolchain has been stress-tested against 113
  SNES programs — fractals, physics sims, cellular automata, ciphers, a 6502 simulator, a
  playable Space Invaders — each one built to exercise a different corner of the codegen and
  verified pixel-for-pixel against two emulators. Browse the full gallery →

  [ Browse all 113 demos → /apps/llvm-mos-65816/snes/ ]      ← NEW link/button

  ## Install
  ... (existing content, unchanged)
```

## Steps

**Definition of done: both sites actually deployed live, not just built locally.** Step 1 ends
with biohack.net's `task publish TAG=vX.Y.Z` (tag-driven Cloudflare Pages deploy) and Step 6 ends
with indri.studio's `task deploy` (`wrangler deploy`) — these are not optional/skippable once the
content is ready. A local `task build` that passes is a checkpoint, not the finish line; the demos
aren't "published" until both deploys have actually run and the verification checklist below is
re-checked against the **live** URLs (`https://biohack.net/...` / `https://indri.studio/...`), not
just `dist/`.

### 1. biohack.net — fix the /snes/ location drift, then add the 2 missing demos

**1a. Fix the 4 off-convention pages first** (currently-live 404s from the gallery, unrelated to
the 2 new demos but caught during this same URL-verification pass): `git mv
src/pages/{bitweave,uarteye,pcooker,borrowlad}.astro src/pages/snes/` for each; update any
self-referential `href`/`BJG_BASE` path inside each file that assumed top-level (`/play/` base
path is unaffected — only the *page* URL moves, not the asset base, matching how the 2026-07-02
sweep did the other 14 with zero asset changes). **DONE (2026-07-26):** the only per-file fix
needed was the `Base.astro` import depth (`../layouts/` → `../../layouts/`, the `href`/`BJG_BASE`
values were already absolute and needed no change); `pnpm build` clean (115 pages, all 4 under
`/snes/{slug}/`); `grep -rn` across `src/` for the old top-level path strings found **zero** stray
references — nothing else in the codebase pointed at the abandoned locations, so no redirect is
needed (matches the "no redirect, old URL just 404s" precedent from 2026-07-02, now confirmed
nothing relies on it). Re-run the audit script (Step 6) — 0 top-level demo pages should remain.

**Clean up old/abandoned locations, not just add new ones — apply this throughout the plan, not
only here:** whenever a step moves or supersedes a location (a page, a route, a standalone
surface), track down and remove/redirect the old one in the *same* step, and grep for stray
references before calling it done — don't leave a duplicate/orphaned surface behind. Concretely,
beyond this 4-page move: **Step 4 below must also retire indri.studio's orphaned standalone
`/apps/llvm-mos-65816/play/` page** (the bare `index.html` + its own `app.js` boot script,
hardcoded to `mandel-display`, found in the Context section above) — once the new gallery exists,
that page is a third, redundant "play a demo" surface (inline `EmulatorEmbed` + new gallery + this
old orphan). Either delete it and redirect `/apps/llvm-mos-65816/play/` → the gallery's
`mandel-display` page, or repoint it at the gallery entirely — don't leave it live and unlinked.

**1b. Add the 2 missing demos.** ROMs already built in this repo: `build/mandel-display.sfc`,
`build/mandel-oop.sfc`. Preview PNGs: indri.studio already has `mandel-display.png`;
`build/mandel-oop-jg.png` exists from prior verification work (recompress to 256×224 via
scaffold.sh's Pillow step).

- `~/.claude/skills/snes-rom-page/scaffold.sh --rom build/mandel-display.sfc --slug mandel-display --site ~/biohack.net --title "Mode 7 Mandelbrot" --preview <preview> --selfcheck "0x200 2 0x204F 5800 ..."`
- same for `mandel-oop` (`selfcheck` per its plan: `corpus_result==0x204F`, see
  `docs/plans/2026-06-30-snesgfx-mandel-oop-verification.md`).
- Write `src/pages/snes/mandel-display.astro` + `src/pages/snes/mandel-oop.astro` **directly under
  `snes/`** from `page-template.astro`, biohack.net-branded (dark + orange, Dune Rise), category
  `fractals` — no top-level detour this time.
- Add both to the `demos` array in `src/pages/snes/index.astro` (category `fractals`).
- **Bug-provenance callout, for parity with the new indri.studio pages:** add the same "Compiler
  bug this demo guards against" section (see mockup above) to biohack.net's existing 11
  bug-provenance pages — `crcwall`, `lfsr2`, `bitweave`, `uarteye`, `pcooker`, `borrowlad`,
  `qsortviz`, `spaceship`, `ucmprank`, `trimerge`, `keycmp64` — using the same prose as the
  `bugFound` data (they currently only mention the patch/round in the lede paragraph, no distinct
  section).
- Verify: `task build` + headless screenshot both new pages + a couple of the updated bug-callout
  pages (per skill step 4).
- Commit, `task publish TAG=vX.Y.Z`.

### 2. indri.studio — extract shared demo data

- New script (throwaway, run once): parse all 111+2 biohack.net `src/pages/snes/*.astro` files,
  pull `{slug, title, desc, keys, category, controls[]}` out of the frontmatter/JSX (regex or a
  small TS/Node script since it's a fixed shape) plus `selfcheck` out of `roms/manifest.json`.
- For the 11 demos in the *Bug provenance* table above, add `bugFound: {patch, summary,
  fixSummary, fixCommitUrl, demoPlanLink}` by hand (condensed from that table + each demo's own
  plan doc) — not scraped, since this prose doesn't exist verbatim in the current biohack.net pages
  yet (this plan is also the spec for adding it there). `fixCommitUrl` points at the public fork
  commit (table above has all 4).
- Write `~/indri.studio/src/data/snes-demos.ts` — one exported array, 113 entries, same shape
  (+ `bugFound?` on the 10).

### 3. indri.studio — copy assets

- Copy all 113 `.sfc` + `.png` previews from `~/biohack.net/public/play/{roms,preview}/` into
  `~/indri.studio/public/apps/llvm-mos-65816/play/{roms,preview}/` (mandel-display/mandel-oop
  already-built ROMs go in too). ~9.3 MB total — engine (`app.js`, `cores/`) already vendored
  there, no extra cost.
- Regenerate `public/apps/llvm-mos-65816/play/roms/manifest.json` with all 113 `{id, title,
  selfcheck}` entries (union of biohack.net's manifest + the 2 new ones).

### 4. indri.studio — build the gallery route

- `src/pages/apps/llvm-mos-65816/snes/index.astro` — gallery, modeled on biohack.net's
  `src/pages/snes/index.astro` (category chips + card grid), reading `snes-demos.ts`, indri.studio
  `Base.astro` chrome + purple accent.
- `src/pages/apps/llvm-mos-65816/snes/[slug].astro` — dynamic per-demo page (Astro
  `getStaticPaths()` over `snes-demos.ts`), same anatomy as biohack.net's per-demo pages (hero +
  centred player + controls table + selfcheck), purple accent, `Base.astro`.
- Reuse `EmulatorEmbed`'s boot-script pattern (base path, default ROM, `BJG_BUST`) per-slug instead
  of hardcoded `mandel-display`.
- **Retire the orphaned standalone `/apps/llvm-mos-65816/play/` page** (see the cleanup note in
  Step 1 above): delete `public/apps/llvm-mos-65816/play/index.html` (the old bare single-ROM
  player, hardcoded to `mandel-display`, superseded by the new gallery) and add a redirect
  `/apps/llvm-mos-65816/play/` → `/apps/llvm-mos-65816/snes/mandel-display/` (indri.studio is
  Cloudflare Workers — a Worker-level redirect or an `_redirects`-equivalent, whichever this
  project's routing already uses elsewhere; check for precedent before inventing a new mechanism).
  `grep -rn` the codebase for anything linking `/apps/llvm-mos-65816/play/` directly (as opposed to
  `/apps/llvm-mos-65816/play/<asset>`, which stays — only the bare page route is retired) before
  calling this done.

### 5. indri.studio — expand the product page copy

- Edit `src/content/apps/llvm-mos-65816.mdx`: keep the existing intro + `<EmulatorEmbed />`
  untouched; add one new paragraph (why 113 demos exist) + a link/button to
  `/apps/llvm-mos-65816/snes/`.

### 6. Verify + deploy

- `cd ~/indri.studio && task build`; headless-screenshot the gallery index + 2–3 spot-check demo
  pages (a fractal, blossom, mandel-oop) per the skill's step-4 method.
- Confirm manifest count == 113 on both sites (`jq '.roms | length' public/play/roms/manifest.json`
  / indri.studio equivalent path).
- `task deploy` (indri.studio, wrangler) — goes live on reload, no cache purge needed.
- Commit indri.studio changes per the skill's commit-discipline note (stage only files this run
  touched).

## Verification (raw output, 2026-07-26)

1. `jq '.roms | length' ~/biohack.net/public/play/roms/manifest.json` == 113.
   ```
   113
   ```
   **PASS**

2. `jq '.roms | length' ~/indri.studio/public/apps/llvm-mos-65816/play/roms/manifest.json` == 113.
   ```
   113
   ```
   **PASS**

3. Headless screenshot `https://biohack.net/snes/mandel-display/` and
   `https://biohack.net/snes/mandel-oop/` — core boots, image renders, not clipped.
   ```
   mandel-display: 200
   mandel-oop: 200
   ```
   Both screenshotted locally pre-deploy (core boots, canvas centred, natural aspect, correct
   Mandelbrot render) and confirmed live post-deploy via HTTP 200. **PASS**

4. Headless screenshot `https://indri.studio/apps/llvm-mos-65816/snes/` (gallery) and 3 spot-check
   demo pages — same pass criteria.
   Screenshotted locally pre-deploy (card grid + category chips + bug-found badges, matches the
   site's actual lime-green brand; `crcwall` bug callout renders correctly). CI deploy (`task bump`,
   tag `v0.1.85`) completed; live re-check:
   ```
   $ curl -s -H "Cache-Control: no-cache" https://indri.studio/apps/llvm-mos-65816/snes/ | grep -o 'gl-card-wrap' | wc -l
   113
   ```
   **PASS**

5. `https://indri.studio/apps/llvm-mos-65816/` still renders the original intro + `EmulatorEmbed`
   unchanged, plus the new "browse all 113" link resolving to the gallery.
   ```
   $ curl -s -H "Cache-Control: no-cache" https://indri.studio/apps/llvm-mos-65816/ | grep -o "Browse the full demo gallery"
   Browse the full demo gallery
   $ curl -s -H "Cache-Control: no-cache" https://indri.studio/apps/llvm-mos-65816/ | grep -o 'id="bjg-embed"'
   id="bjg-embed"
   ```
   **PASS**

6. The 11 bug-provenance pages render the "Compiler bug this demo guards against" section on
   *both* sites (`crcwall`, `lfsr2`, `bitweave`, `uarteye`, `pcooker`, `borrowlad`, `qsortviz`,
   `spaceship`, `ucmprank`, `trimerge`, `keycmp64`) with a working link to the public fork commit;
   no other page has the section.
   ```
   Compiler bug this demo guards against
   href="https://github.com/wbniv/llvm-mos-65816/commit/3c2c7a5"
   ```
   (biohack.net `/snes/keycmp64/`, live.) Screenshotted `crcwall` on both sites — box renders
   identically (bordered callout, patch/bug/fix prose, commit link), styled to each site's brand.
   **PASS** (both sites live).

7. `curl -s https://api.github.com/repos/wbniv/llvm-mos-65816` reports `"private": false`.
   ```
   private: False | visibility: public
   ```
   **PASS**

8. All demo URLs resolve under `/snes/` on biohack.net (`bitweave`/`uarteye`/`pcooker`/`borrowlad`
   included) — 0 top-level `src/pages/*.astro` demo pages remain.
   ```
   (no STRAY lines — only index/404/claude remain at top level, all legitimate non-demo pages)
   ```
   Also confirmed live: `/bitweave/` 404s (`cf-cache-status: DYNAMIC`) and `/snes/bitweave/` 200s.
   **PASS**

9. indri.studio's old standalone `/apps/llvm-mos-65816/play/` page no longer serves the old bare
   player.
   ```
   $ curl -s -o /dev/null -w "%{http_code}\n" -H "Cache-Control: no-cache" https://indri.studio/apps/llvm-mos-65816/play/
   404
   ```
   `public/apps/llvm-mos-65816/play/index.html` deleted; no code referenced the bare route (only
   `BJG_BASE` asset-base strings, still needed and untouched). **PASS**

**Two things worth recording from the process:**

- **Deploy-credential detour.** `task deploy` (local `wrangler deploy`) needs `CLOUDFLARE_API_TOKEN`
  in `.env`, sourced via `task secrets-pull` from AWS SSM under the `indri-terraform` profile —
  unavailable in this sandboxed environment (no `aws` CLI at all). Rather than work around it once,
  added `task publish`/`task bump` to indri.studio's Taskfile (mirroring biohack.net's), which push
  a tag to trigger the **already-existing** `.github/workflows/deploy.yml` — CI holds
  `CLOUDFLARE_API_TOKEN` as a GitHub Actions secret, so this needs zero local Cloudflare/AWS
  credentials and works for any contributor with push access (an SSH key on GitHub). Also corrected
  the `snes-rom-page` skill's stale brand guidance ("neon-purple `--rp-accent`") — the live product
  page actually uses the site's default lime-green (`--color-primary-container: #b8ef00`), confirmed
  by screenshot; no per-app theme override was ever applied.
- **False-alarm cache read.** The first live poll of indri.studio's `manifest.json` (with a
  `?_cb=<random>` cache-busting query param, the trick that works on Cloudflare Pages) reported only
  2 ROMs — Cloudflare Workers Static Assets ignores query strings for its cache key (unlike Pages),
  so the query-param buster didn't bypass the cached response. Re-checked with a
  `Cache-Control: no-cache` *header* instead (forces revalidation) and got all 113 correctly — genuine
  false alarm, not a real deploy gap. Worth remembering for future indri.studio (Workers) verification:
  use the header, not a query-string buster.

## Risks / scope notes

- **No silent truncation**: all 113 demos ship on both sites — if any asset is missing (e.g. a
  preview PNG), `log()`/print it rather than skipping silently.
- indri.studio deploy is Cloudflare **Workers** (`wrangler deploy`), not Pages — HTML is
  `no-store`, so no cache-purge step needed there (unlike biohack.net's tag-driven Pages deploy).
- `hello.c` stays unpublished on both sites (user-confirmed).
- **Bug-provenance scope is an editorial judgment call**, not mechanical: `0002`/`0017` were
  excluded because the defect lives in code *we* wrote for the `+mos-a16`/`+mos-xy16` feature
  itself; `0010`/`0011`/`0012`/`0016` were included because the defect lives in pre-existing
  generic/default-8-bit compiler code, even though `0011`/`0012` were only *exposed* by our new
  16-bit code paths (same pattern as the two already-upstream-merged fixes, #562/#563). Re-check
  this judgment if new demos are added to the gallery later.
- All 4 included patches are **unposted upstream** — the fix links are fork commits, not upstream
  PRs, but they're public and resolve fine now the fork is public.
- **The fork going public is itself a consequential, hard-to-undo action** — GitHub, forks, and
  crawlers can copy content the moment it flips, so re-privating later doesn't retract exposure.
  Ran a secrets/sensitive-content sweep first (clean — see the update note above); if anything
  turns up sensitive later, treat it as already-disclosed, not just revert the visibility flag.
- This plan spans 3 repos (`llvm-mos-65816` for context/ROMs, `biohack.net`, `indri.studio`) — the
  file lives here per `~/CLAUDE.md`'s plan-first convention (cascades to all projects under `~/`);
  TODO.md entries added in this repo, cross-referencing both site repos' commits once done.
