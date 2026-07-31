#!/usr/bin/env python3
"""Resync the site manifest's selfcheck `off` values to freshly rebuilt ROMs.

The player's in-browser "Verify fidelity" check reads LEN little-endian bytes of WRAM at `off` and
asserts they equal `want`. `want` is mode-invariant (the battery is a 5-way differential, so a
rebuild in a different mode keeps the hash) — but `off` is the LINK ADDRESS of corpus_result, and
that moves whenever a shared struct changes size. Growing snesgfx moved huffman's from 0x84 to
0x144b, which would have left all 113 pages asserting a stale address and reporting a false
fidelity failure to visitors.

Reads build/<slug>.map (emitted by dev/rebuild-web-roms.sh) for each demo in the manifest and
rewrites `off` where it changed. Never touches `want`, `len` or `frames`.

Most demos assert `corpus_result`, so that is the default symbol. A demo whose self-check targets a
different field declares it as `"symbol": "<name>"` inside its `selfcheck` object — without that,
this script would resync such an entry to `corpus_result`'s address and silently point the button
at the wrong field. `lzss-gallery` is the first: its button asserts one artwork's repacked size via
`gallery_last_z`, not the whole-corpus `corpus_result`
(see docs/plans/2026-07-28-gallery-per-image-selfcheck.md).

  dev/sync-manifest-offsets.py                 # update ~/biohack.net's manifest in place
  dev/sync-manifest-offsets.py --check         # report drift, change nothing (exit 1 if any)
  dev/sync-manifest-offsets.py --site DIR
"""
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def symbol_addr(mapfile: pathlib.Path, symbol: str = "corpus_result"):
    """Return the WRAM address of `symbol` from an ld.lld map, or None."""
    try:
        for line in mapfile.read_text(errors="replace").splitlines():
            # map rows end with the symbol name; the first column is the address
            row = line.rstrip()
            if row.endswith(symbol) and row.split()[-1] == symbol:
                m = re.match(r"\s*([0-9a-fA-F]+)\s", line)
                if m:
                    return int(m.group(1), 16)
    except OSError:
        return None
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=str(pathlib.Path.home() / "biohack.net"))
    ap.add_argument("--check", action="store_true", help="report drift only, exit 1 if any")
    args = ap.parse_args()

    manifest = pathlib.Path(args.site) / "public/play/roms/manifest.json"
    data = json.loads(manifest.read_text())

    changed, missing, same = [], [], 0
    for rom in data["roms"]:
        sc = rom.get("selfcheck")
        if not sc:
            continue
        # A FAILED link still leaves a partial build/<slug>.map behind, and trusting it would rewrite
        # the offset of a demo whose site ROM was never replaced — pointing the self-check at an
        # address that exists only in a ROM that does not exist. Only trust the map when the built
        # ROM is byte-identical to the one actually on the site.
        built = ROOT / "build" / f"{rom['id']}.sfc"
        shipped = pathlib.Path(args.site) / "public/play/roms" / f"{rom['id']}.sfc"
        if not (built.is_file() and shipped.is_file()
                and built.read_bytes() == shipped.read_bytes()):
            missing.append(rom["id"])
            continue
        symbol = sc.get("symbol", "corpus_result")
        addr = symbol_addr(ROOT / "build" / f"{rom['id']}.map", symbol)
        if addr is None:
            missing.append(rom["id"])
            continue
        old = int(str(sc["off"]), 16)
        if old == addr:
            same += 1
        else:
            changed.append((rom["id"], old, addr, symbol))
            sc["off"] = f"0x{addr:x}"

    for slug, old, new, symbol in changed:
        print(f"  {slug:16s} {symbol:18s} off 0x{old:x} -> 0x{new:x}")
    if missing:
        print(f"  no map for: {' '.join(missing)}")
    print(f"\n{len(changed)} offset(s) changed, {same} unchanged, {len(missing)} without a map")

    if args.check:
        return 1 if changed else 0
    if changed:
        manifest.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {manifest}")
    if missing:
        print("REFUSING to treat this as complete — a demo without a map keeps a possibly stale off",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
