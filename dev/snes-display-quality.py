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


# --- content source -------------------------------------------------------
#
# By default the gate reads the working tree, which is right for CI (where the
# tree IS the commit) and for `--update-baseline`. It is wrong for a
# pre-commit hook on a shared checkout: a *concurrent* worker's unstaged file
# then blocks everyone's commits, which is exactly how the old SNESDQ_SKIP
# escape hatch came to be used in 40 of 100 commits. Under --staged the gate
# instead reads what the commit will actually contain: the staged blob for
# staged paths, HEAD for everything else, and the dirty worktree never.
STAGED_MODE = False
_staged_cache: dict[str, str] = {}


def _git(*args: str) -> str:
    import subprocess
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout


def _load_staged_view() -> None:
    global _staged_cache
    staged = {ln for ln in _git("diff", "--cached", "--name-only",
                                "--diff-filter=ACMR").splitlines() if ln}
    for rel in staged:
        if rel.endswith((".c", ".h")):
            _staged_cache[rel] = _git("show", f":{rel}")


def read_source(path: Path) -> str:
    """Content of `path` as the pending commit would contain it."""
    rel = path.relative_to(ROOT).as_posix()
    if STAGED_MODE:
        if rel in _staged_cache:
            return _staged_cache[rel]
        text = _git("show", f"HEAD:{rel}")
        if text:
            return text
        # untracked and unstaged -> not part of this commit
        return ""
    return path.read_text(errors="replace")


def source_files(pattern: str = "*") -> list[Path]:
    """Paths to consider. Under --staged, tracked-or-staged files only."""
    if STAGED_MODE:
        tracked = {ln for ln in _git("ls-files", "examples/snes").splitlines() if ln}
        tracked |= set(_staged_cache)
        out = []
        for rel in sorted(tracked):
            pp = ROOT / rel
            if pp.suffix in {".c", ".h"} and pp.match(f"examples/snes/**/{pattern}"
                                                      if pattern != "*" else str(pp)):
                out.append(pp)
        return out
    return sorted(SOURCE_ROOT.rglob(pattern))


def normalized(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def finding_id(kind: str, relative: str, line: str) -> str:
    material = f"{kind}\0{relative}\0{normalized(line)}".encode()
    return hashlib.sha256(material).hexdigest()[:20]


def scan() -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for path in source_files():
        if path.suffix not in {".c", ".h"}:
            continue
        if not STAGED_MODE and not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        for number, line in enumerate(read_source(path).splitlines(), 1):
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
    display = read_source(SOURCE_ROOT / "snesgfx/display.h")
    upload = read_source(SOURCE_ROOT / "snesgfx/upload.h")

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
        for path in [q for q in source_files("*.c") if q.parent == SOURCE_ROOT]:
            text = read_source(path)
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
    parser.add_argument("--staged", action="store_true",
                        help="judge the pending commit (staged blobs + HEAD), "
                             "never the dirty worktree; for the pre-commit hook")
    args = parser.parse_args()

    if args.staged:
        if args.update_baseline:
            parser.error("--staged and --update-baseline are mutually exclusive")
        global STAGED_MODE
        STAGED_MODE = True
        _load_staged_view()

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
