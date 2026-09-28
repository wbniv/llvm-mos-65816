#!/usr/bin/env python3
"""Check checked-in LZSS gallery assets against the asset generator's palette map."""
import ast
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/snes/lzss-gallery/derived"
GENERATOR = ROOT / "tools/lzss-gallery-assets.py"


def palette_map():
    tree = ast.parse(GENERATOR.read_text())
    values = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name in {"ART_INDICES", "DASHBOARD_INK", "DASHBOARD_DARK"}:
                values[name] = ast.literal_eval(node.value) if name != "ART_INDICES" else None
                if name == "ART_INDICES":
                    call = node.value
                    if not (isinstance(call, ast.Call) and isinstance(call.func, ast.Name) and call.func.id == "tuple"
                            and len(call.args) == 1 and isinstance(call.args[0], ast.Call)
                            and isinstance(call.args[0].func, ast.Name) and call.args[0].func.id == "range"):
                        raise ValueError("ART_INDICES must remain a tuple(range(start, stop))")
                    values[name] = tuple(range(*(ast.literal_eval(x) for x in call.args[0].args)))
    if set(values) != {"ART_INDICES", "DASHBOARD_INK", "DASHBOARD_DARK"}:
        raise ValueError("generator is missing palette ownership constants")
    return values


def bgr555(rgb):
    r, g, b = (v >> 3 for v in rgb)
    return r | (g << 5) | (b << 10)


def run():
    errors = []
    mapping = palette_map()
    art = set(mapping["ART_INDICES"])
    if not art or min(art) < 0 or max(art) > 255:
        raise ValueError("invalid ART_INDICES in asset generator")
    report_path = ASSETS / "report.json"
    report = json.loads(report_path.read_text())
    spec = json.loads((ROOT / "assets/snes/lzss-gallery/sources.json").read_text())
    slugs = {w["slug"] for w in spec["works"] if w.get("enabled", True)}
    records = {item["slug"]: item for item in report}
    if len(records) != len(report) or set(records) != slugs:
        errors.append(f"manifest/report slug mismatch: manifest={len(slugs)} report={len(records)}")
    expected = slugs
    for suffix in ("idx", "pal"):
        actual = {p.stem for p in ASSETS.glob(f"*.{suffix}")}
        if actual != expected:
            errors.append(f".{suffix} inventory mismatch: expected {len(expected)}, found {len(actual)}")
    static = {1: bgr555(mapping["DASHBOARD_INK"]), 2: bgr555(mapping["DASHBOARD_DARK"])}
    for slug in sorted(expected & records.keys()):
        row = records[slug]
        idx_path, pal_path = ASSETS / f"{slug}.idx", ASSETS / f"{slug}.pal"
        if not idx_path.exists() or not pal_path.exists():
            continue
        pixels, palette = idx_path.read_bytes(), pal_path.read_bytes()
        if len(pixels) != row.get("raw_indexed_bytes"):
            errors.append(f"{slug}: raster length {len(pixels)} != report {row.get('raw_indexed_bytes')}")
        used = set(pixels)
        forbidden = sorted(used - art)
        if forbidden:
            errors.append(f"{slug}: forbidden artwork indices {forbidden[:8]}")
        if sorted(used) != row.get("artwork_indices_used") or len(used) != row.get("artwork_colors_used"):
            errors.append(f"{slug}: used-index metadata mismatch")
        if len(palette) != 512:
            errors.append(f"{slug}: palette length {len(palette)} != 512")
            continue
        if hashlib.sha256(palette).hexdigest() != row.get("palette_sha256"):
            errors.append(f"{slug}: palette SHA-256 mismatch")
        words = [palette[i] | (palette[i + 1] << 8) for i in range(0, len(palette), 2)]
        bad = [i for i, word in enumerate(words) if word & 0x8000]
        if bad:
            errors.append(f"{slug}: BGR555 bit 15 set at CGRAM {bad[:8]}")
        if words[0] != 0:
            errors.append(f"{slug}: CGRAM 0 must remain black")
        for i, value in static.items():
            if words[i] != value:
                errors.append(f"{slug}: static ink CGRAM {i} mismatch")
        reserved = [i for i in range(224, 256) if words[i] != 0]
        if reserved:
            errors.append(f"{slug}: sprite CGRAM entries must be zero before runtime restore: {reserved[:8]}")
        if row.get("palette_mapping") != "contiguous-3-223-static-inks":
            errors.append(f"{slug}: report palette mapping disagrees with generator")
    c_source = (ROOT / "examples/snes/lzss-gallery.c").read_text()
    if "REG_CGADD=224u" not in c_source or "write_reserved_obj_palette();" not in c_source:
        errors.append("runtime sprite palette restore no longer starts at CGRAM 224")
    print(f"palette audit: {len(expected)} works; artwork indices {min(art)}–{max(art)}; "
          f"static inks 1–2; sprite reservation 224–255")
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    return bool(errors)


if __name__ == "__main__":
    try:
        raise SystemExit(1 if run() else 0)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
