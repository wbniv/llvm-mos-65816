# HOWTO: bulk rebuild + republish the SNES demo web ROMs

When a **shared change touches every demo** — a `snesgfx/` header, the title-card font (`font16.h` /
`gen-font16.py`), a crt0/link tweak, or a toolchain rebuild — the 113 ROMs published on the site
(`biohack.net/public/play/roms/*.sfc`) are stale until recompiled and redeployed. This is that loop.
It's designed to run **often** and fast.

**TL;DR**

```
# 0. make the shared change + regenerate any baked asset, e.g. the title font:
python3 tools/gen-font16.py > examples/snes/font16.h

# 1. prove it on ONE representative demo with the full gate (host == +mos-a16 on MAME + bsnes-jg):
dev/run.sh boids

# 2. rebuild EVERY published ROM (one container, no gate) and sync into the site:
dev/publish-web-roms.sh            # --site ~/biohack.net by default

# 3. resync the manifest self-check offsets — REQUIRED whenever a shared struct changed size:
dev/sync-manifest-offsets.py       # --check to report drift without writing

# 4. verify EVERY ROM against the manifest (self-check + force-blank scan) before deploying:
dev/verify-web-roms.sh             # must print ALL PASS

# 5. commit the ROMs + manifest in the site repo, then deploy:
cd ~/biohack.net && git add public/play/roms && git commit -m "…" && task bump
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
- **Preview PNGs are untouched.** Previews are demo frames (not the title), so a title/asset change
  leaves them valid.
- **The manifest's `want` hashes are untouched — but its `off` values are NOT.** ⚠️ The self-check
  hashes are gate-neutral, so `want` survives a rebuild in any mode. `off`, however, is the **link
  address of `corpus_result`**, and that moves whenever a shared struct changes size. Growing snesgfx
  in 2026-07 moved **103 of 113** offsets (huffman `0x84` → `0x144b`); shipping the ROMs without
  resyncing would have left almost every page's "Verify fidelity" button asserting an address that no
  longer exists in its ROM. Step 3 is not optional after a struct-size change. (The per-demo
  `dev/<slug>.sh` gates are immune — they read the address from their own map at gate time.)

## The scripts

| Script | Runs | Does |
|---|---|---|
| `dev/rebuild-web-roms.sh` | **in-container** (via `dev/run.sh rebuild-web-roms …`) | compile `build/<slug>.sfc` + `build/<slug>.map` for each slug; fix SNES checksum. Args: slugs, or `@<listfile>`. |
| `dev/publish-web-roms.sh` | **host** | list slugs from `<site>/public/play/roms/*.sfc` → build them all in one container → copy the fresh `.sfc` into the site. Syncs whatever built even if some demos failed, reports the gap, exits non-zero. Does **not** deploy. |
| `dev/sync-manifest-offsets.py` | **host** | rewrite each demo's self-check `off` from `build/<slug>.map`. Only trusts a map when the built ROM is byte-identical to the shipped one — **a failed link still leaves a partial map behind**, and trusting it would aim the self-check at an address that exists only in a ROM that was never published. |
| `dev/verify-web-roms.sh` | **host** | replay EVERY shipped ROM against its manifest self-check in bsnes-jg + scan for force-blank bleed. The deploy gate. |

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
cd ~/biohack.net
git add public/play/roms                       # the fresh .sfc files only
git commit -m "snes: rebuild demo ROMs (<what changed>)"
task bump                                       # auto-bump patch tag + push → Cloudflare deploy
```

The `.astro` pages cache-bust each ROM by content hash, so a changed `.sfc` rebuilds its page
automatically — no page edits needed. **Publishing is user-triggered**; don't `task bump` without the
go-ahead.

## Per-demo specials (handled by `rebuild-web-roms.sh`)

- **Renamed slugs** — `SRCMAP`: `3d-wireframe→wireframe`, `buddhabrot→buddha`, `space-invaders→invaders`.
- **Binary assets** — `ASSET_EXTS`: `space-invaders` links `invaders.pic`/`.pal` (objcopy'd to `.o`).
- **ROM-size-tight** — `mandel-double` is at the near-window edge and cannot absorb the 4 KB `font16`
  table, so it **self-declares `TITLE_FONT16_FAR`** (+ `snes-far-platform`) in its own source, parking
  the table in bank $01 `.far_rodata`. Constraints live in the DEMO SOURCE, never in a build script —
  that is exactly how the old `-DTITLE_FONT16_OFF` drifted out of sync with the other build paths.
  **As of 2026-07-26 it no longer fits at all**: the title/upload rework added ~1.2 KB to every demo
  and this one is 138 bytes over. It is skipped by the bulk rebuild and keeps its previously published
  ROM (so it simply retains the older title animation — nothing regresses). Reclaiming those bytes is
  open; measured dead ends are recorded in the session plan (`display_frame`/`hscrollw_band` noinline
  and font8-in-far-ROM all make it *worse*; `SINCOS` is hot-loop and should not be banked).
- **No title card** (nothing to change, byte-identical after a title-font rebuild): `cordic`, `factorial`.
- **Mode-7 title** (`hilbert`, via `m7title.h`) is a *separate* title system but now **also uses the Waldo
  font16** (rendered as 256 Mode-7 8bpp tiles = 64 glyphs × 4). It changes on a font16 regen too.

## Gotchas

- **Hot shared tree.** `build/` and `vendor/` are shared with concurrent agents; the in-container build
  writes `build/<slug>.sfc` + `build/<slug>.buildlog`. Commit only the site's `public/play/roms/**`.
- **A new demo not yet on the site** won't be rebuilt (the list comes from the site's roms dir). Publish
  it first with the `snes-rom-page` skill, then it joins the bulk loop.
- **A genuinely default-8-only demo** builds via the fallback; if its hash ever differs from the manifest
  after an a16 attempt, that's a real 5-way-differential gap worth filing — not a publish problem to
  paper over.
