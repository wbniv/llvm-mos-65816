---
name: snes-rom-page
description: >-
  Publish a playable in-browser SNES emulator page for a .sfc ROM on an Astro static site
  (indri.studio or biohack.net). The player engine comes from the @wbniv/bsnes-jg-player npm
  package (synced + drift-stamped by its CLI); this skill adds the ROM + manifest entry and the
  site's data-driven registry entry (a content-collection JSON file on biohack.net, a TS array
  entry on indri.studio — both sites render every demo page from one shared route), then builds +
  deploys per the site. Use when the user wants to put a SNES ROM online as a playable page.
  Triggers: "publish <rom> to <site>", "add an emulator page", "put this rom on the site", "make a
  playable page for <rom>".
---

# snes-rom-page

Turn a SNES `.sfc` ROM into a playable page on an Astro static site. The page boots the
**bsnes-jg WASM** core (the same cycle-accurate core the llvm-mos-65816 differential gate trusts).
Both sites render **every** demo from one shared dynamic route (`src/pages/snes/[slug].astro` on
biohack.net, `src/pages/apps/llvm-mos-65816/snes/[slug].astro` on indri.studio) driven by a
per-site data registry — there is no per-ROM page file to write or edit. `scaffold.sh` does the
mechanical asset work (engine sync + ROM + preview + manifest); the per-site registry entry is
written by the skill/agent per *Per-site* below. The engine (app.js + cores) is **not vendored
here** — it ships in the
[`@wbniv/bsnes-jg-player`](https://github.com/wbniv/bsnes-jg-wasm) npm package, which each site
installs and syncs via the package's own CLI (drift-gated in the site's CI by `sync --check`).

> ⚠️ **Never hand-edit the installed `public/play/app.js`.** It's synced from the
> `@wbniv/bsnes-jg-player` package, not authored here — a hand-edit gets silently clobbered by the
> next `scaffold.sh`/`sync` run on any ROM. Fix it upstream in `@wbniv/bsnes-jg-player` and re-sync.

