---
name: snes-rom-page
description: >-
  Publish a playable in-browser SNES emulator page for a .sfc ROM on an Astro static site
  (indri.studio or biohack.net). Copies the shared bsnes-jg WASM player, adds the ROM + a
  manifest entry, scaffolds a /<slug> page (centred player + controls/instructions) from a
  template, then builds + deploys per the site. Use when the user wants to put a SNES ROM
  online as a playable page. Triggers: "publish <rom> to <site>", "add an emulator page",
  "put this rom on the site", "make a playable page for <rom>".
---

# snes-rom-page

Turn a SNES `.sfc` ROM into a playable `/<slug>` page on an Astro static site. The page boots the
**bsnes-jg WASM** core (the same cycle-accurate core the llvm-mos-65816 differential gate trusts),
shows the ROM on a centred canvas, and carries the controls/instructions. The mechanical asset setup
is `scaffold.sh`; the page is written from `page-template.astro`. The bsnes-jg engine (~4 MB) is
vendored in `engine/`, so the skill is **fully self-contained** — no external/machine-local paths,
safe to distribute.

## Inputs

- **ROM** — path to the `.sfc` (required).
- **slug** — URL path + manifest id, lowercase `[a-z0-9-]` (e.g. `blossom`).
- **title** + one-line **description**.
- **category** — one of the ids from `index.astro`'s `categories` list (e.g. `motion`). Derive
  the human label from that list too (e.g. `Motion & Curves`) for `{{CATEGORY_LABEL}}`. Current
  ids: `fractals`, `physics`, `cellular`, `motion`, `algorithms`, `rendering`, `signals`,
  `bignums`, `ciphers`, `classics`.
- **controls / instructions** — what the buttons do + a short "what is it" (the ROM author knows; ask
  if unclear). The keys are fixed by the player (below) — you map them to the ROM's actions.
- optional **preview** PNG (256×224) shown while the core downloads.
- optional **selfcheck** — a WRAM assert that mirrors the build gate (see below).

## Steps

1. **Pick the site** from the request and `cd` to its repo (see *Per-site* below). Confirm it's an
   Astro site (`src/pages/`, `src/layouts/Base.astro`).

2. **Scaffold the assets** (engine + ROM + preview + manifest):

   ```sh
   "$(git rev-parse --show-toplevel)/.claude/skills/snes-rom-page/scaffold.sh" \
     --rom /path/to/<slug>.sfc --slug <slug> --site <SITE_DIR> \
     --title "Title" --preview /path/to/preview.png \
     --selfcheck "0xOFF 2 0xWANT FRAMES label text"     # optional
   ```
   It writes `public/play/{app.js,cores/*,roms/<slug>.sfc,roms/manifest.json,preview/<slug>.png}`,
   copying the engine from the skill's bundled **`engine/`** (self-contained — no external paths).
   Pass `--player-src DIR` only to re-sync the engine from a newer `bsnes-jg-wasm` build.

3. **Write the page** `src/pages/<slug>.astro` from `page-template.astro`:
   - Replace `{{SLUG}}` `{{TITLE}}` `{{DESC}}` `{{KEYS_LINE}}` `{{INSTRUCTIONS}}`
     `{{CATEGORY_ID}}` `{{CATEGORY_LABEL}}`.
   - Set the `controls` array (keys → action) and the `{{KEYS_LINE}}` one-liner to the ROM's mapping.
   - Brand it to the site (set `--rp-accent`, swap colours/props — *Per-site*). The template's layout
     + the **natural-aspect canvas** (no `overflow:hidden`/`object-fit`) and **centred player**
     (`margin-inline:auto`) are load-bearing — keep them; they fix a top-scanline clip and centre it.
   - Keep `<div id="game">`/`#screen`/`#status`/`#verify`/`#fullscreen`/`#banner` ids and the boot
     `<script>` — app.js drives them and pauses when the canvas scrolls out of view. `#fullscreen`
     wires a Fullscreen button (hidden automatically on browsers without the API).

