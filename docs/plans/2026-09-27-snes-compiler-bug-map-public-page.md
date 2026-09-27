# Public SNES compiler contributions map

## Goal

Publish the compiler contributions map at `https://biohack.net/snes/compiler-contributions/` and link to it from the bottom of the SNES gallery. The public view must be derived from the compiler repository's canonical `docs/snes-compiler-contributions.json`, not maintained as a second hand-authored table.

It is a provenance index, not a defect dashboard: each row identifies the original published ROM or compiler-only contribution, the discovery date, the linked contribution statement and technical evidence, any upstream PR, and the internal simulated PR packet. Later ROMs that merely guard an earlier defect do not appear.

## Mockups

### Desktop

```text
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ ← SNES demos                                                                                │
│                                                                                            │
│ COMPILER CONTRIBUTIONS                                                                      │
│ Published SNES ROMs and compiler work that improved the toolchain.                          │
│                                                                                            │
│ ┌────────────┬──────────────────────────────┬──────────────┬──────────┬────────┬─────────┐ │
│ │ DISCOVERED │ CONTRIBUTION (linked evidence) │ SOURCE    │ UPSTREAM          │
│ ├────────────┼───────────────────────────────┼───────────┼───────────────────┤ │
│ │ 2026-06-25 │ rotate coalescing miscompile  │ CRC Wall  │ #578 · MERGED     │ │
│ │ 2026-06-26 │ far memset picks near runtime │ Blossom   │ internal PR sim   │ │
│ │ 2026-06-30 │ G_SCMP/G_UCMP abort           │ QSort Viz │ #577 · MERGED     │ │
│ └────────────┴───────────────────────────────┴───────────┴───────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Mobile

```text
┌──────────────────────────────┐
│ ← SNES demos                 │
│                              │
│ COMPILER CONTRIBUTIONS       │
│ Published contribution map.  │
│                              │
│ ┌──────────────────────────┐ │
│ │ 2026-06-25               │ │
│ │ [rotate coalescing]       │ │
│ │ [CRC Wall]                │ │
│ │ [PR #578] · MERGED        │ │
│ └──────────────────────────┘ │
│                              │
│ ← horizontally scrollable    │
│   table is acceptable only   │
│   if cards become too dense. │
└──────────────────────────────┘
```

Use the responsive table implementation: it preserves a compact chronological comparison on desktop and renders cards on narrow screens. The contribution title, including its type icon, is the evidence link; do not duplicate it in a separate Record column or mobile field.

The Upstream field is mutually exclusive: show the upstream PR and its current state when it has been posted; otherwise show the internal PR simulation. Do not add a second simulation column or field.

## Rendered screenshots

Desktop capture:

![Compiler-bug discovery map on desktop](2026-09-27-snes-compiler-bug-map-desktop.png)

390px mobile verification capture:

![Compiler-bug discovery map as mobile cards](2026-09-27-snes-compiler-bug-map-mobile.png)

## Data and synchronization contract

1. Keep `docs/snes-compiler-contributions.json` as the canonical source. Its required fields are `slug`, `discovered`, `defect`, `evidence`, `prs`, and `pr_simulations`; a record has either a public `page` or a compiler-only `source_label`.
2. Commit the generated public export at `biohack.net/src/data/snes-compiler-contributions.json`; the Astro route imports this copy at build time. The export contains a semantic SHA-256 of its canonical records.
3. Extend `dev/publish-snes-rom-both-sites.sh` to compare the compiler public export with the biohack copy before publication, fail with an actionable message when they differ, and copy/stage the export during `--publish`.
4. Keep `dev/render-snes-demo-compiler-bug-map.py` as the compiler-side Markdown renderer and make it validate dates, artifact paths, PR links, and the rule that a recorded upstream PR has an internal simulation.

## Page implementation

1. Add the `src/pages/snes/compiler-contributions.astro` route in biohack.net and redirect the previous `/snes/compiler-bugs/` path.
2. Sort records by `discovered`, then `slug`; never rely on JSON order for display order.
3. Make every Source value a link. Public demo names link to their published `/snes/<slug>/` page; compiler-only source labels link to their technical evidence until they have a dedicated public source page.
4. Make each contribution title link directly to its technical evidence; link simulations to their paths on the public compiler repository and PRs to their canonical upstream URLs.
5. Add one low-emphasis `Compiler bug discovery map` link to the gallery footer after the emulator-verification sentence. Do not add another gallery badge or filter.
6. Preserve normal site typography, keyboard focus styles, horizontal overflow containment, and a descriptive title/canonical URL.
7. Give desktop table rows a more prominent hover state: brighten the full row with a clearly visible accent-tinted surface, add an inset accent rule at the left edge, and slightly lift the contribution/source link contrast. The change must not move column geometry, obscure status badges, or rely on color as the sole focus indicator. Apply the same treatment through `:focus-within` so keyboard users receive equivalent context; keep transitions short and disable nonessential motion for `prefers-reduced-motion`.

## Verification and publication

1. Run the compiler renderer and `python3 dev/docs-deps.py --impact docs/snes-demo-compiler-bug-pages.json`, then refresh dependencies and review the affected publishing guidance.
2. Build and test biohack.net; assert that `/snes/compiler-contributions/index.html` is emitted, contribution links point to evidence, and the gallery HTML contains the footer link.
3. Run the paired publication script in read-only mode against a registered demo to prove the registry-copy check.
4. Commit compiler and site changes separately, push both, deploy biohack.net, and fetch both `/snes/` and `/snes/compiler-bugs/` to confirm the live footer link and table.

## Phase 2 — automatic cross-repository updates

Start this phase only after the public page above is deployed and its initial source-copy contract has been proven in a release.

1. Add a compiler-side exporter that emits a public registry copy and records the canonical records' semantic SHA-256 in that copy.
2. Make the compiler CI render both the Markdown map and public export, fail on stale generated output, and require the discovery registry to be reconciled whenever a structured defect record gains a discovery or a status change.
3. On a merge that changes the public export, create or update a biohack.net synchronization PR containing only the exported registry. It must name the compiler commit and source hash it represents.
4. Make biohack.net CI reject a records-hash mismatch before deployment. Its page continues to build from the committed copy, avoiding an availability dependency on another repository during site builds.
5. Keep `dev/publish-snes-rom-both-sites.sh` as a second, release-time check: it verifies the generated site copy for a ROM publication and stages the refreshed copy during `--publish`.
6. Treat a failed synchronization PR or a site-copy mismatch as a release blocker for a newly registered discovery, but do not block unrelated existing ROM publications merely because a later compiler-only status change awaits review.

This phase provides the ongoing update guarantee: a newly discovered or fixed defect changes the compiler source of truth, regenerates the public export, and receives a reviewable site-sync PR. It deliberately does not use a runtime `raw.githubusercontent.com` fetch.

### Per-defect rows and later discoveries

The canonical registry also carries the website's PR status snapshot and optional `lines` array. Each line binds one defect to its technical record, optional upstream PR, and internal simulation. A line may override `discovered`; otherwise it inherits the ROM's original discovery date. Both rendered maps sort by the effective line date. The September 25 split-Y report and September 27 bank-wrap isolation therefore appear after the gallery's earlier July 27 discoveries, with their own evidence and no upstream PR assigned.

The [near-decoder simulation](../pr-preparations/2026-09-27/near-y-pr-simulation.md) covers the two published downstream repairs and their remaining #321 submission gates. PR status metadata for #577, #578, #584, #586, #588 and #590 was checked through the GitHub API on September 27. The gallery explanation distinguishes the archived XY16 regression's `0x5CF0` result from the existing browser cartridge's `0x839F` display benchmark.

Registry reconciliation and near-decoder follow-up: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`.

The registry also preserves the website's concurrent BRK/COP split: PR #586 belongs to the BRK operand record, and #588 to COP. The QSort record retains #577.

### Recorded planning checks

- PASS — 2026-09-27: the registry renderer accepted the chronological registry and the documentation dependency refresh passed.
- PASS — 2026-09-27: the initial biohack.net page build emitted `/snes/compiler-bugs/index.html`; the site test suite passed 47 tests with one existing skip.
- PASS — 2026-09-27: release `v1.0.603` deployed successfully. Live `/snes/` contains the footer link and live `/snes/compiler-bugs/` contains the chronological table, PR #578, and simulation links.
- PASS — 2026-09-27: the exporter regenerated the public registry, its committed biohack copy compared equal, and the paired-publication helper passed shell syntax validation.

## Non-goals

- Do not expose `file://` URLs or local build paths.
- Do not imply that `Not posted` means a defect was rejected; it means no upstream PR URL is recorded.
- Do not treat internal PR simulations as upstream submissions.
