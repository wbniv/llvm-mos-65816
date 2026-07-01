# Plan: Categories + Netflix-style SNES gallery

**Date:** 2026-07-01
**Scope:** `biohack.net` + `snes-rom-page` skill

---

## Context

The `/snes/` gallery lists 87 demos in a flat 2-column card grid — newest first, all categories
jumbled together. Categories already exist as H2 section headers in the ideas doc but live nowhere
in the site. Individual ROM pages have no category label.

Goals:
1. Add a `category` field to the existing `demos` array in `index.astro` (no new file — just
   extend the array entries the skill already writes to)
2. Define a `categories` const at the top of `index.astro` as the taxonomy source
3. Redesign `/snes/` as a Netflix-style horizontal-shelf layout (one shelf per category)
4. Add a category chip to individual ROM pages — `{{CATEGORY_ID}}` + `{{CATEGORY_LABEL}}`
   placeholders in `page-template.astro`
5. Update the `snes-rom-page` skill: add `category` input + update step 4 (now adds
   `category` to the `demos` entry) + update step 3 (replace new template placeholders)
6. Apply the chip immediately to `hilbert.astro` and verify

---

## Mockups

### Current index — 2-column grid (crowded at 87 demos)

```
┌─────────────────────────────────────────────────────────────────┐
│  SNES DEMOS                                                     │
│  87 demos compiled from C...                                    │
│                                                                 │
│  ┌────────────┐ ┌────────────┐  ← #72  #71                     │
│  │  [thumb]   │ │  [thumb]   │                                  │
│  │ 3-D Voxel  │ │  Marching  │                                  │
│  │    Life    │ │   Squares  │                                  │
│  │ long desc  │ │ long desc  │                                  │
│  └────────────┘ └────────────┘                                  │
│  ┌────────────┐ ┌────────────┐  ← #70  #69 ...×42 more rows    │
│  │  [thumb]   │ │  [thumb]   │                                  │
│  │  Dither    │ │  Gouraud   │                                  │
│  └────────────┘ └────────────┘                                  │
│  ... 42 more rows of 2 ...                                      │
└─────────────────────────────────────────────────────────────────┘
```

### New index — category shelves (Netflix-style)

```
┌─────────────────────────────────────────────────────────────────┐
│  ← biohack.net                                                  │
│  SNES DEMOS                                                     │
│  87 Super Nintendo programs compiled from C...                  │
│                                                                 │
│  FRACTALS ─────────────────────────────────────── [‹] [›]      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │[img] │ │[img] │ │[img] │ │[img] │ │[img] │ │[img] │──►    │
│  │Julia │ │Newton│ │Burn. │ │Buddh.│ │Mandel│ │L-Sys.│       │
│  │Set   │ │Fract.│ │Ship  │ │brot  │ │Float │ │Plant │       │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘       │
│                                                                 │
│  PHYSICS & SIMULATION ─────────────────────────── [‹] [›]      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐               │
│  │[img] │ │[img] │ │[img] │ │[img] │ │[img] │──►            │
│  │N-Body│ │Dbl   │ │Ray-  │ │3-D   │ │Barnes│               │
│  │Orbits│ │Pend. │ │caster│ │Wire  │ │  Hut │               │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘               │
│                                                                 │
│  CELLULAR AUTOMATA ────────────────────────────── [‹] [›]      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                         │
│  │[img] │ │[img] │ │[img] │ │[img] │──►                      │
│  │Life  │ │1-D CA│ │Doom  │ │Reac- │                         │
│  │      │ │      │ │Fire  │ │Diff  │                         │
│  └──────┘ └──────┘ └──────┘ └──────┘                         │
│  ... 7 more rows ...                                            │
└─────────────────────────────────────────────────────────────────┘
```

Key UX decisions:
- Cards are narrower (~180 px) so 4–5 fit on desktop; on mobile (~375 px) 2.5 are visible
  (the half-card signals "more to scroll" — the Netflix peekaboo trick)
