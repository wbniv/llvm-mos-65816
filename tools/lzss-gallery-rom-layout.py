#!/usr/bin/env python3
"""Render the LZSS gallery's romopt bank allocation as standalone HTML."""
from __future__ import annotations
import argparse, html, json, pathlib, re

BANK_BYTES = 32768
BANKS_PER_MIB = 32

CSS = """
:root{color-scheme:dark;--bg:#100f0d;--panel:#1d1a16;--ink:#f4ead6;--muted:#a99d8a;
--code:#e4a853;--stream:#65b7a6;--palette:#f0d277;--free:#302b25;--rule:#4b4338}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.35 ui-monospace,monospace}
main{max-width:1240px;margin:auto;padding:28px 22px 46px}h1{margin:0;color:#fff4dc;font:700 28px/1.1 system-ui}
.lede,.detail,.note{color:var(--muted)}.summary,.legend{display:flex;gap:12px;flex-wrap:wrap;margin:17px 0}
.pill,.note{border:1px solid var(--rule);background:var(--panel);padding:8px 11px;border-radius:8px}
.key:before{content:"";display:inline-block;width:12px;height:12px;background:var(--c);margin-right:7px;vertical-align:-2px}
.locked{margin:12px 0 20px;border:2px solid var(--code);border-radius:9px;background:var(--panel);overflow:hidden}
.locked .row,.head{display:flex;justify-content:space-between;padding:9px 11px}.locked .row{border-bottom:1px solid var(--rule)}
.cart{display:grid;grid-template-columns:repeat(5,minmax(190px,1fr));gap:10px}.bank{background:var(--panel);border:1px solid var(--rule);border-radius:8px;overflow:hidden}
.head{border-bottom:1px solid var(--rule)}.num,.title{font-weight:800;color:#fff4dc}.used{color:var(--muted)}
.bar{height:45px;display:flex;background:var(--free)}.seg{height:100%;min-width:1px}.stream{background:var(--stream)}
.palette{background:var(--palette)}.free{background:var(--free)}.label{padding:8px 10px;min-height:91px}
.item{font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.reserve{opacity:.55}
.boundary{grid-column:1/-1;display:grid;grid-template-columns:1fr auto 1fr;gap:12px;align-items:center;
color:var(--palette);font-weight:800;letter-spacing:.04em;margin:7px 0}
.boundary:before,.boundary:after{content:"";height:2px;background:linear-gradient(90deg,transparent,var(--palette))}
.boundary:after{background:linear-gradient(90deg,var(--palette),transparent)}
.note{margin-top:18px;border-left:3px solid var(--palette)}@media(max-width:980px){.cart{grid-template-columns:repeat(3,1fr)}}
@media(max-width:620px){.cart{grid-template-columns:1fr}}
"""

def map_sections(path: pathlib.Path) -> dict[str, int]:
    out: dict[str, int] = {}
    pattern = re.compile(r"^\s*[0-9a-f]+\s+[0-9a-f]+\s+([0-9a-f]+)\s+\d+\s+(\.\S+)")
    for line in path.read_text().splitlines():
        if m := pattern.match(line):
            out[m.group(2)] = int(m.group(1), 16)
    return out

