#!/usr/bin/env python3
"""Export the reviewed upstream Mermaid diagram with stable dashboard links."""

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/upstream-pending-work.md"
MAP = ROOT / "docs/upstream-dashboard-graph-map.json"
MANIFEST = ROOT / "docs/upstream-dashboard.json"
OUTPUT = ROOT / "docs/upstream-dashboard-graph.json"


def export():
    source = SOURCE.read_text()
    section = source.split("## Flowchart\n", 1)[1]
    diagram = section.split("```mermaid\n", 1)[1].split("\n```", 1)[0]
    mapping = json.loads(MAP.read_text())
    manifest = json.loads(MANIFEST.read_text())
    ids = {item["id"] for item in manifest["items"]}
    if mapping.get("schemaVersion") != 1:
        raise ValueError("Unknown graph mapping schema")
    node_ids = set(re.findall(r"\b([A-Z][A-Z0-9]*)\[", diagram))
    for node_id, node in mapping["nodes"].items():
        if node_id not in node_ids or node["workId"] not in ids or not node["label"]:
            raise ValueError(f"Invalid mapped graph node: {node_id}")
    track_ids = set()
    for track in mapping["tracks"]:
        if track["id"] in track_ids or not track["workIds"]:
            raise ValueError(f"Invalid graph track: {track['id']}")
        track_ids.add(track["id"])
        if set(track["workIds"]) - ids:
            raise ValueError(f"Unknown work item in graph track: {track['id']}")
    date = re.search(r"Local preparation updated (\d{4}-\d{2}-\d{2})", source)
    if not date:
        raise ValueError("Flowchart source has no local-review date")
    return {
        "schemaVersion": 1,
        "source": "docs/upstream-pending-work.md#flowchart",
        "sourceHash": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "sourceSnapshotDate": date.group(1),
        "manifestSourceHash": manifest["sourceHash"],
        "mermaid": diagram,
        "nodes": mapping["nodes"],
        "tracks": mapping["tracks"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = json.dumps(export(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != result:
            raise SystemExit(f"{OUTPUT}: stale")
        print(f"{OUTPUT}: current")
    else:
        OUTPUT.write_text(result)
        print(OUTPUT)


if __name__ == "__main__":
    main()
