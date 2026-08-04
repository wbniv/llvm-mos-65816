# #123 — Mode 7 filter for both SNES galleries

**Status:** IMPLEMENTED LOCALLY (2026-07-26)

Mockups:

- [biohack.net Mode 7 filter states](2026-07-26-123-mode7-gallery-filter/mode7-filter-mockups.html)
- [indri.studio Mode 7 filter states](2026-07-26-123-mode7-gallery-filter/indri-mode7-filter-mockups.html)

## Goal

Add a visible `Mode 7` filter to the SNES galleries on biohack.net and indri.studio. Activating it
shows exactly the nine demos whose shared metadata has `displayMode: 7`; deactivating it restores
the gallery without disturbing the current position or category choice.

## Data contract

Use the existing `displayMode?: 7` field as the sole filter predicate. Do not introduce another
hard-coded slug list in browser JavaScript.

The expected set remains:

`avalanche`, `blossom`, `buddhabrot`, `julia`, `lzss-gallery`, `mandel-display`,
`mandel-double`, `mandel-float`, and `mandel-oop`.

Add a build-time assertion in each site that:

- exactly nine records have `displayMode === 7`;
- the set equals the committed expected set;
- every matching card renders both its `data-display-mode="7"` hook and its visible `7` badge; and
- the two sites use the same expected set.

## Interaction model

Render a real `<button type="button" aria-pressed="false">` labeled `Mode 7`, with the existing
compact `7` badge repeated as a decorative leading mark. The word label is necessary here: unlike
the screenshot badge, this is a control and must describe its action.

Inactive:

- neutral styling consistent with the gallery’s existing controls;
- all demos remain visible;
- accessible name is `Show Mode 7 demos only`.

Active:

- `aria-pressed="true"`;
- highlighted cyan/mint treatment matching the screenshot badges;
- accessible name changes to `Show all demos`;
- the result count reads `9 Mode 7 demos`;
- pressing Escape while focus is in the gallery clears the filter.

Persist the state in the URL as `?mode=7`. Read it on initial load and browser history navigation.
Use `history.replaceState`, so toggling a view preference does not create a noisy Back-button stack.
The page must remain a complete usable gallery when JavaScript is unavailable.

Respect `prefers-reduced-motion`: filtering needs no card animation. With motion allowed, a short
opacity transition is acceptable, but cards must not reflow through a long stagger.

## biohack.net

`src/pages/snes/index.astro` uses horizontal category shelves rather than category chips.

Add the Mode 7 control below the introduction and above the first shelf. When active:

1. hide every `.cat-card` whose record is not Mode 7;
2. hide a `.cat-shelf` when it contains no visible cards;
3. keep the remaining shelves in their original category order;
4. reset each visible shelf’s horizontal scroll position to its beginning so results cannot be
   offscreen;
5. disable/hide shelf arrows when the filtered row does not overflow; and
6. restore prior shelf visibility and normal arrow behavior when cleared.

Each card receives `data-display-mode={displayMode}`. Each shelf receives a stable category hook.
Do not infer filter membership by inspecting badge text or image URLs.

## indri.studio

`src/pages/apps/llvm-mos-65816/snes/index.astro` already filters with category chips.

The Mode 7 control is an independent toggle placed after the category chip group. Its predicate is
combined with the current category:

```text
visible = (category == "all" OR card.category == category)
       AND (mode7 is off OR card.displayMode == "7")
```

Changing category must not clear Mode 7. Clearing Mode 7 must retain the selected category.
If a future category has no Mode 7 cards, show the empty-state line `No Mode 7 demos in this
category.` without collapsing the control row.

Centralize filtering in one `applyFilters()` function and call it from category clicks, Mode 7
clicks, initial query parsing, and `popstate`.

## Responsive and accessible presentation

The two linked mockups are the visual contract. The indri.studio mockup separately covers its
inactive, Mode 7-only, combined-category, empty-result, and narrow-phone states; do not treat the
biohack.net shelf composition as a shared page layout.

- At desktop widths, place the toggle and result count on one line.
- At narrow widths, allow the count to wrap below without shrinking the touch target.
- Minimum control height is 40 CSS pixels and minimum touch area is 44×44 where surrounding layout
  permits.