4. **Register the demo on the gallery page** (`src/pages/snes/index.astro` on biohack.net, skipped for
   indri.studio unless it has one). Add a new entry to the `demos` array:

   ```js
   {
     slug: '<slug>',
     title: '<Title>',
     desc: '<One or two sentences: what it renders, the technique, any notable constraint.>',
     keys: '<compact key-hint line matching the page's controls, e.g. "← → move · Z/X fire">',
     category: '<category-id>',
   },
   ```

   Keep `desc` to 2 sentences max — the card is small. The `keys` line is rendered in monospace at
   11 px; keep it under ~60 chars so it doesn't truncate on a 2-column card.

5. **Build, then VERIFY before deploying.** Two distinct things to check:

   - **Does the ROM render?** A **bsnes-jg screenshot of the ROM is sufficient** — the page boots the
     *same* bsnes-jg WASM core, so the build gate's `build/<slug>-jg.png` (or any bsnes-jg render of
     the exact ROM you're shipping; confirm the sha matches what's deployed) already proves the picture
     renders. **No Chrome needed for this** — don't block the publish on a browser screenshot you can't
     run. (When in doubt that the deployed `.sfc` is the one you rendered: `sha256sum` both.)
   - **Is the page shell intact?** (core boots in-browser, HUD/text not clipped, player centred.) This is
     a per-*page* concern, unchanged by the ROM, so it only needs checking when you edited the
     `.astro`/template — and it's the *only* thing the Chrome shot adds over the bsnes-jg render. If
     Chrome is available and you changed the page, screenshot it; otherwise verify the page serves
     (`curl -o/dev/null -w '%{http_code}'`) and trust the unchanged template.

   ```sh
   cd <SITE_DIR> && task build
   # Optional page-shell shot (only if Chrome is present AND you edited the page):
   ( python3 -m http.server 8799 --directory dist & sleep 1
     google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
       --window-size=1000,1400 --virtual-time-budget=9000 \
       --screenshot=/tmp/<slug>.png "http://localhost:8799/<slug>/" )
   ```
   (`--virtual-time-budget` fast-forwards so the ROM runs to a live frame.) On a republish that only
   swaps the ROM/preview/manifest, the bsnes-jg render + an HTTP 200 check is the verification.

6. **Commit, then deploy** per the site (*Per-site*).

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

### indri.studio (`~/SRC/indri.studio`) — Astro 6 + Tailwind + Cloudflare **Workers**
- `Base.astro` props: `title`, `description`, `ogImage`, `ringFlare={false}`. Set
  `ogImage={new URL('/play/preview/<slug>.png', Astro.site ?? 'https://indri.studio').href}`.
- Brand: grey + neon‑purple. Set `--rp-accent: #b026ff;` (or use the page as-is). Tokens in
  `src/styles/global.css`.
- Deploy: `task deploy` (build + `wrangler deploy`; `CLOUDFLARE_API_TOKEN` in `.env`). HTML is served
  `no-store`, so it goes live on reload — no cache purge.

### biohack.net (`~/SRC/biohack.net`) — Astro 5 static + Cloudflare **Pages**
- `Base.astro` props: `title`, `description` only.
- Brand: dark + orange cyberpunk (`--bg #16171a`, `--ink #e8e6e0`, `--accent #c2410c`; fonts Dune
  Rise / Blade Runner / Space Grotesk in `global.css`). Set `--rp-accent: var(--accent);` and use the
  display font for the title (`font-family:'Dune Rise',...; text-transform:uppercase`).
- Deploy is **tag-driven** (GitHub Actions → Cloudflare Pages): `git add` + `git commit`, then
  `task publish TAG=vX.Y.Z` (or `task release` to auto-bump the patch) — it tags and pushes
  `origin master` + the tag. Creds live in CI secrets (`CF_PAGES_API_TOKEN`), not locally.

## Commit discipline

Stage only the files this run created/edited — `public/play/**` (engine, ROM, preview, manifest) and
`src/pages/<slug>.astro`. Verify `git diff --cached --name-only`. The engine blobs are ~4 MB
(`bsnes_jg.wasm`); that's expected for the first ROM on a site, free for subsequent ones.
