# HOWTO: bulk rebuild + republish the SNES demo web ROMs

When a **shared change touches every demo** — a `snesgfx/` header, the title-card font (`font16.h` /
`gen-font16.py`), a crt0/link tweak, or a toolchain rebuild — the ~93 ROMs published on the site
(`biohack.net/public/play/roms/*.sfc`) are stale until recompiled and redeployed. This is that loop.
It's designed to run **often** and fast.

**TL;DR**

```
# 0. make the shared change + regenerate any baked asset, e.g. the title font:
python3 tools/gen-font16.py > examples/snes/font16.h

# 1. prove it on ONE representative demo with the full gate (host == +mos-a16 on MAME + bsnes-jg):
dev/run.sh boids

# 2. rebuild EVERY published ROM (one container, no gate) and sync into the site:
dev/publish-web-roms.sh            # --site ~/SRC/biohack.net by default

# 3. commit the ROMs in the site repo, then deploy:
cd ~/SRC/biohack.net && git add public/play/roms && git commit -m "…" && task release
```

## Why it's fast (and still correct)

- **One container, no gate.** `dev/rebuild-web-roms.sh` runs inside the dev image and compiles each
  `build/<slug>.sfc` with a single `mos-clang` call — no emulator, no MAME, no render. That's the slow
  part and it's unnecessary here: a shared title/asset change is **gate-neutral** (the title fires
  before `title_end`, outside every corpus CRC).
- **Uniform `+mos-a16 -Os`.** The battery is a **5-way differential** (`host == default == +mos-a16 ==
  +mos-xy16`), so each demo's corpus/gate hash is **mode-invariant** — an a16 rebuild keeps the manifest
  self-check `want` hash even for demos originally shipped default-8. Demos that won't build in a16 fall
  back to default-8 automatically (same hash). No `-verify-machineinstrs` — some demos ride the
  documented `a16-rc-undef` `-verify` known issue while emitting correct code.
- **Preview PNGs + manifest are untouched.** Previews are demo frames (not the title), and the
  self-check hashes are gate-neutral, so a font/asset change leaves both valid.

## The scripts

| Script | Runs | Does |
|---|---|---|
| `dev/rebuild-web-roms.sh` | **in-container** (via `dev/run.sh rebuild-web-roms …`) | compile `build/<slug>.sfc` for each slug; fix SNES checksum. Args: slugs, or `@<listfile>`. |
| `dev/publish-web-roms.sh` | **host** | list slugs from `<site>/public/play/roms/*.sfc` → build them all in one container → copy the fresh `.sfc` into the site. Does **not** deploy. |

Slug→source is 1:1 except `3d-wireframe→wireframe`, `buddhabrot→buddha`, `space-invaders→invaders`
(kept in `SRCMAP` in `dev/rebuild-web-roms.sh` — extend it if a new renamed slug appears).

## Verify before you deploy

1. **Full gate on one demo** (step 1 above) proves the shared change didn't break codegen — pick a demo
   whose title exercises the change (e.g. a name with the new glyphs).
2. **Spot self-check a handful** against the manifest to confirm mode-invariance held:

   ```
   # asserts corpus_result == the manifest 'want' for a few rebuilt ROMs, bsnes-jg only (fast):
   dev/run.sh boids        # or any demo's own gate
   ```

   Any hash mismatch means a demo's build mode changed its result — investigate that demo before
   deploying (should not happen for 5-way-green demos).
3. **Title capture** (optional visual proof): render an early frame of a built ROM with the bsnes-jg
   harness and eyeball the title, e.g. `~/waldo/waldofont build/boids.sfc 200 /tmp/t` → `/tmp/t.png`.

## Deploy (site side)

`biohack.net` deploys via Cloudflare on a tagged push. After syncing + committing the ROMs:

```
cd ~/SRC/biohack.net
git add public/play/roms                       # the fresh .sfc files only
git commit -m "snes: rebuild demo ROMs (<what changed>)"
task release                                    # auto-bump patch tag + push → Cloudflare deploy
```

The `.astro` pages cache-bust each ROM by content hash, so a changed `.sfc` rebuilds its page
automatically — no page edits needed. **Publishing is user-triggered**; don't `task release` without the
go-ahead.

## Per-demo specials (handled by `rebuild-web-roms.sh`)

- **Renamed slugs** — `SRCMAP`: `3d-wireframe→wireframe`, `buddhabrot→buddha`, `space-invaders→invaders`.
- **Binary assets** — `ASSET_EXTS`: `space-invaders` links `invaders.pic`/`.pal` (objcopy'd to `.o`).
- **ROM-size-tight** — `EXTRA_CFLAGS`: `mandel-double` is at the exact 32 KB bank edge and can't absorb
  the ~4 KB `font16` table, so it builds with **`-DTITLE_FONT16_OFF`** (title_layer.h falls back to the
  no-table pixel-doubled font8; chunky title, but it fits). Add other edge demos here if a future asset
  pushes them over.
- **Not on the 16×16 title path** (left unchanged by a font16 swap): demos with **no title** (`cordic`,
  `factorial`) and the one **Mode-7 title** demo `hilbert` (`m7title.h` renders font8 at 8×8 in Mode 7 —
  a separate system). These are expected byte-identical after a title-font-only rebuild.

## Gotchas

- **Hot shared tree.** `build/` and `vendor/` are shared with concurrent agents; the in-container build
  writes `build/<slug>.sfc` + `build/<slug>.buildlog`. Commit only the site's `public/play/roms/**`.
- **A new demo not yet on the site** won't be rebuilt (the list comes from the site's roms dir). Publish
  it first with the `snes-rom-page` skill, then it joins the bulk loop.
- **A genuinely default-8-only demo** builds via the fallback; if its hash ever differs from the manifest
  after an a16 attempt, that's a real 5-way-differential gap worth filing — not a publish problem to
  paper over.
