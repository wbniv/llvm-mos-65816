#!/usr/bin/env python3
"""Generate a visual LoROM cartridge map from an lld map and gallery report."""
import argparse
import json
import re
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("map")
p.add_argument("report")
p.add_argument("output")
a = p.parse_args()

sections = {}
for line in Path(a.map).read_text().splitlines():
    m = re.match(r"^\s*([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)\s+1\s+(\.\S+)$", line)
    if m:
        sections[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))

works = json.loads(Path(a.report).read_text())
bank_count = max(max(work["stream_bank"], work["palette_bank"]) for work in works)
if bank_count > 31:
    raise SystemExit("too many gallery banks for 1 MiB LoROM")

rows = []
banks = [{
    "bank": 0,
    "stream_items": [],
    "palette_items": [],
    "stream": 0,
    "palette": 0,
    "used": None,
    "free": None,
}]
for bank in range(1, bank_count + 1):
    stream_items = [work for work in works if work["stream_bank"] == bank]
    palette_items = [work for work in works if work["palette_bank"] == bank]
    sec = f".gallery_{bank:02X}"
    if sec not in sections:
        raise SystemExit(f"missing linked section {sec}")
    addr, linked = sections[sec]
    if addr >> 16 != bank or linked > 32768:
        raise SystemExit(f"{sec}: invalid bank/size {addr:06X}/{linked}")
    stream = sum(work["compressed_bytes"] for work in stream_items)
    expected = stream + 512 * len(palette_items)
    if linked != expected:
        raise SystemExit(f"{sec}: linked {linked}, expected stream+palette {expected}")
    free = 32768 - linked
    banks.append({
        "bank": bank,
        "stream_items": stream_items,
        "palette_items": palette_items,
        "stream": stream,
        "palette": 512 * len(palette_items),
        "used": linked,
        "free": free,
    })
    detail = [f"{work['title']} stream — {work['compressed_bytes']:,}" for work in stream_items]
    detail += [f"{work['title']} palette — 512" for work in palette_items]
    contents = "<br/>".join(detail)
    rows.append(f"| `${bank:02X}` | {contents} | {stream:,} | {512*len(palette_items):,} | {linked:,} | {free:,} |")

last = bank_count
pad = 31 - last
for bank in range(bank_count + 1, 32):
    banks.append({
        "bank": bank,
        "stream_items": [],
        "palette_items": [],
        "stream": 0,
        "palette": 0,
        "used": 0,
        "free": 32768,
    })

if len(banks) != 32 or [bank["bank"] for bank in banks] != list(range(32)):
    raise SystemExit("internal error: cartridge model must contain banks $00-$1F exactly once")

def bank_summary(model):
    bank = model["bank"]
    if bank == 0:
        return "$00 SYSTEM · CODE / RODATA / HEADER"
    if model["used"] == 0:
        return f"${bank:02X} EMPTY · 32,768 B padding"
    streams = [work["slug"].replace("-", " ").upper() for work in model["stream_items"]]
    if streams:
        content = " + ".join(streams[:2])
        if len(streams) > 2:
            content += f" + {len(streams)-2} streams"
    else:
        content = "PALETTES"
    palettes = len(model["palette_items"])
    if palettes:
        content += f" + {palettes} pal"
    return (f"${bank:02X} {content} · {model['used']:,} used"
            f" · {model['free']:,} free")

def occupancy_class(model):
    if model["bank"] == 0:
        return "system"
    if model["used"] == 0:
        return "empty"
    if model["free"] < 32:
        return "critical"
    if model["free"] < 256:
        return "tight"
    if model["free"] < 1024:
        return "packed"
    return "used"

gallery_used = sum(model["used"] or 0 for model in banks)
tree = [
    "```mermaid",
    "%%{init: {'treemap': {'padding': 6, 'diagramPadding': 8, 'showValues': false}}}%%",
    "treemap-beta",
    f'"1 MiB LoROM · $00-$1F · {gallery_used:,} B gallery · {pad*32768:,} B padding":::root',
]

for quadrant in range(4):
    first = quadrant * 8
    qmodels = banks[first:first + 8]
    qused = sum(model["used"] or 0 for model in qmodels)
    occupied = sum((model["used"] or 0) > 0 for model in qmodels)
    system = " + system" if first == 0 else ""
    tree.append(
        f'  "Q{quadrant} · ${first:02X}-${first+7:02X} · 256 KiB'
        f' · {occupied} occupied{system} · {qused:,} B gallery":::quadrant'
    )
    for cell_in_quadrant in range(4):
        cell = quadrant * 4 + cell_in_quadrant
        cell_first = cell * 2
        cmodels = banks[cell_first:cell_first + 2]
        cused = sum(model["used"] or 0 for model in cmodels)
        state = ("system pair" if cell_first == 0 else
                 ("empty" if cused == 0 else f"{cused:,} B gallery"))
        tree.append(
            f'    "${cell_first:02X}-${cell_first+1:02X} · 64 KiB · {state}":::cell'
        )
        for model in cmodels:
            tree.append(
                f'      "{bank_summary(model)}": 32768:::{occupancy_class(model)}'
            )

tree += [
    "classDef root fill:#111827,stroke:#91b4d8,color:#f4f8ff,stroke-width:3px;",
    "classDef quadrant fill:#202b3d,stroke:#6784a0,color:#e8f1fa,stroke-width:2px;",
    "classDef cell fill:#17202c,stroke:#46596d,color:#bdcad6,stroke-width:1px;",
    "classDef system fill:#263967,stroke:#7092e6,color:#ffffff,stroke-width:2px;",
    "classDef critical fill:#5c202d,stroke:#ff647d,color:#ffffff,stroke-width:2px;",
    "classDef tight fill:#623c20,stroke:#f49a4a,color:#ffffff,stroke-width:2px;",
    "classDef packed fill:#554d1c,stroke:#dbcb54,color:#ffffff;",
    "classDef used fill:#193f38,stroke:#4dcaa9,color:#ffffff;",
    "classDef empty fill:#161c25,stroke:#303a48,color:#788796;",
]
tree.append("```")

out = [
    "<!-- GENERATED by tools/snes-rom-map.py; do not edit. -->",
    *tree, "",
    "**Occupancy:** critical <32 B free · tight <256 B · packed <1,024 B · "
    "green = occupied · blue = system · gray = padding", "",
    "| Bank | Contents | Stream | Palette | Used | Free |",
    "|---:|---|---:|---:|---:|---:|", *rows,
    f"| `${last+1:02X}-$1F` | Explicit power-of-two padding | 0 | 0 | 0 each | 32,768 each |", "",
]
Path(a.output).write_text("\n".join(out))
