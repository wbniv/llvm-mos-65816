# Cache-Control headers for biohack.net SNES demos

## Context

After deploying a new spigot.sfc ROM, the user on mobile had to hard-refresh to pick up the new
assets. Hard refresh is awkward on mobile Chrome. The root cause: all SNES demo pages already
have build-time SHA-256 cache busting (`?v=<sha>` on every asset URL), but there are no explicit
`Cache-Control` headers on the site. Without headers, browsers can serve stale HTML from their
local cache — if the HTML is stale, the old hashes are used and the old ROM is loaded.

## How the existing cache busting works

Every demo page (8 total: spigot, blossom, spirograph, 1d-ca, 3d-wireframe, double-pendulum,
n-body, space-invaders) computes SHA-256 hashes of 7 assets at Astro build time and injects them
into the page as `window.BJG_BUST`. app.js's `bust(path)` function appends `?v=<sha>` to every
asset request (ROM, manifest.json, cores, app.js itself). This means asset URLs are
content-addressed — when a file changes, its URL changes, forcing a cache miss. This is solid.

The gap: the HTML page itself has no cache headers. After a deploy, browsers may serve stale HTML
(with old hashes) without checking. No `?v=` param on the page URL — it's a normal `/snes/spigot/`
path. On mobile, `Cache-Control: public, max-age=0, must-revalidate` (Cloudflare Pages default)
requires conditional revalidation, but bfcache restores pages without any network request at all.

## Fix: one `_headers` file

Add `public/_headers` (Cloudflare Pages reads this from the build output; Astro copies `public/`
to `dist/` as-is):

```
# HTML: always revalidate — fresh ETags after every deploy, no stale page state
/*
  Cache-Control: public, max-age=0, must-revalidate

# Versioned play assets — app.js bust() always uses ?v=<sha>; bare URLs only in dev
/play/*
  Cache-Control: public, max-age=31536000, immutable
```

**Why `must-revalidate` not `no-store`:** `no-store` disables bfcache entirely (instant back
navigation breaks). `must-revalidate` forces a conditional GET on any page load; Cloudflare
returns 304 (same HTML) or 200 (new HTML after deploy). A normal pull-to-refresh or tap-on-URL
triggers this revalidation. Only bfcache (back/forward swipe) skips it — acceptable trade-off.

**Why immutable for `/play/*`:** the `bust()` function in app.js uses `?v=sha` for all play
assets. A changed file gets a new URL → new cache entry. The bare URL (no query param) is never
requested by the app. Immutable caching on the CDN side eliminates 304 round-trips for the heavy
WASM core (~4 MB) on repeat visits.

## Files to change

- **Create** `~/SRC/biohack.net/public/_headers` (new file, contents above)
- No changes to any demo pages, Base.astro, or astro.config.mjs

## Verification

After deploying:
```sh
curl -sI https://biohack.net/snes/spigot/ | grep -i cache-control
# → Cache-Control: public, max-age=0, must-revalidate

curl -sI "https://biohack.net/play/roms/spigot.sfc" | grep -i cache-control
# → Cache-Control: public, max-age=31536000, immutable
```

Then deploy a dummy ROM change (touch spigot.sfc, redeploy) and verify a normal mobile
pull-to-refresh (not hard refresh) picks up the new hash and loads the new ROM.

### Verified 2026-06-29 — PASS

Step 1 — page Cache-Control:

```
$ curl -sI https://biohack.net/snes/spigot/ | grep -i cache-control
cache-control: public, max-age=0, must-revalidate
```

PASS — HTML revalidates on every load.

Step 2 — versioned play asset Cache-Control:

```
$ curl -sI "https://biohack.net/play/roms/spigot.sfc" | grep -i cache-control
cache-control: public, max-age=31536000, immutable
```

PASS — `/play/*` is immutably cached.

**Implementation note:** the deployed `public/_headers` declares only the `/play/*` immutable
rule and relies on Cloudflare Pages' built-in default (`max-age=0, must-revalidate`) for HTML —
deliberately, so a `/*` rule can't bleed `must-revalidate` into the immutable `/play/*` entries.
The observed live behaviour matches the plan's intent exactly.

Step 3 — fresh-ROM pickup on redeploy: proven end-to-end by the real `v1.0.121` republish
(doom-fire/rdiff/1d-ca got new ROM binaries). The live `/play/roms/<slug>.sfc` `sha256` matched
the freshly-built committed ROMs immediately after deploy, so the `?v=<sha>` busting + revalidating
HTML served the new content without a hard refresh. PASS (no dummy touch needed — a real ROM swap
exercised the same path).
