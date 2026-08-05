# Dual SNES ROM site drift audit — biohack.net vs indri.studio

**Date:** 2026-08-03

**Verdict:** `ROM PARITY RESTORED; NON-ROM DRIFT REMAINS`

**Remediation:** indri.studio commit `2b78747`, release `v0.1.135`

**Sites:**

- `https://biohack.net/snes/`
- `https://indri.studio/apps/llvm-mos-65816/snes/`

## Scope and method

This audit compared the local publication repositories and their live deployments across:

- ROM filenames, sizes, and SHA-256 values;
- manifest inventory and normalized manifest entries;
- page-metadata coverage;
- preview inventory and SHA-256 values;
- player engine version records and synchronized asset hashes;
- live manifest identity, live ROM downloads, and representative page HTTP status.

Local publication roots were:

```text
/home/will/biohack.net/public/play
/home/will/indri.studio/public/apps/llvm-mos-65816/play
```

The downloaded live manifests were byte-identical to their corresponding repository manifests.
The differences below are therefore deployed publication state, not merely local worktree drift.

## Inventory summary

| Area | biohack.net | indri.studio | Difference |
|---|---:|---:|---|
| ROM files | 120 | 120 | identical inventory |
| Manifest entries | 120 | 120 | byte-identical manifests |
| Page metadata entries | 120 | 120 | complete coverage |
| ROMs without previews | 0 | 0 | none |
| Duplicate manifest IDs | 0 | 0 | none |
| ROM hash mismatches | — | — | 0 |
| Common preview hash mismatches | — | — | 2 |

Both sites have one extra non-ROM preview, `lzss-gallery-contact-sheet.png`. Every actual ROM on
each site has a corresponding preview, manifest entry, and playable page.

## Remediation result

The initial audit found five releases absent from indri.studio and one stale common ROM. Release
`v0.1.135` synchronized all six artifacts from the current biohack/project publication:

- added `apollo-daylight`;
- added `cartsize-exhirom-6m`;
- added `cartsize-exhirom-8m`;
- added `cartsize-hirom-4m`;
- added `seamdemo`;
- replaced indri's stale `lzss-gallery.sfc`.

The five releases were added with previews, manifest records, page metadata, and generated playable
routes. The indri build passed with 139 generated pages. Post-deploy checks downloaded all six live
ROMs, required their SHA-256 values to match biohack, and required HTTP 200 from all six playable
pages.

| Slug | Live SHA-256 | indri page | Match |
|---|---|---:|---:|
| `lzss-gallery` | `a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d` | 200 | yes |
| `apollo-daylight` | `a74142914170bec0a3bdce060928581ef2d979b426f011a552ce42b90441eda4` | 200 | yes |
| `cartsize-exhirom-6m` | `459ff309560c8c94f1307192b1a62ce5ce98b756de8a01b193301da618138255` | 200 | yes |
| `cartsize-exhirom-8m` | `b4359721416f9dbead84c115fe36ca97f207f5cfbc94d4a823ac5411c0928485` | 200 | yes |
| `cartsize-hirom-4m` | `071d68f116a73ae7d21265ce39684df680c519b0307321acd207eeb23e6b7130` | 200 | yes |
| `seamdemo` | `29dafeb5cad15e4356b21d6446ba1ff221ac495cc87690912bdf9d68bbdcbb5c` | 200 | yes |

## Resolved finding 1 — five releases were missing from indri.studio

The following releases exist as complete ROM, manifest, page-metadata, and preview records on
biohack.net but are absent from indri.studio:

| Slug | biohack live page | indri live page |
|---|---:|---:|
| `apollo-daylight` | HTTP 200 | HTTP 404 |
| `cartsize-exhirom-6m` | HTTP 200 | HTTP 404 |
| `cartsize-exhirom-8m` | HTTP 200 | HTTP 404 |
| `cartsize-hirom-4m` | HTTP 200 | HTTP 404 |
| `seamdemo` | HTTP 200 | HTTP 404 |

All five now return HTTP 200 on indri.studio and serve the same ROM bytes as biohack.net. The table
above records the original audit state; it is retained as incident history.

## Resolved finding 2 — `lzss-gallery.sfc` differed

The live sites serve different LZSS Gallery ROMs:

```text
biohack.net  a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d
indri.studio 726c421fb708956ccadbdf677c2d856eb4ae1103cd91cec7a590b8ba66ec8dcd
```

The current project build, `build/lzss-gallery.sfc`, matches biohack.net at
`a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d`.
Biohack includes the later gallery navigation restoration; indri retains the earlier ROM from its
2026-08-01 chevron publication.