> **History:** this skill's repo-local copy previously (1) bundled a raw `engine/` fallback with its
> own PROVENANCE-timestamp gate, retired in [`5e75e65`](https://github.com/wbniv/llvm-mos-65816/commit/5e75e65)
> in favor of the CLI-delegated sync above, matching the canonical `~/.claude/skills/snes-rom-page`
> copy's 2026-07-27 migration; and (2) scaffolded a per-slug `page-template.astro` file + a
> hand-maintained gallery `demos` array, both retired here in favor of the two sites' actual current
> architecture — a single shared route per site reading a data registry (content collection JSON on
> biohack.net, a TS array on indri.studio) — confirmed against both sites' live HEAD, not assumed.

## Inputs

- **ROM** — path to the `.sfc` (required).
- **slug** — URL path + manifest id, lowercase `[a-z0-9-]` (e.g. `blossom`).
- **title** + one-line **description**.
- **category** — one of: `fractals`, `physics`, `cellular`, `motion`, `algorithms`, `rendering`,
  `signals`, `bignums`, `ciphers`, `classics` (biohack.net: `src/data/snes-categories.ts`; indri.studio
  hardcodes the same ten as a label map in its gallery + demo route). Drives the category chip and
  gallery grouping automatically — no separate label to write.
- **controls / instructions** — what the buttons do + a short "what is it" (the ROM author knows; ask
  if unclear). The keys are fixed by the player (below) — you map them to the ROM's actions.
- optional **preview** PNG (256×224) shown while the core downloads.
- optional **selfcheck** — a WRAM assert that mirrors the build gate (see below).
- optional **touchNav** — canvas tap rects for ROMs that draw their own prev/next chevrons (e.g.
  lzss-gallery): `--touchnav "LX LY LW LH RX RY RW RH"` (logical px, mapped to pad Left/Right).

## Steps

1. **Pick the site** from the request and `cd` to its repo (see *Per-site* below). Confirm it's an
   Astro site (`src/pages/`, `src/layouts/Base.astro`). If `@wbniv/bsnes-jg-player` isn't in its
   `package.json` yet: `pnpm add @wbniv/bsnes-jg-player` (or the git URL
   `github:wbniv/bsnes-jg-wasm#npm-package` until the first npm publish).

2. **Scaffold the assets** (engine sync + ROM + preview + manifest):

   ```sh
   ~/llvm-mos-65816/.claude/skills/snes-rom-page/scaffold.sh \
     --rom /path/to/<slug>.sfc --slug <slug> --site <SITE_DIR> \
     --title "Title" --preview /path/to/preview.png \
     --playdir public/play \
     --selfcheck "0xOFF 2 0xWANT FRAMES label text"     # optional
   ```
   It writes `<playdir>/{app.js,cores/*,roms/<slug>.sfc,roms/manifest.json,preview/<slug>.png}`.
   `--playdir` defaults to `public/play`; **indri.studio needs
   `--playdir public/apps/llvm-mos-65816/play`** instead (see *Per-site*). The engine is synced from
   the site's installed `@wbniv/bsnes-jg-player` package (via the package's own CLI) — ROMs, preview,
   and manifest are site content the CLI never touches. (The scaffold path above is absolute so it
   resolves regardless of the site repo you've `cd`'d into — `git rev-parse --show-toplevel` at that
   point would resolve to the *site's* root, not this one.)

3. **Add the site's registry entry.** Neither site has a per-ROM page file or a separate
   "register on the gallery" step any more — the gallery, the homepage count, and the per-demo
   route all read the *same* entry, so writing it once is the whole job. See *Per-site* for the
   exact file, schema, and an example to copy the shape from.

4. **Build, then VERIFY before deploying.** Two distinct things to check:

   - **Does the ROM render?** A **bsnes-jg screenshot of the ROM is sufficient** — the page boots the
     *same* bsnes-jg WASM core, so the build gate's `build/<slug>-jg.png` (or any bsnes-jg render of
     the exact ROM you're shipping; confirm the sha matches what's deployed) already proves the picture
     renders. **No Chrome needed for this** — don't block the publish on a browser screenshot you can't
     run. (When in doubt that the deployed `.sfc` is the one you rendered: `sha256sum` both.)
   - **Did the build's collection/array count check pass?** biohack.net's `[slug].astro` throws at
     build time if `src/content/snes/` doesn't have as many entries as `roms/manifest.json` has ROMs
     — `task build` failing with a "SNES demo count mismatch" error means the registry entry is
     missing or the manifest has a stale extra ROM. There's no shared page template to break any
     more, so a normal ROM-only publish needs no browser screenshot at all — the build's own count
     check plus the bsnes-jg render is the verification.
   - **Only if you edited the shared route itself** (`[slug].astro`, rare): screenshot it —
     `google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --window-size=1000,1400
     --virtual-time-budget=9000 --screenshot=/tmp/<slug>.png "http://localhost:8799/snes/<slug>/"`
     against `task build && python3 -m http.server 8799 --directory dist` — and confirm nothing is
     clipped and the player is centred, since that change is shared across every demo page.

   ```sh
   cd <SITE_DIR> && task build
   ```

5. **Commit, then deploy** per the site (*Per-site*).

## The player's keyboard map (fixed, from app.js)

| Key | SNES | | Key | SNES |
|---|---|---|---|---|
| Arrows | D-pad | | **Z** / **X** | B / A |
| **A** / **S** | Y / X | | **Q** / **W** | L / R |
| **Enter** | Start | | **Shift** | Select |

Write the page's controls as *action ← key* (e.g. for an attractor demo: `Q/W` zoom, `X/A` cycle
attractor, `Shift` colour, `Enter` reset, arrows pan). Don't document desktop-emulator defaults —
they're irrelevant to the in-browser player.

## Selfcheck (optional, recommended)