- `overflow-x: auto; scroll-snap-type: x mandatory` + `scroll-snap-align: start` on each card
- `[‹]` / `[›]` JS arrow buttons for mouse users; touch users flick naturally
- Long `desc` is NOT shown on shelf cards (it's on the individual ROM page); cards show
  thumbnail + title + keys only — keeps the shelf visually clean and dense
- Hover: card lifts with orange glow, ▶ overlay appears (same as current)

### Category chip on individual ROM page (hilbert example)

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│                  HILBERT CURVE                           │
│            [MOTION & CURVES]                             │  ← chip
│                                                          │
│   An order-4 Hilbert space-filling curve traced...       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

Chip style: small pill, `font-size: 11px`, `letter-spacing: 0.12em`, `text-transform: uppercase`,
`background: var(--bg-soft)`, `border: 1px solid var(--rule)`, `color: var(--ink-dim)`. Centred
under the title (hero is already `text-align: center`). Links back to `/snes/#cat-<id>` so
clicking it deep-links back to the right shelf row on the gallery.

---

## Category taxonomy

Defined as a `const categories` at the top of `index.astro` (not a separate file):

```ts
const categories = [
  { id: 'fractals',   label: 'Fractals' },
  { id: 'physics',    label: 'Physics & Simulation' },
  { id: 'cellular',   label: 'Cellular Automata' },
  { id: 'motion',     label: 'Motion & Curves' },
  { id: 'algorithms', label: 'Algorithms & Data' },
  { id: 'rendering',  label: 'Rendering & Graphics' },
  { id: 'signals',    label: 'Signals & Crypto' },
  { id: 'bignums',    label: 'Big Numbers' },
  { id: 'ciphers',    label: 'Ciphers & Bit Tricks' },
  { id: 'classics',   label: 'Games & Classics' },
];
```

Representative assignments (full mapping is implementation work):

| id | Example slugs |
|---|---|
| `fractals` | julia, newton, burning-ship, buddhabrot, mandel-float, mandel-double, fn-plot |
| `physics` | n-body, double-pendulum, raycaster, 3d-wireframe, bhut, boids |
| `cellular` | life, 1d-ca, doom-fire, rdiff, msquares, percol, grid3d |
| `motion` | harmonograph, epicycles, spirograph, cordic, cardioid, **hilbert**, lsystem, vaprintf |
| `algorithms` | sort-race, maze, spigot, factorial, hull, editdist, radix, fenwick, huffman |
| `rendering` | gouraud, perlin, dither, rotozoom, medfilt, domcol, hdr-bloom, polyfill, seqvm, disbits |
| `signals` | fft, iir-scope, crctex, cgrade, dhmix |
| `bignums` | avalanche, multibase |
| `ciphers` | tea, truchet, bitcensus, bitshuffle, gf256, critters |
| `classics` | space-invaders, blossom, turtle-vm, qsortviz, poolfx, cosmzoom |

---

## Files to modify

### 1. `biohack.net/src/pages/snes/index.astro` — add categories + Netflix shelf layout

**Data changes (frontmatter):**
- Add `const categories = [...]` above the existing `const demos = [...]`
- Add `category: 'id'` field to every entry in `demos` (all 87 + any new ones like `funnelkal`);
  the rest of each entry (`slug`, `title`, `desc`, `keys`) is unchanged

**Shelf rendering (replacing the `<ul class="gl-grid">`)**:

```ts
const byCategory = categories.map(cat => ({
  ...cat,
  items: demos.filter(d => d.category === cat.id),
})).filter(c => c.items.length > 0);
```

Then render:
```astro
{byCategory.map(({ id, label, items }) => (
  <section class="cat-shelf" id={`cat-${id}`}>
    <div class="cat-header">
      <h2 class="cat-title">{label}</h2>
      <div class="cat-nav">
        <button class="cat-prev" aria-label={`Scroll ${label} left`}>‹</button>
        <button class="cat-next" aria-label={`Scroll ${label} right`}>›</button>
      </div>
    </div>
    <ul class="cat-row" role="list">
      {items.map(({ slug, title, keys }) => (
        <li class="cat-card">
          <a href={`/snes/${slug}/`} class="cat-card-link" aria-label={`Play ${title}`}>
            <div class="cat-thumb-wrap">
              <img class="cat-thumb"
                src={`/play/preview/${slug}.png${previewV(slug) ? `?v=${previewV(slug)}` : ''}`}
                alt={`${title} preview`} width="256" height="224" loading="lazy" decoding="async" />
              <div class="cat-play-overlay" aria-hidden="true">▶</div>
            </div>
            <div class="cat-card-body">
              <h3 class="cat-card-title">{title}</h3>
              <p class="cat-card-keys">{keys}</p>
            </div>
          </a>
        </li>
      ))}
    </ul>
  </section>
))}
```

**New CSS** (`.cat-*`; old `.gl-*` rules can be removed):
```css
.cat-shelf { margin-bottom: 2.5rem; }
.cat-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .75rem; }
.cat-title  { font-size: 11px; font-weight: 700; letter-spacing: .22em; text-transform: uppercase;
              color: var(--ink-dim); margin: 0; }
.cat-nav    { display: flex; gap: .4rem; }
.cat-prev, .cat-next {
  background: transparent; color: var(--ink-dim); cursor: pointer;
  font-size: 14px; font-family: 'JetBrains Mono', ui-monospace, monospace;
  border: 1px solid var(--accent-soft); border-radius: 6px; padding: .2rem .6rem;
  transition: border-color .15s, color .15s;
}
.cat-prev:hover, .cat-next:hover { border-color: var(--accent); color: var(--accent); }

.cat-row {
  display: flex; gap: 10px; list-style: none; padding: 0 0 4px; margin: 0;
  overflow-x: auto; scroll-snap-type: x mandatory; -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.cat-row::-webkit-scrollbar { display: none; }
.cat-card { flex: 0 0 180px; scroll-snap-align: start; border: 1px solid var(--rule);
            background: var(--bg-soft); border-radius: 8px; overflow: hidden;
            transition: border-color .2s, box-shadow .2s; }
.cat-card:hover { border-color: var(--accent); box-shadow: 0 0 20px rgba(194,65,12,.3); }
.cat-card-link { display: flex; flex-direction: column; text-decoration: none; color: inherit; height: 100%; }
.cat-thumb-wrap { position: relative; background: #000; line-height: 0; overflow: hidden; }
.cat-thumb { display: block; width: 100%; height: auto; aspect-ratio: 256/224;
             image-rendering: pixelated; object-fit: cover; transition: opacity .2s; }
.cat-card:hover .cat-thumb { opacity: .82; }
.cat-play-overlay { position: absolute; inset: 0; display: flex; align-items: center;
                    justify-content: center; font-size: 1.8rem; color: rgba(255,255,255,.9);
                    text-shadow: 0 0 20px rgba(194,65,12,.9),0 0 4px rgba(0,0,0,.8);
                    opacity: 0; transition: opacity .2s; pointer-events: none; }
.cat-card:hover .cat-play-overlay { opacity: 1; }
.cat-card-body  { padding: .6rem .75rem .75rem; }
.cat-card-title { margin: 0; font-size: 13px; font-weight: 600; color: var(--ink); transition: color .15s; }
.cat-card:hover .cat-card-title { color: var(--accent); }
.cat-card-keys  { margin: .3rem 0 0; font-size: 10px; font-family: 'JetBrains Mono', ui-monospace, monospace;
                  color: var(--ink-dim); opacity: .65; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
@media (max-width: 520px) { .cat-card { flex: 0 0 140px; } }
```

**Inline JS for arrow buttons** (`<script is:inline>` at bottom of page):
```js
document.querySelectorAll('.cat-shelf').forEach(shelf => {
  const row = shelf.querySelector('.cat-row');
  const scrollAmt = () => Math.floor(row.clientWidth * 0.85);
  shelf.querySelector('.cat-prev')?.addEventListener('click', () =>
    row.scrollBy({ left: -scrollAmt(), behavior: 'smooth' }));
  shelf.querySelector('.cat-next')?.addEventListener('click', () =>
    row.scrollBy({ left:  scrollAmt(), behavior: 'smooth' }));
});
```

### 2. `snes-rom-page/page-template.astro` — add `{{CATEGORY_ID}}` + `{{CATEGORY_LABEL}}`

In `.rp-hero`, after `<h1 class="rp-title">{{TITLE}}</h1>`:
```html
<a href="/snes/#cat-{{CATEGORY_ID}}" class="rp-cat-chip">{{CATEGORY_LABEL}}</a>
```

Add to the `<style>` block:
```css
.rp-cat-chip {
  display: inline-block; margin-top: .5rem; padding: 3px 10px;
  font-size: 11px; letter-spacing: .12em; text-transform: uppercase;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  color: var(--ink-dim); background: var(--bg-soft, #1e2128);
  border: 1px solid var(--rule, #2e3138); border-radius: 4px;
  text-decoration: none; transition: border-color .15s, color .15s;
}
.rp-cat-chip:hover { border-color: var(--accent); color: var(--accent); }
```

### 3. `snes-rom-page/SKILL.md` — update inputs + steps 3 & 4

**Inputs:** add `category` — the id from `index.astro`'s `categories` list (e.g. `motion`);
derive the human label (e.g. `Motion & Curves`) for `{{CATEGORY_LABEL}}`.

**Step 3:** add to the placeholder replacement list:
> `{{CATEGORY_ID}}` → the category id · `{{CATEGORY_LABEL}}` → the human label

**Step 4:** update the gallery entry shape:
```js
{
  slug: '<slug>',
  title: '<Title>',
  desc: '<desc>',
  keys: '<keys>',
  category: '<category-id>',   // ← new
},
```

### 4. `biohack.net/src/pages/snes/hilbert.astro` — add chip (verify target)

After `<h1 class="rp-title">Hilbert Curve</h1>`:
```html
<a href="/snes/#cat-motion" class="rp-cat-chip">Motion & Curves</a>
```

Add `.rp-cat-chip` CSS to the page's `<style>` block.

---

## Execution order

1. Edit `index.astro`: add `categories` const + `category` field to all 87 `demos` entries +
   replace grid HTML/CSS with Netflix shelf markup/CSS + add inline JS
2. Edit `page-template.astro`: add chip placeholder + CSS
3. Edit `SKILL.md`: update inputs + step 3 + step 4
4. Edit `hilbert.astro`: add chip + CSS
5. Build + verify

---

## Verification

1. `cd ~/SRC/biohack.net && task build` — zero errors
2. Serve locally: `python3 -m http.server 8799 --directory dist &`
3. `/snes/` renders Netflix-style category shelves (not a flat grid)
4. `/snes/hilbert/` shows "MOTION & CURVES" chip below the title, linked to `/snes/#cat-motion`
5. Clicking the chip → browser jumps to the Motion & Curves shelf
6. Narrow viewport (375 px): ~2.5 cards visible in the first shelf (peekaboo effect)
7. Arrow buttons `[‹]` `[›]` advance/retreat the shelf on desktop
8. Total cards across all shelves = 87 (no demo dropped)
9. Cache-busting still works (`?v=<sha>` on thumbnails)
