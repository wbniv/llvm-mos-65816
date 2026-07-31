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

The same file also carries the second thing that drifts: a per-work ORACLE TABLE. A `live-record`
self-check (the gallery's "verify the artwork on screen" button) does not compare against a scalar
`want` — the ROM publishes which work is displayed and what it repacked that work to, and the
player looks the expected size up in a table the HOST compressor produced. Hand-maintaining 62
numbers across every corpus regeneration is exactly the drift that left `frames` at 200000 through
five corpus expansions, so the table is generated, not written:

  "selfcheck": {
    "oracleFrom": {"report": "assets/snes/lzss-gallery/derived/report.json",
                   "value": "compressed_bytes", "title": "title"},
    "oracle": [15305, ...],          <- materialized here, in report.json array order
    "titles": ["Under the Wave …"]   <- materialized only when `title` is declared
  }

Resyncing it is gated on the same "built ROM is byte-identical to the shipped ROM" check as `off`:
a table describing a corpus the shipped ROM was not built from is worse than a stale one, because
it reports a per-artwork MISMATCH to visitors for a ROM that is in fact correct.

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


def oracle_tables(spec: dict):
    """Return {"oracle": [...], "titles": [...]} built from the host report `spec` names.

    Raises SystemExit on a malformed spec — a silently skipped table would ship a stale oracle,
    which is the exact failure this generator exists to prevent.
    """
    report = ROOT / spec["report"]
    rows = json.loads(report.read_text())
    if not isinstance(rows, list) or not rows:
        raise SystemExit(f"FATAL: {report} is not a non-empty JSON array")
    out = {}
    value_key = spec["value"]
    try:
        out["oracle"] = [int(r[value_key]) for r in rows]
    except KeyError:
        raise SystemExit(f"FATAL: {report} rows have no '{value_key}' field")
    # The record the player reads publishes `z` as a uint16; an oracle entry that cannot be
    # represented there would compare unequal forever rather than fail loudly.
    bad = [v for v in out["oracle"] if not 0 <= v <= 0xffff]
    if bad:
        raise SystemExit(f"FATAL: {report} '{value_key}' out of uint16 range: {bad[:4]}")
    if spec.get("title"):
        out["titles"] = [str(r[spec["title"]]) for r in rows]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=str(pathlib.Path.home() / "biohack.net"))
    ap.add_argument("--check", action="store_true", help="report drift only, exit 1 if any")
    args = ap.parse_args()

    manifest = pathlib.Path(args.site) / "public/play/roms/manifest.json"
    data = json.loads(manifest.read_text())

    changed, missing, same, tables = [], [], 0, []
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

        # Per-work oracle table, regenerated from the host report (see module docstring).
        spec = sc.get("oracleFrom")
        if spec:
            for key, values in oracle_tables(spec).items():
                if sc.get(key) != values:
                    tables.append((rom["id"], key, len(sc.get(key) or []), len(values)))
                    sc[key] = values

    for slug, old, new, symbol in changed:
        print(f"  {slug:16s} {symbol:18s} off 0x{old:x} -> 0x{new:x}")
    for slug, key, was, now in tables:
        print(f"  {slug:16s} {key:18s} table {was} -> {now} entries (regenerated)")
    if missing:
        print(f"  no map for: {' '.join(missing)}")
    print(f"\n{len(changed)} offset(s) changed, {same} unchanged, "
          f"{len(tables)} table(s) regenerated, {len(missing)} without a map")

    if args.check:
        return 1 if (changed or tables) else 0
    if changed or tables:
        manifest.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {manifest}")
    if missing:
        print("REFUSING to treat this as complete — a demo without a map keeps a possibly stale off",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