The manifest self-check records are nevertheless identical on both sites:

```text
symbol=gallery_last_z off=0x473 len=2 want=0x3BC9 frames=12000
```

Indri now serves the biohack/current-project hash
`a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d`.
Manifest equality alone still does not prove artifact equality; the paired publishing gate must
keep its ROM SHA-256 check.

## Finding 3 — player bundle has false version parity

Both sites label the player package `@wbniv/bsnes-jg-player` version `1.0.0`, but every synchronized
bundle asset has a different SHA-256:

| Asset | biohack.net | indri.studio |
|---|---|---|
| `app.js` | `fdb8b71ef465…` | `100f4b5122e4…` |
| `cores/PROVENANCE.json` | `5927ba6e4126…` | `745f5d72dd5…` |
| `cores/bsnes_jg.js` | `54e19fd849b8…` | `33078eba5c52…` |
| `cores/bsnes_jg.wasm` | `e74dbd3d7160…` | `61397b181bd0…` |

The provenance records identify the same bsnes-jg 2.1.0 source archive and source SHA-256, but
different builds:

| Field | biohack.net | indri.studio |
|---|---|---|
| built | 2026-08-02T05:17:03Z | 2026-07-27T20:31:40Z |
| Emscripten | 6.0.4 | 6.0.1 |

Biohack's `app.js` also contains later startup/controller corrections absent from indri's bundle.
In particular, touch-navigation timer state and cleanup moved to player scope after the earlier
chevron implementation. Publishing different bytes under the same `1.0.0` label defeats package
versioning and makes cache/provenance diagnosis ambiguous.

## Finding 4 — preview drift

Two previews differ among otherwise common releases:

| Preview | Assessment |
|---|---|
| `trimerge.png` | indri has an older 256×224 capture; biohack has the later 60 fps scroll-ring presentation |
| `mandel-display.png` | both are 4×4 placeholders but differ in content; low visual impact, still unnecessary drift |

The five releases missing from indri also account for five missing previews there.

## Finding 5 — page metadata drift

Normalized common manifest entries are identical, apart from entries wholly missing on indri.
The site page metadata differs for two common releases:

- `svx2-fastrom-video`: biohack titles it `SVX2 60 FPS FastROM Video` and categorizes it as `video`;
  indri titles it `SVX2 FastROM Animated Video` and categorizes it as `rendering`.
- `lzss-gallery`: descriptions and key instructions differ. Biohack describes tapping the left or
  right half, while indri describes bounded visible chevrons. This corresponds to their different
  player/ROM navigation states and is not merely punctuation drift.

Site-specific route layout and page presentation are intentional; artifact identity, manifest
self-checks, and core player behavior should not diverge.

## Confirmed parity after remediation

- All 120 ROM filenames and SHA-256 values match.
- The two 120-entry manifests are byte-identical.
- All 120 manifest/self-check records match.
- Neither manifest contains duplicate ROM IDs.
- Every ROM present on a site has a preview and page-metadata record on that site.
- The published SVX2 ROM is byte-identical on both sites:

```text
c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2
```

Live SVX2 URLs:

- `https://biohack.net/snes/svx2-fastrom-video/`
- `https://biohack.net/play/roms/svx2-fastrom-video.sfc`
- `https://indri.studio/apps/llvm-mos-65816/snes/svx2-fastrom-video/`
- `https://indri.studio/apps/llvm-mos-65816/play/roms/svx2-fastrom-video.sfc`

## Remediation order

1. **Done:** publish the five missing releases to indri.studio with ROMs, previews, manifest
   entries, and page metadata.
2. **Done:** replace indri's `lzss-gallery.sfc` with the current biohack/project artifact and retain
   the matching self-check record.
3. **Pending:** synchronize `trimerge.png`; either synchronize or deliberately replace both 4×4 Mandelbrot
   placeholders.
4. **Pending:** release a new `@wbniv/bsnes-jg-player` version and sync the exact same engine bundle to both
   sites. Do not reuse `1.0.0` for another byte-distinct bundle.
5. **Pending:** reconcile shared titles/categories and keep only explicitly documented site-specific wording.
6. **Ongoing policy:** run `task publish-snes-rom-both-sites` for every subsequent ROM publication and require its four
   live URLs and paired SHA-256 verdict in the release handoff.

The paired gate is documented in [`snes-rom-dual-site-publishing.md`](../snes-rom-dual-site-publishing.md).
