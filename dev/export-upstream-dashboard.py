#!/usr/bin/env python3
"""Export the reviewed public compiler work inventory for wald3n.com."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
CURATION = ROOT / "docs/upstream-dashboard-curation.json"
OUTPUT = ROOT / "docs/upstream-dashboard.json"
PUBLIC_REPO = "https://github.com/wbniv/llvm-mos-65816/blob/main/"
STATUS = {
    "fixed": "fixed",
    "not_reproduced": "qualified",
    "contract_clarification": "qualified",
}


def public_link(path):
    source = ROOT / path
    if not source.is_file():
        raise ValueError(f"missing evidence path: {path}")
    # Index entries travel with this export in the publication commit.
    tracked = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--error-unmatch", "--", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0
    return PUBLIC_REPO + path if tracked else None


def normalize(item):
    item = dict(item)
    paths = item.pop("evidencePaths", [])
    links = [public_link(path) for path in paths]
    item["evidenceUrls"] = [link for link in links if link]
    item["evidenceNote"] = "Detailed evidence awaits publication." if any(link is None for link in links) else ""
    item.setdefault("dependsOn", [])
    item.setdefault("upstreamUrl", None)
    item.setdefault("nextStep", "")
    item.setdefault("demoUrls", [])
    if not paths and not item["upstreamUrl"]:
        raise ValueError(f"item has no evidence or upstream link: {item['id']}")
    return item


def build():
    curation = json.loads(CURATION.read_text())
    items = []
    inputs = [CURATION]
    overrides = curation.get("defectOverrides", {})
    defect_paths = sorted((ROOT / "docs/defects").glob("*.json"))
    for path in defect_paths:
        inputs.append(path)
        record = json.loads(path.read_text())
        relpath = path.relative_to(ROOT).as_posix()
        item = {
            "id": "defect:" + path.stem,
            "kind": "defect",
            "title": record["title"],
            "summary": record.get("summary", ""),
            "localStatus": STATUS.get(record["status"], "qualified"),
            "publicationStatus": "unknown",
            "evidencePaths": [relpath],
        }
        item.update(overrides.get(path.stem, {}))
        items.append(normalize(item))
    unknown_overrides = sorted(set(overrides) - {path.stem for path in defect_paths})
    if unknown_overrides:
        raise ValueError(f"overrides without defect records: {unknown_overrides}")
    items.extend(normalize(item) for item in curation["items"])
    ids = [item["id"] for item in items]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate dashboard item ID")
    known = set(ids)
    for item in items:
        missing = set(item["dependsOn"]) - known
        if missing:
            raise ValueError(f"{item['id']} has unknown dependencies: {sorted(missing)}")
        if item["id"] in item["dependsOn"]:
            raise ValueError(f"{item['id']} depends on itself")
        if item["localStatus"] not in {"fixed", "needs-work", "qualified", "in-progress", "ready"}:
            raise ValueError(f"invalid local status for {item['id']}")
        if item["publicationStatus"] not in {"unposted", "posted", "merged", "unknown", "not-applicable"}:
            raise ValueError(f"invalid publication status for {item['id']}")
    digest = hashlib.sha256()
    for path in inputs:
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes() + b"\0")
    return {
        "schemaVersion": 1,
        "reviewedAt": curation["reviewedAt"],
        "sourceHash": digest.hexdigest(),
        "sourceRepository": "wbniv/llvm-mos-65816",
        "items": items,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(build(), indent=2, ensure_ascii=False) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != rendered:
            parser.exit(1, f"{OUTPUT}: stale; run dev/export-upstream-dashboard.py\n")
        print(f"{OUTPUT}: current")
    else:
        OUTPUT.write_text(rendered)
        print(OUTPUT)


if __name__ == "__main__":
    main()
