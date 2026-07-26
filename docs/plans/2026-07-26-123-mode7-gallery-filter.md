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
