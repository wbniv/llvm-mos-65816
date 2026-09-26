# LZSS Gallery Palette-Range Audit — 2026-07-27

## Result

**PASS:** all 62 generated artwork rasters use only the currently implemented 219-index artwork
set:

```text
1–27, 32–111, 144–255
```

No compact artwork raster uses index `0` or any BG3, BG2, or OBJ-reserved index. Every generated
512-byte palette leaves all 37 non-artwork entries as deterministic BGR555 zero before the runtime
restores the UI colors.

This is a baseline investigation, not yet an enforced gate. The implementation plan is
[`#138`](../../docs/plans/2026-07-27-138-lzss-gallery-palette-range-audit.md).

## Scope and contract

Inputs:

- `assets/snes/lzss-gallery/derived/report.json`;
- all 62 `derived/*.idx` files;
- all 62 `derived/*.pal` files;
- `tools/lzss-gallery-assets.py`; and
- the palette upload/restore code in `examples/snes/lzss-gallery.c`.

Current ownership:

| Indices | Count | Owner | Audit expectation |
|---:|---:|---|---|
| `0` | 1 | Surround/partial-tile padding | Absent from compact `.idx`; zero in `.pal` |
| `1–27` | 27 | Artwork | Allowed |
| `28–31` | 4 | BG3 8×8 text | Absent from `.idx`; zero before restore |
| `32–111` | 80 | Artwork | Allowed |
| `112–127` | 16 | BG2 Waldo text | Absent from `.idx`; zero before restore |
| `128–143` | 16 | OBJ palette 0 | Absent from `.idx`; zero before restore |
| `144–255` | 112 | Artwork | Allowed |

The planned #136 contiguous `32–247` mapping is not implemented and was not used as the pass/fail
contract for this audit.

## Checks performed

For every work, the audit checked:

- `.idx` length equals `raw_indexed_bytes`;
- `.pal` is exactly 512 bytes;
- every pixel index belongs to the 219-entry allowed set;
- actual used indices equal `artwork_indices_used`;
- actual used count equals `artwork_colors_used`;
- palette SHA-256 equals `palette_sha256`;
- every reserved palette word is zero; and
- every palette word has BGR555 bit 15 clear.

Corpus-level checks confirmed exactly 62 report records, 62 `.idx` files, and 62 `.pal` files. The
union of indices used by the corpus covers all 219 allowed artwork indices and contains no
forbidden index.

## Per-work results

Sixty works use all 219 available artwork indices. `tableau-vii` uses 216 and
`thai-temple-painting` uses 175; using fewer colors is valid.

| Work | Used indices | Actual ranges | Forbidden pixels | Nonzero reserved palette entries | Result |
|---|---:|---|---:|---:|---|
| great-wave | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| grande-jatte | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| water-lilies | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| basket-apples | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| stack-wheat | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| self-portrait | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| paris-street | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| poppy-field | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| earthly-delights | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| the-scream | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| third-of-may | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| the-kiss | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| view-of-delft | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| wijk-windmill | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| flower-still-life | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| sunflowers | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| tableau-vii | 216 | `1–27, 32–111, 144–149, 151–216, 218–224, 226–255` | 0 | 0 | PASS |
| ice-skaters | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| home-heron | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| dragon | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| scholar-landscape | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| houses-parliament | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thistles | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| starry-night | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| river-moonlight | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| mountain-waterfall | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| wooded-merrymakers | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| wide-river | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| sailing-vessels | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| ships-calm | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| st-odulphus | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| voyage-childhood | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| voyage-youth | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| voyage-manhood | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| voyage-old-age | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| tornado-forest | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| niagara | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| fog-mount-desert | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| buffalo-storm | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| mount-corcoran | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| sunset-woods | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| harvest-moon | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| wivenhoe-park | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| stormy-sunset | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| keelmen-moonlight | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| approach-venice | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| mortlake-terrace | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| pantheon-interior | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| grand-canal-molo | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| louvre-rain | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| marly-le-roi | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| the-willows | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| mount-akiha | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| fujisawa-shuku | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-temple-painting | 175 | `1–27, 32–111, 144–211` | 0 | 0 | PASS |
| thai-buddha-descending | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-elephant-duel | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-ravan-palace | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-surasa-hanuman | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-hanuman | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-hanuman-longka | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |
| thai-ravana-war | 219 | `1–27, 32–111, 144–255` | 0 | 0 | PASS |

## Runtime review

`palette()` uploads all 512 palette bytes, then restores the used BG3 and BG2 font colors and calls
`write_reserved_obj_palette()`. That helper writes OBJ entries `128–133` as one contiguous run.
Artwork cannot be damaged by these restores because its indexed pixels exclude the entire
`28–31`, `112–143` reservation.

The remaining reserved entries stay zero. This is intentional: current font and sprite graphics do
not use every pen in their conservatively reserved palettes.

## Additional quality observation

Range correctness passed, but the audit exposed a separate measurement worth retaining:
quantization happens in 24-bit RGB before conversion to 15-bit BGR555. Consequently, distinct
quantizer colors can collapse to identical SNES colors. This is not a palette-range violation.

Three works have used indices whose emitted BGR555 value is black:

- `earthly-delights`: indices `247–255`;
- `wide-river`: index `255`; and
- `thai-temple-painting`: indices `204–211`.

Those values may represent legitimate near-black source colors, but the future audit script should
report BGR555 collisions and zero-valued used colors as quality metrics. A separate visual/color
optimization effort may quantize directly in BGR555 space; it should not be folded into the
range-enforcement change without its own comparison and approval.

## Gaps

The current generator asserts that generated pixels belong to `ART_INDICES`, but there is no
standalone corpus audit, no Taskfile target, and no publication gate. It also does not independently
assert every reserved palette word is zero or reconcile the filesystem inventory with
`report.json`. Plan #138 closes those enforcement gaps.