def bank_card(bank: int, items: list[tuple[str, int, str]]) -> str:
    used = sum(size for _, size, _ in items)
    free = BANK_BYTES - used
    segments = "".join(
        f'<span class="seg {kind}" style="width:{size/BANK_BYTES*100:.4f}%" '
        f'title="{html.escape(name)}: {size:,} bytes"></span>'
        for name, size, kind in items
    )
    lines = "".join(f'<div class="item">{html.escape(name)} · {size:,} B</div>'
                    for name, size, _ in items)
    if not lines:
        lines = '<div class="detail">32,768 bytes free</div>'
    return f"""<section class="bank{' reserve' if not items else ''}">
<div class="head"><span class="num">Bank ${bank:02X}</span><span class="used">{used:,} / 32,768</span></div>
<div class="bar">{segments}<span class="seg free" style="width:{free/BANK_BYTES*100:.4f}%"></span></div>
<div class="label"><div class="title">{len(items)} packed item{'s' if len(items)!=1 else ''}</div>{lines}</div>
</section>"""

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", type=pathlib.Path, required=True)
    ap.add_argument("--map", dest="mapfile", type=pathlib.Path, required=True)
    ap.add_argument("--rom", type=pathlib.Path, required=True)
    ap.add_argument("--output", type=pathlib.Path, required=True)
    args = ap.parse_args()

    report = json.loads(args.report.read_text())
    sections = map_sections(args.mapfile)
    rom_bytes = args.rom.stat().st_size
    assert rom_bytes % BANK_BYTES == 0
    banks = rom_bytes // BANK_BYTES
    assert banks % BANKS_PER_MIB == 0

    packed: dict[int, list[tuple[str, int, str]]] = {}
    for asset in report:
        sb, pb = asset["stream_bank"], asset["palette_bank"]
        assert sb >= 1 and pb >= 1, "romopt assets must not enter bank $00"
        packed.setdefault(sb, []).append((f'{asset["slug"]} stream', asset["compressed_bytes"], "stream"))
        packed.setdefault(pb, []).append((f'{asset["slug"]} palette', 512, "palette"))
    assert max(packed, default=0) < banks

    bank0 = sections.get(".text", 0) + sections.get(".rodata", 0)
    bank0 += sum(v for k, v in sections.items() if k.startswith(".snes_"))
    cards = []
    for bank in range(1, banks):
        cards.append(bank_card(bank, packed.get(bank, [])))
        if (bank + 1) % BANKS_PER_MIB == 0:
            mib = (bank + 1) // BANKS_PER_MIB
            cards.append(f'<div class="boundary">{mib * 8} Mbit ({mib} MiB) boundary · end of bank ${bank:02X}</div>')

    asset_bytes = sum(sum(x[1] for x in values) for values in packed.values())
    used_banks = len(packed)
    body = f"""<!doctype html>
<!-- GENERATED by tools/lzss-gallery-rom-layout.py; do not edit. -->
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>LZSS Gallery — romopt cartridge layout</title><style>{CSS}</style><main>
<h1><code>romopt</code> asset packing</h1>
<p class="lede">{rom_bytes*8//1048576} Mbit ({rom_bytes//1048576} MiB) LoROM · bank $00 locked · assets begin at bank $01</p>
<div class="summary"><span class="pill">{len(report)} works</span><span class="pill">{len(report)*2} indivisible items</span>
<span class="pill">{used_banks} packed asset banks</span><span class="pill">{banks-1-used_banks} reserved banks</span>
<span class="pill">{asset_bytes:,} asset bytes</span></div>
<div class="legend"><span class="key" style="--c:var(--code)">bank $00: runtime/shared only</span>
<span class="key" style="--c:var(--stream)">LZSS stream</span><span class="key" style="--c:var(--palette)">512-byte palette</span>
<span class="key" style="--c:var(--free)">free / padding</span></div>
<section class="locked"><div class="row"><strong>Bank $00 — excluded from romopt</strong><span>{bank0:,} / 32,768 bytes</span></div>
<div class="bar"><span class="seg" style="width:{bank0/BANK_BYTES*100:.4f}%;background:var(--code)"></span>
<span class="seg free" style="width:{(BANK_BYTES-bank0)/BANK_BYTES*100:.4f}%"></span></div>
<div class="label">Runtime, startup, navigation, descriptors, fonts, tables, header, and vectors.
No artwork stream or palette is eligible for this bank.</div></section>
<div class="cart">{''.join(cards)}</div>
<p class="note"><strong>Algorithm:</strong> stable first-fit decreasing. Sort streams and palettes
largest-to-smallest, retain manifest order as the tie-breaker, and place each item in the first
32 KiB bank where it fits. Palettes remain separate 512-byte items so they fill stream-sized holes.</p>
</main></html>"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(body)
    print(f"wrote {args.output}: {banks} banks, {used_banks} asset banks, {len(report)} works")

if __name__ == "__main__":
    main()