- Keep a visible focus ring using each site’s existing focus tokens.
- Never convey active state only through color: use `aria-pressed`, the label, and an active inset
  mark/check.
- Hidden cards and shelves use the `hidden` attribute, not opacity alone, so they leave the
  accessibility tree and tab order.
- Announce count changes through a restrained `aria-live="polite"` status.

## Files expected to change

### biohack.net

- `src/pages/snes/index.astro`
- focused gallery behavior tests or a new `tests/snes-mode7-filter.test.mjs`

### indri.studio

- `src/pages/apps/llvm-mos-65816/snes/index.astro`
- `src/data/snes-demos.ts` only if the parity assertion is colocated there
- focused gallery behavior tests or a new `tests/snes-mode7-filter.test.mjs`

## Verification

1. Both Astro production builds pass.
2. Static output contains exactly nine `data-display-mode="7"` cards and nine accessible badges.
3. Initial page shows the normal complete gallery.
4. Activating Mode 7 shows exactly the nine expected slugs.
5. Loading `?mode=7` initializes the active state before user interaction.
6. Clearing restores all cards.
7. On indri.studio, `Fractals + Mode 7` shows the six qualifying fractal cards; switching back to
   `All` restores all nine Mode 7 cards without clearing the toggle.
8. On biohack.net, empty shelves disappear and reappear correctly; remaining shelves start at
   scroll position zero.
9. Keyboard activation, Escape-to-clear, focus ring, `aria-pressed`, and live count are verified.
10. Test at the narrowest supported phone width and with reduced motion.

## Rollout

1. Implement and locally build biohack.net.
2. Implement indri.studio using the same semantics and expected set.
3. Compare the nine rendered slugs from both built HTML files.
4. Deploy both release tags.
5. Fetch both production pages cold and assert the control plus nine Mode 7 hooks.
6. Browser-smoke the active, combined-category, query-string, clear, and narrow-screen states.

## Acceptance criteria

- Both galleries expose an obvious, keyboard-accessible `Mode 7` filter.
- It selects exactly the same nine demos that carry the `7` badge.
- The selection is shareable with `?mode=7`.
- indri.studio composes Mode 7 with categories; biohack.net hides empty shelves.
- The filtered result is usable on narrow phones and with assistive technology.
- Neither site maintains an independent runtime slug list that can drift from `displayMode`.

## Implementation record

- Both galleries render a 44-pixel accessible `Mode 7` toggle from the existing `displayMode`
  metadata and preserve the complete gallery as the no-JavaScript default.
- The active selection is reflected as `?mode=7`, uses `aria-pressed`, updates a polite live result
  count, and clears with Escape while focus is inside the gallery.
- biohack.net hides empty shelves, resets visible shelf scroll positions, and recalculates arrow
  visibility.
- indri.studio combines the toggle with its existing category predicate and renders the specified
  empty state without clearing either filter.
- Both Astro production builds pass. Each built gallery contains exactly nine
  `data-display-mode="7"` hooks, nine accessible Mode 7 badges, and one filter toggle.

## Verification record — 2026-08-03, against `main` @ `c5e645d`

The plan's Verification section states **outcomes**, not commands, so each step below names the
command chosen to produce its evidence. The step text is reproduced **verbatim and unreordered**.

**Result: 7 / 10 steps PASS, 3 FAIL.**

### Scope and method

This plan is entirely website-layer — no ROM, no toolchain. Evidence therefore comes from three
sources, in this order of authority:

1. **CI deploy-run conclusions** for "builds pass" (per the standing rule that biohack.net and
   indri.studio build **only** in CI — a host-side build in either checkout is void as evidence).
2. **Cold fetches of the two live production pages** for static output.
3. **A jsdom harness** that loads each live page and evaluates that page's own shipped filter
   script, then drives it with real `click` / `keydown` / `popstate` events. This is the strongest
   runtime evidence obtainable here: no browser automation is installed (no Playwright, Node or
   Python), and jsdom performs **no layout**, so anything that depends on measured geometry
   (arrow overflow, narrow-viewport reflow) is out of its reach and is recorded as such.

