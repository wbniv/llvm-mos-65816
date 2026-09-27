#!/usr/bin/env python3
"""Export the public SNES compiler-bug registry with a semantic records hash."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/snes-demo-compiler-bug-pages.json"
OUTPUT = ROOT / "docs/snes-demo-compiler-bug-public.json"


def main() -> None:
    source = SOURCE.read_bytes()
    registry = json.loads(source)
    if registry.get("schema") != 1 or not isinstance(registry.get("records"), list):
        raise SystemExit(f"{SOURCE}: expected schema 1 with records")
    for record in registry["records"]:
        for field in ("slug", "page", "discovered", "defect", "evidence", "prs", "pr_simulations"):
            if field not in record:
                raise SystemExit(f"{SOURCE}: record is missing {field}")
    records = registry["records"]
    records_bytes = json.dumps(records, sort_keys=True, separators=(",", ":")).encode("utf-8")
    public = {
        "schema": 1,
        "canonical_source": SOURCE.relative_to(ROOT).as_posix(),
        "records_sha256": hashlib.sha256(records_bytes).hexdigest(),
        "records": records,
    }
    OUTPUT.write_text(json.dumps(public, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
