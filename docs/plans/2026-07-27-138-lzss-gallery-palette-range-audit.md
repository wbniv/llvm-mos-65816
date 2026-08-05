# #138 — LZSS Gallery Artwork Palette-Range Audit

**Status:** PLANNED  
**Baseline investigation:** [`reports/investigations/2026-07-27-lzss-gallery-palette-range-audit.md`](../../reports/investigations/2026-07-27-lzss-gallery-palette-range-audit.md)

## Goal

Turn the one-time 62-work palette-range audit into a deterministic gate which proves that every
generated artwork raster, palette, and report record obeys the currently implemented sparse CGRAM
contract:

| CGRAM indices | Owner |
|---:|---|
| `0` | Black surround and partial-tile padding |
| `1–27` | Artwork |
| `28–31` | BG3 8×8 text |
| `32–111` | Artwork |
| `112–127` | BG2 Waldo text |
| `128–143` | OBJ palette 0 |
| `144–255` | Artwork |

The implemented artwork set is therefore `1–27, 32–111, 144–255` (219 possible indices). This
plan audits that contract; it does **not** silently adopt #136's planned contiguous `32–247`
mapping. When #136 is implemented, it must update the machine-readable contract and the same audit
must validate the new range.

## Deliverables

### 1. Machine-readable palette contract

Have `tools/lzss-gallery-assets.py` emit
`assets/snes/lzss-gallery/derived/palette-contract.json` containing:

- mapping/version name;
- allowed artwork ranges;
- index `0` padding/surround role;
- BG2, BG3, and OBJ reserved ranges;
- runtime-restored entries and their roles;
- palette byte length and BGR555 constraints; and
- the expected maximum artwork-color count.

The generator remains the owner of the mapping. The audit script consumes this output instead of
maintaining an independent numeric copy.

### 2. Audit script

Add executable `tools/lzss-gallery-palette-audit.py`. It must inspect every record in
`derived/report.json` and fail on any of the following:

1. missing or extra `.idx`, `.pal`, or report records;
2. `.idx` length differing from `raw_indexed_bytes`;
3. `.pal` length other than 512 bytes;
4. any artwork pixel outside the contract's artwork ranges;
5. index `0` appearing in the compact artwork raster (padding is added later during tile upload);
6. any generated non-artwork palette entry being nonzero before runtime restoration;
7. mismatch between actual used indices, `artwork_indices_used`, and `artwork_colors_used`;
8. mismatch between the palette file and `palette_sha256`;
9. any BGR555 word with bit 15 set;
10. missing coverage metadata for a catalogued work; or
11. a runtime palette restore range which disagrees with the generated contract.

The script should report lower-than-capacity paintings as informational, not failures. A work need
not use all 219 indices. Likewise, multiple RGB colors may quantize to the same BGR555 word; record
that as a quality metric, separately from range correctness.

Output:

- a concise human-readable table on stdout;
- `--json <path>` for automation; and
- `--markdown <path>` for a reproducible investigation appendix.

The default command must be read-only. Output files are written only when explicitly requested.

### 3. Taskfile entry

Connect the script to `Taskfile.yml`:

```yaml
lzss-gallery-palette-audit:
  desc: Audit every gallery raster and palette against the generated CGRAM ownership contract
  cmds:
    - dev/run.sh lzss-gallery-palette-audit
```

Add `dev/lzss-gallery-palette-audit.sh` as the container entry point. It invokes the Python script
from `/work`, installs nothing on the host, and propagates the script's exit status. Forward
optional output arguments through `{{.CLI_ARGS}}` or the existing `dev/run.sh` argument path.

The normal gallery verification/publish path must call this task before accepting or publishing a
new corpus. A palette audit failure blocks the ROM build and both website publications.

### 4. Runtime-contract check

The static portion of the script must inspect `examples/snes/lzss-gallery.c` or, preferably, consume
generated C constants so that it can prove:

- the full 512-byte artwork palette is uploaded;
- BG3 entries `28–31` are restored;
- BG2 entries `112–127` remain reserved, with the used font entries restored;
- OBJ entries `128–143` remain reserved, with visible pens restored by
  `write_reserved_obj_palette()`; and
- artwork pixels cannot reference any of those overwritten entries.

Do not treat zero-filled unused entries as an error. The current runtime intentionally restores
only the pens used by its font and sprite graphics.

## Verification

The completed gate must pass all of these tests:

- current 62-work corpus: PASS;
- mutate one `.idx` byte to each forbidden range: FAIL with work, byte offset, and index;
- mutate a reserved `.pal` word: FAIL with work and CGRAM index;
- truncate a palette or raster: FAIL with expected and actual sizes;
- alter `palette_sha256` or used-index metadata: FAIL;
- add an unreported `.idx`/`.pal`: FAIL;
- set BGR555 bit 15: FAIL;
- run in the development container with no host installation; and
- leave the worktree unchanged in default read-only mode.

## Documentation updates

After implementation:

1. regenerate the investigation appendix with the new script;
2. link the audit from #125 and the gallery build/publish documentation;
3. record the exact task command and commit SHA in the investigation;
4. update #136 to name this gate as a required migration test; and
5. mark this plan implemented only after the task is enforced in the normal build/publication
   pipeline.