If the ROM's build gate asserts a WRAM value (e.g. a CRC/hash in `corpus_result`), pass
`--selfcheck "0xOFF LEN 0xWANT FRAMES label"` — the page's **Verify fidelity** button powers on, runs
`FRAMES` frames, reads `LEN` little-endian bytes of WRAM at `OFF`, and asserts `== WANT`, reproducing
the headless gate live in the tab. `OFF` is the WRAM offset of the symbol (from the ROM's `.map`),
`FRAMES` must be enough for the value to be set. Omit if the ROM has no such gate.

## Per-site

Both routes below are **shared, stable code that a normal ROM publish never touches** — page title,
og-image, branding colours, and the Fullscreen/canvas markup are all derived generically from the
registry entry (`demo.title`/`demo.desc`/`demo.slug`/`demo.category`) inside the route itself.
Authoring a new ROM means writing *only* the registry entry below; there is nothing else to set.

### biohack.net (`~/biohack.net`) — Astro 5 static + Cloudflare **Pages**
- **Registry**: create `src/content/snes/<slug>.json` — one JSON file per ROM, the `snes` content
  collection (schema: `src/content.config.ts`; route: `src/pages/snes/[slug].astro`; gallery:
  `src/pages/snes/index.astro`; also feeds the homepage's demo count). Fields:
  - `order` (int) — gallery position; append = current max + 1.
  - `slug`, `title`, `desc` (≤2 sentences — the gallery card is small), `keys` (compact key-hint
    line, e.g. `"← → move · Z/X fire"`, ~60 chars — it's rendered in 11 px monospace on a
    2-column card).
  - `category` — one of the ids above.
  - `displayMode` (optional int, e.g. `7` for a Mode 7 demo).
  - `pageTitle` (`"<Title> — bioHACK•NET"`), `pageDesc` (meta description), `heading` (h1 inner
    HTML), `lede` (hero paragraph inner HTML), `keysHtml` (array of key-help line(s), inner HTML),
    `doc` (the whole notes section inner HTML — `<h2>` sections, `<p>`, `<pre class="rp-code">`,
    `.rp-table` rows, `.rp-foot`). Required for a normal demo — `[slug].astro` only *skips*
    generating a page for entries that omit `doc` (used for the one demo, `lzss-gallery`, that
    keeps a hand-written page because its content derives from a build-time catalog); such entries
    still need order/slug/title/desc/keys/category for the gallery card + count.
  - Copy an existing entry (e.g. `src/content/snes/julia.json`) as the shape reference — prose
    fields are HTML strings rendered with `set:html`, not markdown.
  - The build's `getStaticPaths` **throws** if the collection's entry count ≠ `roms/manifest.json`'s
    ROM count — the registry entry and the manifest entry from step 2 must land together.
- Deploy is **tag-driven** (GitHub Actions → Cloudflare Pages): `git add` + `git commit`, then
  `task bump` (auto-increments the patch tag, e.g. v1.0.244→v1.0.245, and pushes `origin master` +
  the tag) — or `task publish TAG=vX.Y.Z` for an explicit tag. (There is **no** `task release`.)
  Creds live in CI secrets (`CF_PAGES_API_TOKEN`), not locally. On a hot tree, a concurrent agent's
  `git add -A` can sweep your content-entry/manifest edits into *their* commit — verify the deployed
  HEAD is consistent (all of registry entry + manifest + rom + preview present) before/after `task bump`.

### indri.studio (`~/indri.studio`) — Astro 6 + Tailwind + Cloudflare **Workers**
- **Assets live under `public/apps/llvm-mos-65816/play/`, not `public/play/`** — pass
  `--playdir public/apps/llvm-mos-65816/play` to `scaffold.sh` in step 2, or it writes to the wrong
  place. (`scripts/sync-llvm-mos-emulator.sh`, which `pnpm run sync-engine` wraps, hardcodes the same
  path for a standalone re-sync.)
- **Registry**: append one object to the `SNES_DEMOS` array in `src/data/snes-demos.ts` (interface
  `SnesDemo`, same file; route: `src/pages/apps/llvm-mos-65816/snes/[slug].astro`; gallery:
  `src/pages/apps/llvm-mos-65816/snes/index.astro`). Fields:
  - `slug`, `displayMode?` (e.g. `7`), `title`, `desc`, `keys`, `category` (same ids as biohack.net —
    the route hardcodes its own id→label map, so no separate label file to touch).
  - `controls` — `[key, action][]` tuples (e.g. `[["← →", "move"], ["Z / X", "fire"]]`), or `null`
    for a self-running demo (the route checks `demo.keys.toLowerCase().startsWith("self-running")`
    for wording elsewhere, but `controls: null` is what suppresses the Controls table).
  - `selfcheck` — `{off, len, want, frames, label}`, matching the `--selfcheck` value passed to
    `scaffold.sh` **exactly**: the page displays it in the footer, but `app.js` re-reads the real
    check from `roms/manifest.json` at runtime — the two must agree or the footer text lies.
  - `bugFound?` / `works?` — optional fields used by a handful of existing entries (a guarded
    pre-existing compiler bug; the lzss-gallery corpus catalog). Omit both for a normal ROM.
- Deploy: `task deploy` (build + `wrangler deploy`; `CLOUDFLARE_API_TOKEN` in `.env`). HTML is served
  `no-store`, so it goes live on reload — no cache purge.

## Commit discipline

Stage only the files this run created/edited — `public/apps/llvm-mos-65816/play/**` or
`public/play/**` (ROM, preview, manifest — engine files only when the `@wbniv/bsnes-jg-player`
package version was bumped, since sync is otherwise a no-op) and the registry entry
(`src/content/snes/<slug>.json` on biohack.net, the appended object in `src/data/snes-demos.ts` on
indri.studio). Verify `git diff --cached --name-only`.