Artifacts fetched for the run:

```
$ curl -sS -o biohack.html -w "biohack %{http_code} %{size_download}\n" https://biohack.net/snes/
biohack 200 104234
$ curl -sS -o indri.html -w "indri %{http_code} %{size_download}\n" \
    https://indri.studio/apps/llvm-mos-65816/snes/
indri 200 163840
```

biohack.net ships its gallery script inline (`<script>` in the page); indri.studio ships it as
`/_astro/index.astro_astro_type_script_index_0_lang.bzOpgAji.js`, gated on `astro:page-load`. The
harness extracts each, boots the page with `runScripts: "outside-only"` + `pretendToBeVisual`,
`eval`s the page's own script, and (for indri) dispatches `astro:page-load`. Card sets are
`.cat-card` on biohack.net and `.gl-card-wrap` on indri.studio; a card is "visible" iff its
`hidden` property is false; the slug is taken from the card's `href`.

**Systemic website-layer facts inherited from the #121 verification record (2026-08-03, `631ffe9`,
commit `ab6a541`) and not re-derived here:** the Mode 7 demo count is now **11, not nine** —
commits `cdaa6f4` / `ad87374` legitimately added `svx2-fastrom-video` and `apollo-daylight`, and
both metadata sources and both live galleries agree on the identical 11-slug set. Where a step
below turns on that same numeral, it is scored against the observed set and the cause is cited
rather than re-investigated.

### 1. Both Astro production builds pass.

Command: the deploy-workflow conclusion for each site's current HEAD (host builds are not evidence).

```
$ cd ~/biohack.net && git log -1 --format='biohack HEAD %h %s' \
  && gh run list --workflow deploy.yml -L 1 \
       --json displayTitle,conclusion,url -q '.[]|"\(.conclusion)\t\(.displayTitle)\t\(.url)"'
biohack HEAD 84c1d21 chore(snes): rebuild Apollo on the shared FPS gauge
success	chore(snes): rebuild Apollo on the shared FPS gauge	https://github.com/wbniv/biohack.net/actions/runs/30828480971

$ cd ~/indri.studio && git log -1 --format='indri HEAD %h %s' \
  && gh run list --workflow deploy.yml -L 1 \
       --json displayTitle,conclusion,url -q '.[]|"\(.conclusion)\t\(.displayTitle)\t\(.url)"'
indri HEAD 2b78747 feat(snes): synchronize complete ROM catalog from biohack
success	feat(snes): synchronize complete ROM catalog from biohack	https://github.com/wbniv/indri.studio/actions/runs/30824497265
```

**PASS** — both sites' latest deploy runs (`v1.0.365`, `v0.1.135`) are `success`, and both live
pages served the filtered gallery on a cold fetch.

### 2. Static output contains exactly nine `data-display-mode="7"` cards and nine accessible badges.

Command: parse both cold-fetched pages with jsdom and count the hooks, the badges, the badges that
carry an accessible name, and the filter toggles.

```
$ node -e '...JSDOM(each page)...'
biohack badges: 11 | aria-label sample: "Mode 7 display" | title: "Mode 7 display" | text: "7" | role: null
biohack badges with accessible name: 11
biohack data-display-mode=7 hooks: 11 | toggles: 1
indri badges: 11 | aria-label sample: "Mode 7 display" | title: "Mode 7 display" | text: "7" | role: null
indri badges with accessible name: 11
indri data-display-mode=7 hooks: 11 | toggles: 1
```

**FAIL** — the hooks and badges are one-for-one consistent (11 hooks, 11 badges, every badge
carrying the accessible name `Mode 7 display`, exactly one toggle per site), but the count is
**11, not nine**. Same cause as #121's badge-count FAIL: `cdaa6f4` / `ad87374` added two later
Mode 7 demos. Recorded as observed; expectations not adjusted, code not changed.

Two contributing gaps found while scoring this step, both **plan items that were never
implemented**, and jointly the reason the drift was silent:

```
$ cd ~/biohack.net && git ls-files | grep -i mode7 || echo "biohack: no mode7 test file tracked"
biohack: no mode7 test file tracked
$ cd ~/indri.studio && git ls-files | grep -i mode7 || echo "indri: no mode7 test file tracked"
indri: no mode7 test file tracked
$ cd ~/biohack.net && grep -rn "assert" src/pages/snes/index.astro \
    || echo "biohack: no build-time mode7 assertion"
biohack: no build-time mode7 assertion
```

The Data-contract build-time assertion ("exactly nine records have `displayMode === 7`; the set
equals the committed expected set; the two sites use the same expected set") exists on **neither**
site, and neither `tests/snes-mode7-filter.test.mjs` was ever added. Had the assertion shipped,
`cdaa6f4` would have failed its own build instead of drifting the count unnoticed.

### 3. Initial page shows the normal complete gallery.

Command: boot each live page in the harness with no query string and count visible cards.

```
STEP3 biohack {"total":120,"visible":120,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"120 demos","url":""}
STEP3 indri   {"total":120,"visible":120,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"120 demos","url":""}
```

**PASS** — all 120 cards visible on both sites, toggle `aria-pressed="false"`, accessible name
`Show Mode 7 demos only`, count `120 demos`, and no query string written on load.

### 4. Activating Mode 7 shows exactly the nine expected slugs.

Command: boot each page, dispatch a `click` on `.gl-mode-toggle`, list the visible slugs.

```
STEP4 biohack {"total":120,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP4 indri   {"total":120,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
slugs: ["apollo-daylight","avalanche","blossom","buddhabrot","julia","lzss-gallery",
        "mandel-display","mandel-double","mandel-float","mandel-oop","svx2-fastrom-video"]
biohack_superset_of_expected9: true
indri_superset_of_expected9:   true
same_set_both_sites:           true
extra_beyond_expected9:        ["apollo-daylight","svx2-fastrom-video"]
```

**FAIL** — the selection is **11 slugs, not nine**. The filter mechanism itself is correct in every
respect the step can test: it selects a strict superset containing all nine committed slugs, the
two sites resolve the **identical** set, `aria-pressed` flips to `true`, the accessible name becomes
`Show all demos`, the count reads `11 Mode 7 demos`, and `?mode=7` is written. The two extras are
exactly the pair identified in #121 (`cdaa6f4` / `ad87374`). This is a stale expectation in the
plan, not a filter defect — but the step as written does not hold.

### 5. Loading `?mode=7` initializes the active state before user interaction.

Command: boot each page at `?mode=7` and read state **without** dispatching any event.

```
STEP5 biohack {"total":120,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP5 indri   {"total":120,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
```

**PASS** — both sites parse `?mode=7` on their initial `applyMode7()` / `applyFilters()` call, so
the filtered state, pressed state, label, and count are all correct with zero user interaction, and
the shareable query string survives the `history.replaceState` round-trip unchanged.

### 6. Clearing restores all cards.

Command: boot each page at `?mode=7`, then dispatch one `click` on the toggle.

```
STEP6 biohack {"total":120,"visible":120,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"120 demos","url":""}
STEP6 indri   {"total":120,"visible":120,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"120 demos","url":""}
```

**PASS** — all 120 cards return, `aria-pressed` returns to `false`, the label and count revert, and
`mode` is deleted from the URL (`url: ""`).

### 7. On indri.studio, `Fractals + Mode 7` shows the six qualifying fractal cards; switching back to `All` restores all nine Mode 7 cards without clearing the toggle.

Command: boot indri.studio, click the toggle, click the `fractals` chip, then the `all` chip; then
(as a bonus probe of the specified empty state) click a category with no Mode 7 cards.

```
STEP7 afterMode7 {"visible":11,"pressed":"true","count":"11 Mode 7 demos","url":"?mode=7"}
STEP7 combined   {"visible":6,"pressed":"true","count":"6 Mode 7 demos in this category","url":"?mode=7"}
          slugs: ["buddhabrot","julia","mandel-display","mandel-double","mandel-float","mandel-oop"]
STEP7 backToAll  {"visible":11,"pressed":"true","count":"11 Mode 7 demos","url":"?mode=7"}
          slugs: ["apollo-daylight","avalanche","blossom","buddhabrot","julia","lzss-gallery",
                  "mandel-display","mandel-double","mandel-float","mandel-oop","svx2-fastrom-video"]
STEP7 emptyState {"cat":"ciphers","visible":0,"emptyHidden":false,
                  "emptyText":"No Mode 7 demos in this category.",
                  "controlRowStillThere":true,"pressed":"true"}
```

**PASS (with the systemic count caveat).** The step's own discriminating assertion — `Fractals +
Mode 7` yields **exactly six** cards — holds exactly, and they are the six expected fractal slugs.
Switching back to `All` restores the full Mode 7 set with the toggle still pressed and `?mode=7`
retained, which is the composition behaviour the step exists to test. The literal numeral "nine"
reads 11 for the cause already scored FAIL at steps 2 and 4; it is not an independent defect, so
it is noted rather than counted a third time. The empty-state contract is a bonus PASS: `ciphers +
Mode 7` renders the exact specified line `No Mode 7 demos in this category.`, keeps the control row
mounted, and clears neither filter.

### 8. On biohack.net, empty shelves disappear and reappear correctly; remaining shelves start at scroll position zero.

Command: boot biohack.net, pre-scroll every `.cat-row` to `scrollLeft = 120`, toggle Mode 7 on,
inspect every shelf, then toggle back off.

```
STEP8 {
 "shelfCount": 12,
 "hiddenBefore": 0,
 "hiddenDuring": 7,
 "visibleDuring": [{"n":6,"scrollLeft":0},{"n":1,"scrollLeft":0},{"n":2,"scrollLeft":0},
                   {"n":1,"scrollLeft":0},{"n":1,"scrollLeft":0}],
 "anyVisibleShelfWithZeroCards": false,
 "anyHiddenShelfWithCards": false,
 "hiddenAfter": 0,
 "allScrollLeftZero": true
}
```

**PASS** — of 12 shelves, 7 hide and 5 remain, and the partition is exactly right in both
directions: no visible shelf holds zero Mode 7 cards and no hidden shelf holds one (6 + 1 + 2 + 1 +
1 = 11, the full Mode 7 set). Every visible row was reset from `scrollLeft = 120` to `0`, and all
12 shelves reappear on clear.

Not covered by this step's evidence: **arrow visibility**. `updateShelfNav()` compares
`row.scrollWidth` against `row.clientWidth`, both identically `0` under jsdom's null layout, so its
result here is vacuous rather than verified. The plan's biohack.net requirement 5 ("disable/hide
shelf arrows when the filtered row does not overflow") is therefore untested — it rolls into the
step 10 gap below rather than being claimed as passing.

### 9. Keyboard activation, Escape-to-clear, focus ring, `aria-pressed`, and live count are verified.

Command: for each site, focus the toggle, dispatch the UA-synthesised `click` that Enter/Space
produces on a real `<button>`, then dispatch `Escape` from inside the gallery; read the ARIA
surface throughout. The focus ring is a CSS property with no jsdom equivalent, so it is read out of
the shipped stylesheet instead.

```
STEP9 biohack {"tagName":"BUTTON","type":"button","pressedInitial":"false",
               "labelInitial":"Show Mode 7 demos only","focusedIsToggle":true,
               "pressedAfterKeyActivate":"true","labelAfterKeyActivate":"Show all demos",
               "countAfterKeyActivate":"11 Mode 7 demos","hasGlWrap":true,
               "pressedAfterEscape":"false","focusReturnedToToggle":true,
               "countAriaLive":"polite","countAfterEscape":"120 demos","hiddenAttrUsed":true}
STEP9 indri   {"tagName":"BUTTON","type":"button","pressedInitial":"false",
               "labelInitial":"Show Mode 7 demos only","focusedIsToggle":true,
               "pressedAfterKeyActivate":"true","labelAfterKeyActivate":"Show all demos",
               "countAfterKeyActivate":"11 Mode 7 demos","hasGlWrap":true,
               "pressedAfterEscape":"false","focusReturnedToToggle":true,
               "countAriaLive":"polite","countAfterEscape":"120 demos","hiddenAttrUsed":true}

$ grep -o '\.gl-mode-toggle[^{]*:focus-visible{[^}]*}' biohack-ext.css indri.css
biohack: .gl-mode-toggle[data-astro-cid-7xccancv]:focus-visible{outline:2px solid var(--accent);outline-offset:3px}
indri:   .gl-mode-toggle[data-astro-cid-lxksxuin]:focus-visible{outline:2px solid var(--color-primary-container);outline-offset:3px}
```

**PASS** — identical on both sites. The control is a real `<button type="button">`, so keyboard
activation is native; activation flips `aria-pressed` and the accessible name; Escape while focus is
inside `.gl-wrap` clears the filter and returns focus to the toggle; the count element carries
`aria-live="polite"` and its text changes on every transition; hidden cards use the `hidden`
attribute (leaving the accessibility tree and tab order) rather than opacity; and both sites define
a `:focus-visible` outline from their own focus token.

### 10. Test at the narrowest supported phone width and with reduced motion.

Command: **none available.** No browser automation is installed on this host (no Playwright for
Node or Python, no headless Chromium driver), and jsdom implements no layout engine or media-query
matching, so neither a narrow-viewport render nor a `prefers-reduced-motion` render can be
executed. Recorded instead: a static read of the shipped stylesheets for the properties this step
would have exercised.

```
biohack {"toggle_min_height_44":true,"filter_row_wraps":true,"focus_visible_outline":true,
         "nonColor_active_cue_check":true,"nonColor_active_cue_inset":true,
         "any_card_opacity_transition":false}
indri   {"toggle_min_height_44":true,"filter_row_wraps":true,"focus_visible_outline":true,
         "nonColor_active_cue_check":true,"nonColor_active_cue_inset":true,
         "any_card_opacity_transition":false}
```

**FAIL — not executed.** The code-level proxy is favourable on every readable point: both toggles
set `min-height:44px` unconditionally (no narrow-width shrink rule exists), `.gl-mode-filter` is
`display:flex; flex-wrap:wrap` so the count wraps below without shrinking the target, active state
is conveyed by an inset bar **and** a `.gl-mode-check` mark in addition to colour, and filtering
carries **no** card transition at all — cards are shown and hidden by the `hidden` attribute, so
the reduced-motion requirement is satisfied by construction rather than by a media query. But a
proxy is not the test: this step asks for a rendered result at the narrowest supported width, and
that was not produced. It is the same unexecuted-browser-smoke gap #121 recorded, now also
carrying step 8's untested arrow-overflow behaviour.

### Summary

| Step | Result | Evidence |
|---|---|---|
| 1 | PASS | both deploy workflows `success` (`v1.0.365`, `v0.1.135`) |
| 2 | **FAIL** | 11 hooks / 11 named badges per site, not nine; build-time assertion + test file never implemented |
| 3 | PASS | 120/120 cards, `aria-pressed="false"`, no query string |
| 4 | **FAIL** | 11 slugs, not nine; identical set on both sites, superset of the committed nine |
| 5 | PASS | `?mode=7` active before any event, both sites |
| 6 | PASS | 120/120 restored, `mode` deleted from URL |
| 7 | PASS | `Fractals + Mode 7` = exactly 6; `All` restores set with toggle retained; empty state exact |
| 8 | PASS | 7/12 shelves hidden, partition exact, every visible row reset to `scrollLeft 0`, all restored |
| 9 | PASS | native `<button>`, Escape clears + refocuses, `aria-live="polite"`, `:focus-visible` outline |
| 10 | **FAIL** | not executed — no browser automation installed; CSS proxy recorded |

Three FAILs, two causes: the plan's "nine" is stale at 11 (steps 2 and 4, cause already established
in #121), and no rendering-browser check was ever run (step 10, carrying step 8's arrow-overflow
sub-case). No filter-behaviour defect was found — every 123-specific mechanism the harness could
drive behaved exactly as the plan specifies, on both sites, with the two galleries agreeing on an
identical Mode 7 set.
