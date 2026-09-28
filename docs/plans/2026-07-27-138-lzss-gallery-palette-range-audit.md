# #138 — LZSS Gallery Artwork Palette-Range Audit

**Status:** IMPLEMENTED 2026-09-28

**Baseline investigation:** [`reports/investigations/2026-07-27-lzss-gallery-palette-range-audit.md`](../../reports/investigations/2026-07-27-lzss-gallery-palette-range-audit.md)

## Why this was planned

The July 27 baseline inspected all 62 generated artworks and passed, but it was a one-time report rather than a repeatable gate. The generator already constrained newly produced artwork pixels to its color range; it did not recheck checked-in `.idx`/`.pal` files against `report.json`, confirm reserved sprite entries stayed clear, or check the current runtime restore point. The plan arose from that enforcement gap and the reserved-palette concern recorded during #128 work.

The original plan overstated the scope by requiring a separate generated contract, report outputs, and a broader static runtime analysis. Those deliverables were unnecessary for the concrete gap: the generator is already the owner of the palette map, and a focused audit can read its constants directly. The original palette ranges in the baseline report are dated evidence and do not describe the current build.

## Current contract

| CGRAM indices | Owner |
|---:|---|
| `0` | Black surround and padding |
| `1–2` | Static dashboard inks |
| `3–223` | 221 artwork colors |
| `224–255` | Runtime-restored sprite colors |

The current 62-work corpus oracle is `0x9512`. The historical 26-work oracle `0x3D44` is unrelated to this palette audit.

## Implemented gate

[`tools/lzss-gallery-palette-audit.py`](../../tools/lzss-gallery-palette-audit.py) checks that the enabled manifest, report, and raster/palette file inventories agree; validates raster lengths, allowed pixel indices, used-index metadata, palette hashes, BGR555 words, static inks, black entry zero, and zero-filled sprite entries before runtime restoration; and confirms the runtime restore starts at CGRAM 224. It derives the artwork range and static ink values from `tools/lzss-gallery-assets.py` so the audit does not maintain a second numeric palette map.

The audit runs as a standalone task (`task lzss-gallery-palette-audit`) and before compilation in the normal gallery gate (`task lzss-gallery`). Its default mode is read-only. The audit does not optimize palette quality or judge quantization collisions; those remain visual-quality questions rather than ownership violations.

## Verification record

- `python3 tools/lzss-gallery-palette-audit.py` — PASS, 62 works.
- The audit checks `.idx` and `.pal` inventory, metadata, hashes, palette ownership, BGR555 validity, and the current runtime sprite restore entry point.
- The normal gallery gate invokes the audit before the ROM build.
