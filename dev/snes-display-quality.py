#!/usr/bin/env python3
"""Fast, dependency-free SNES display quality gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "dev/snes-display-quality-baseline.json"
SOURCE_ROOT = ROOT / "examples/snes"

SENSITIVE = re.compile(
    r"\b(?:REG_(?:VMDATA[HL]?|CGDATA|OAMDATA|MDMAEN)|"
    r"snes_(?:vram|cgram|oam)_addr)\b"
)
FORCE_BLANK = re.compile(
    r"\bREG_INIDISP\s*=\s*(?:INIDISP_FORCE_BLANK|0x8[0-9a-fA-FuUlL]*)"
)


def normalized(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def finding_id(kind: str, relative: str, line: str) -> str:
    material = f"{kind}\0{relative}\0{normalized(line)}".encode()
    return hashlib.sha256(material).hexdigest()[:20]


def scan() -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for path in sorted(SOURCE_ROOT.rglob("*")):
        if path.suffix not in {".c", ".h"} or not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            kind = None
            if FORCE_BLANK.search(line):
                kind = "force-blank"
            elif SENSITIVE.search(line):
                kind = "ppu-write"
            if kind:
                findings.append(
                    {
                        "id": finding_id(kind, relative, line),
                        "kind": kind,
                        "path": relative,
                        "line": number,
                        "text": normalized(line),
                    }
                )
    return findings


def invariant_errors() -> list[str]:
    errors: list[str] = []
    display = (SOURCE_ROOT / "snesgfx/display.h").read_text()
    upload = (SOURCE_ROOT / "snesgfx/upload.h").read_text()

    order = ["scene_emit(&d->scene, &d->q);", "snes_wait_vblank();", "upq_flush(&d->q);",
             "REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);"]
    positions = [display.find(token) for token in order]
    if any(pos < 0 for pos in positions) or positions != sorted(positions):
        errors.append("display_frame order must remain emit -> wait VBlank -> flush -> enable")
    if "REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);" not in display:
        errors.append("display brightness must mask off the INIDISP force-blank bit")

    budget_match = re.search(r"#define\s+UPQ_VBLANK_BUDGET\s+(\d+)", upload)
    if not budget_match:
        errors.append("UPQ_VBLANK_BUDGET is missing")
    else:
        budget = int(budget_match.group(1))
        for path in sorted(SOURCE_ROOT.glob("*.c")):
            text = path.read_text(errors="replace")
            tiles = re.search(r"#define\s+CANVAS_FLUSH_TILES\s+(\d+)", text)
            if tiles and int(tiles.group(1)) * 16 > budget:
                errors.append(
                    f"{path.relative_to(ROOT)}: CANVAS_FLUSH_TILES needs "
                    f"{int(tiles.group(1)) * 16} bytes, budget is {budget}"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update-baseline", action="store_true")
    args = parser.parse_args()

    findings = scan()
    if args.update_baseline:
        payload = {
            "schema": 1,
            "purpose": "Reviewed legacy direct PPU/force-blank access sites; new sites fail.",
            "findings": findings,
        }
        BASELINE.write_text(json.dumps(payload, indent=2) + "\n")
        print(f"SNESDQ: wrote {len(findings)} reviewed findings to {BASELINE.relative_to(ROOT)}")
        return 0

    errors = invariant_errors()
    if not BASELINE.exists():
        errors.append("baseline missing; run dev/snes-display-quality.py --update-baseline and review it")
        known: set[str] = set()
    else:
        known = {item["id"] for item in json.loads(BASELINE.read_text())["findings"]}
    new = [item for item in findings if item["id"] not in known]

    for item in new:
        errors.append(
            f"{item['path']}:{item['line']}: new {item['kind']}: {item['text']}"
        )
    if errors:
        print("SNESDQ: FAIL", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(
        f"SNESDQ: PASS ({len(findings)} reviewed sensitive access sites; "
        "display order and upload budgets valid)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
