# Player release review — `@wbniv/bsnes-jg-player` live-record (`verifyLiveRecord`)

**Date:** 2026-08-01 · **Reviewer:** orchestrator session (user-requested review + release prep)
**Repo under review:** `~/bsnes-jg-wasm` (npm package `@wbniv/bsnes-jg-player`, currently `1.0.0`)
**Feature:** `selfcheck.mode: "live-record"` — the browser half of the gallery's per-image
"Verify fidelity" button ([contract](../plans/2026-07-28-gallery-per-image-selfcheck.md)).

## Verdict

**Ship it, with one mandatory fix folded in.** The implementation is faithful to the contract,
its pass/fail decision paths were already exercised end-to-end against a real ROM + oracle
tables (verify-fidelity close-out, evidence in the selfcheck plan), and the repo state is
cleaner than previously reported. The mandatory fix is the badge `className` defect — which the
new code *reproduces* — without which every verdict the feature renders will continue to be an
**unstyled** pill, as it has been on every demo page to date.

## State correction (important)

Earlier reports said the implementation was "sitting uncommitted." Measured:

| Artifact | State |
|---|---|
| `web/app.js` (the **source** copy) | feature **committed** — `a5270ff` "feat(player): implement selfcheck.mode live-record", plus three later telemetry commits (`33ad2bf`/`1915b14`/`b037411`) |
| `web/roms/manifest.json` (demo-page data) | committed in `a5270ff` |
| `dist/engine/app.js` (the **published artifact**) | **uncommitted refresh** (+62 lines) — byte-identical to the committed source; the dist copy simply never caught up |
| `dist/demo/roms/manifest.json` | same — uncommitted refresh (+152 lines, the live-record selfcheck entry: `mode`/`z`/`work`/`ok`/`state`/`ready`/`oracle[62]`/`titles[62]`, matching the site fixture shape exactly) |
| npm version / `ENGINE_VERSION` | never published/stamped — sites run a ghost build (byte-identical to this dist state, so **live behaviour already matches what ships**; the release makes it versioned, not different) |

So the release is: commit the dist refresh, fix the badge defect (both copies), bump, publish,
re-sync sites via the package CLI (`bin/sync.mjs`, which writes each dest's `ENGINE_VERSION`
stamp with per-file sha256s).

## Code review — `verifyLiveRecord(sc)` (`dist/engine/app.js` @230, == `web/app.js`)

**What it does right (matches the contract, confirmed against the plan):**

- **No power-cycle.** It polls the already-running machine — a reload would destroy the
  gallery's browsing-cursor state, which is the entire point of the displayed-work check. The
  live rAF loop is deliberately left running so the visitor's navigation stays live.
- **Respects the ROM's publication barrier.** All fields are only trusted once
  `state == sc.ready`; intermediate reads are used solely for progress display and
  navigation-following, never for the verdict.
- **Navigation semantics per spec:** first mid-check navigation re-targets and restarts the
  budget ("following your navigation to …"); a second one fails soft with the "hold on one
  artwork" message. Budget exhaustion yields the ⏱ warn, not a false FAIL.
- **Verdict triage is exact:** `ok !== 1` (ROM's own byte-compare rejected) is distinguished
  from `z != oracle` (repack size mismatch) — the two failure classes the ROM publishes.
- Chunked (`poll` frames per `setTimeout(0)` macrotask), so the tab stays responsive.

**Findings, mandatory → cosmetic:**

- **F1 (MANDATORY): the badge is never styled — new code reproduces a site-wide defect.**
  The page element is `<span id="checkresult" class="rp-badge">`; biohack.net styles
  `.rp-badge.pass/.fail/.running`. Every `className` write in `app.js` **replaces** the class
  with `"badge …"`, which no stylesheet defines — the green PASS / red FAIL pills have never
  rendered on any demo page. Sites: the new `badge()` helper (`:234`), the two resets
  (`:175`, `:199`), and the legacy verify path (`:309`, `:327`, `:330`).
  **Fix:** `"rp-badge " + cls` in the helper, `"rp-badge"` in the resets, and route the legacy
  path through the fixed helper. Text content is untouched, so the headless-CI contract
  (grep `#checkresult` for PASS/MISMATCH, noted at `:187`) is preserved.
  **Companion (site repo):** add a `.rp-badge.warn` rule — `warn` is a new class this feature
  introduces; without the rule the timeout badge would be unstyled even after F1.
- **F2 (release blocker, mechanical):** the dist refresh must be committed — publishing `1.0.0`
  as-is would ship a package whose `dist/` lacks the feature its source has.
- **F3 (minor):** the repack size is read as a hardcoded 2-byte little-endian at `rec.z[0]`;
  `rec.z` carries a length that is ignored. Fine while sizes fit 16 bits (they do: ≤ ~17 KB),
  but honor-or-assert the length. Non-blocking.
- **F4 (by-design, document):** while the check runs, *both* the chunk loop and the live rAF
  loop advance the emulator — the demo visibly fast-forwards during verification, and `done`
  undercounts real machine frames (making the ⏱ warn conservative, never premature). This is
  the price of keeping navigation live; worth one sentence in the README so nobody "fixes" it.
- **F5 (cosmetic):** a `work` index missing from `sc.oracle` renders "want undefined" in the
  mismatch text. Guard with an explicit "no oracle for this work" message.

## Release plan (prepared; executes on your go)

1. Fix F1 (+F5 guard) in `web/app.js`, mirror to `dist/engine/app.js` (keep the pair
   byte-identical); commit.
2. Commit the dist refresh (this + the manifest) — message ties it to `a5270ff`.
3. Version: **`1.1.0`** (new feature ⇒ semver minor), `task publish-dry` to show the exact
   ship list, then `npm publish`.
4. Site rollout, per site: `bsnes-jg-player sync` (writes `ENGINE_VERSION` + sha stamps),
   add the `.rp-badge.warn` CSS rule, commit, deploy via each site's CI flow. Note: after F1,
   the sites' current ghost `app.js` is superseded — the sync replaces it with the fixed,
   versioned copy, resolving the uncommitted `public/play/app.js` drift in `~/biohack.net`
   as a side effect.
5. Live verification: run Verify fidelity on the gallery page — badge must now render as a
   styled green pill; check one FAIL path via a deliberately stale manifest entry on a fixture
   (not live).

## Verification record (to fill at execution)

1. `cmp web/app.js dist/engine/app.js` → identical post-fix.
2. `task publish-dry` output — file list contains dist/engine + bin + astro, no strays.
3. npm publish + version visible in registry.
4. Per-site `ENGINE_VERSION` stamp contents; site CI runs green; live `app.js` sha == packed.
5. Live badge screenshot: styled pass pill.
