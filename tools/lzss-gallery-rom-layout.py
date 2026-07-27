#!/usr/bin/env python3
"""Render the LZSS gallery's romopt bank allocation as standalone HTML."""
from __future__ import annotations
import argparse, html, json, pathlib, re

BANK_BYTES = 32768
BANKS_PER_MIB = 32

CSS = """
:root{color-scheme:dark;--bg:#100f0d;--panel:#1d1a16;--ink:#f4ead6;--muted:#a99d8a;
--code:#e4a853;--stream:#65b7a6;--palette:#f0d277;--shared:#7dd3fc;--free:#302b25;--rule:#4b4338;
--b0strings:#d17bd8;--b0desc:#7da4ed;--b0lookup:#e68d68;--b0const:#94a36b;
--b0init:#b78a57;--b0system:#efc86f}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.35 ui-monospace,monospace}
main{max-width:1240px;margin:auto;padding:28px 22px 46px}h1{margin:0;color:#fff4dc;font:700 28px/1.1 system-ui}
.lede,.detail,.note{color:var(--muted)}.summary,.legend{display:flex;gap:12px;flex-wrap:wrap;margin:17px 0}
.pill,.note{border:1px solid var(--rule);background:var(--panel);padding:8px 11px;border-radius:8px}
.key:before{content:"";display:inline-block;width:12px;height:12px;background:var(--c);margin-right:7px;vertical-align:-2px}
.locked{margin:12px 0 20px;border:2px solid var(--code);border-radius:9px;background:var(--panel);overflow:hidden}
.locked .row,.head{display:flex;justify-content:space-between;padding:9px 11px}.locked .row{border-bottom:1px solid var(--rule)}
.bank0-list{display:grid;grid-template-columns:repeat(2,minmax(260px,1fr));gap:0 18px;padding:9px 11px}
.bank0-item{display:grid;grid-template-columns:12px 1fr auto;gap:7px;padding:3px 0;border-bottom:1px solid #ffffff0b}
.swatch{width:10px;height:10px;margin-top:4px;background:var(--c)}.bank0-item code{color:var(--muted)}
.cart{display:grid;grid-template-columns:repeat(5,minmax(190px,1fr));gap:10px}.bank{background:var(--panel);border:1px solid var(--rule);border-radius:8px;overflow:hidden}
.head{border-bottom:1px solid var(--rule)}.num,.title{font-weight:800;color:#fff4dc}
.used{display:grid;text-align:right;color:var(--muted)}.used span{white-space:nowrap}
.bar{height:45px;display:flex;background:var(--free)}.seg{height:100%;min-width:1px}.stream{background:var(--stream)}
.palette{background:var(--palette)}.shared{background:var(--shared)}.free{background:var(--free)}.label{padding:8px 10px;min-height:91px}
.code{background:var(--code)}.b0strings{background:var(--b0strings)}.b0desc{background:var(--b0desc)}
.b0lookup{background:var(--b0lookup)}.b0const{background:var(--b0const)}
.b0init{background:var(--b0init)}.b0system{background:var(--b0system)}
.item{font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.reserve{opacity:.55}
.boundary{grid-column:1/-1;display:grid;grid-template-columns:1fr auto 1fr;gap:12px;align-items:center;
color:var(--palette);font-weight:800;letter-spacing:.04em;margin:7px 0}
.boundary:before,.boundary:after{content:"";height:2px;background:linear-gradient(90deg,transparent,var(--palette))}
.boundary:after{background:linear-gradient(90deg,var(--palette),transparent)}
.note{margin-top:18px;border-left:3px solid var(--palette)}@media(max-width:980px){.cart{grid-template-columns:repeat(3,1fr)}}
@media(max-width:620px){.cart{grid-template-columns:1fr}.bank0-list{grid-template-columns:1fr}}
"""

def map_data(path: pathlib.Path) -> tuple[dict[str, int], dict[str, tuple[int, int]]]:
    sections: dict[str, int] = {}
    symbols: dict[str, tuple[int, int]] = {}
    pattern = re.compile(r"^\s*[0-9a-f]+\s+[0-9a-f]+\s+([0-9a-f]+)\s+\d+\s+(\.\S+)")
    symbol_pattern = re.compile(
        r"^\s*([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)\s+\d+\s+"
        r"(gallery_\S+_(?:lz|pal)|FONT8|FONT16|GALLERY_ASSETS|SINCOS)$")
    for line in path.read_text().splitlines():
        if m := pattern.match(line):
            sections[m.group(2)] = int(m.group(1), 16)
        if m := symbol_pattern.match(line):
            symbols[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    return sections, symbols

def bank_card(bank: int, items: list[tuple[int, str, int, str]]) -> str:
    items = sorted(items)
    used = max((offset + size for offset, _, size, _ in items), default=0)
    cursor = 0; segments = []
    for offset, name, size, kind in items:
        assert offset >= cursor
        if offset > cursor:
            segments.append(f'<span class="seg free" style="width:{(offset-cursor)/BANK_BYTES*100:.4f}%"></span>')
        segments.append(
            f'<span class="seg {kind}" style="width:{size/BANK_BYTES*100:.4f}%" '
            f'title="{html.escape(name)}: ${offset:04X}–${offset+size-1:04X}"></span>')
        cursor = offset + size
    free = BANK_BYTES - cursor
    segments.append(f'<span class="seg free" style="width:{free/BANK_BYTES*100:.4f}%"></span>')
    lines = "".join(f'<div class="item">${offset:04X} · {html.escape(name)} · {size:,} B</div>'
                    for offset, name, size, _ in items)
    if not lines:
        lines = '<div class="detail">32,768 bytes free</div>'
    return f"""<section class="bank{' reserve' if not items else ''}">
<div class="head"><span class="num">Bank ${bank:02X}</span><span class="used"><span>{used:,} used</span><span>{free:,} free</span></span></div>
<div class="bar">{''.join(segments)}</div>
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
    sections, symbols = map_data(args.mapfile)
    rom_bytes = args.rom.stat().st_size
    assert rom_bytes % BANK_BYTES == 0
    banks = rom_bytes // BANK_BYTES
    assert banks % BANKS_PER_MIB == 0

    packed: dict[int, list[tuple[int, str, int, str]]] = {}
    for asset in report:
        sb, pb = asset["stream_bank"], asset["palette_bank"]
        assert sb >= 1 and pb >= 1, "romopt assets must not enter bank $00"
        stem=asset["slug"].replace("-","_")
        for bank, suffix, label, expected, kind in (
            (sb,"lz","stream",asset["compressed_bytes"],"stream"),
            (pb,"pal","palette",512,"palette")):
            addr,size=symbols[f"gallery_{stem}_{suffix}"]
            assert size == expected and addr >> 16 == bank
            offset=(addr & 0xffff)-0x8000
            packed.setdefault(bank, []).append((offset,f'{asset["slug"]} {label}',size,kind))
    for symbol, expected in (("FONT16",4096),("FONT8",1024)):
        addr,size=symbols[symbol]
        bank=addr >> 16
        assert bank >= 1 and size == expected
        packed.setdefault(bank, []).append(
            ((addr & 0xffff)-0x8000,symbol,size,"shared"))
    assert max(packed, default=0) < banks
    section_rows={}
    section_re=re.compile(
        r"^\s*([0-9a-f]+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+\d+\s+(\.\S+)$")
    for line in args.mapfile.read_text().splitlines():
        if m := section_re.match(line):
            section_rows[m.group(4)]=tuple(int(m.group(i),16) for i in (1,2,3))
    text_vma,_,text_size=section_rows[".text"]
    ro_vma,_,ro_size=section_rows[".rodata"]
    desc_addr,desc_size=symbols["GALLERY_ASSETS"]
    sin_addr,sin_size=symbols["SINCOS"]
    zp_vma,zp_lma,zp_size=section_rows[".zp.data"]
    header_vma,_,header_size=section_rows[".snes_header"]
    nv_vma,_,nv_size=section_rows[".snes_vectors_native"]
    ev_vma,_,ev_size=section_rows[".snes_vectors_emu"]
    bank0_parts=[
        ("Runtime code",text_vma,text_size,"code"),
        ("Strings",ro_vma,desc_addr-ro_vma,"b0strings"),
        ("Gallery descriptors",desc_addr,desc_size,"b0desc"),
        ("Sine/cosine table",sin_addr,sin_size,"b0lookup"),
        ("Other constants",sin_addr+sin_size,ro_vma+ro_size-(sin_addr+sin_size),"b0const"),
        ("WRAM initializers",zp_lma,zp_size,"b0init"),
        ("Unallocated",zp_lma+zp_size,header_vma-(zp_lma+zp_size),"free"),
        ("SNES header",header_vma,header_size,"b0system"),
        ("Native vectors",nv_vma,nv_size,"b0system"),
        ("Emulation vectors",ev_vma,ev_size,"b0system"),
    ]
    bank0_used=sum(size for name,_,size,kind in bank0_parts if kind!="free")
    bank0_free=sum(size for name,_,size,kind in bank0_parts if kind=="free")
    bank0_bar="".join(
        f'<span class="seg {kind}" style="width:{size/BANK_BYTES*100:.4f}%" '
        f'title="{html.escape(name)}: {size:,} bytes"></span>'
        for name,_,size,kind in bank0_parts)
    bank0_list="".join(
        f'<div class="bank0-item"><span class="swatch" style="--c:var(--{kind if kind in ("code","free") else kind})"></span>'
        f'<span>{html.escape(name)} <code>$00:{addr:04X}–{addr+size-1:04X}</code></span>'
        f'<strong>{size:,} B</strong></div>'
        for name,addr,size,kind in bank0_parts)
    cards = []
    for bank in range(1, banks):
        cards.append(bank_card(bank, packed.get(bank, [])))
        if (bank + 1) % BANKS_PER_MIB == 0:
            mib = (bank + 1) // BANKS_PER_MIB
            cards.append(f'<div class="boundary">{mib * 8} Mbit ({mib} MiB) boundary · end of bank ${bank:02X}</div>')

    asset_bytes = sum(sum(x[2] for x in values) for values in packed.values())
    used_banks = len(packed)
    body = f"""<!doctype html>
<!-- GENERATED by tools/lzss-gallery-rom-layout.py; do not edit. -->
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>LZSS Gallery — romopt cartridge layout</title><style>{CSS}</style><main>
<h1><code>romopt</code> asset packing</h1>
<p class="lede">{rom_bytes*8//1048576} Mbit ({rom_bytes//1048576} MiB) LoROM · bank $00 locked · assets begin at bank $01</p>
<div class="summary"><span class="pill">{len(report)} works</span><span class="pill">{len(report)*2+2} indivisible items</span>
<span class="pill">{used_banks} packed asset banks</span><span class="pill">{banks-1-used_banks} reserved banks</span>
<span class="pill">{asset_bytes:,} asset bytes</span></div>
<div class="legend"><span class="key" style="--c:var(--code)">bank $00: runtime/shared only</span>
<span class="key" style="--c:var(--stream)">LZSS stream</span><span class="key" style="--c:var(--palette)">512-byte palette</span>
<span class="key" style="--c:var(--shared)">shared font data</span>
<span class="key" style="--c:var(--free)">free / padding</span></div>
<section class="locked"><div class="row"><strong>Bank $00 — excluded from romopt</strong>
<span>{bank0_used:,} used · {bank0_free:,} free</span></div>
<div class="bar">{bank0_bar}</div><div class="bank0-list">{bank0_list}</div>
<div class="label">Physical ROM-address breakdown from the final linker map. Writable BSS/WRAM is
not cartridge content. No packed stream, palette, font, or static graphic is eligible for this bank.</div></section>
<div class="cart">{''.join(cards)}</div>
<p class="note"><strong>Algorithm:</strong> stable first-fit decreasing. Sort streams and palettes
largest-to-smallest, retain manifest order as the tie-breaker, and place each item in the first
32 KiB bank where it fits. This determines bank membership, not order inside a bank. The bars and
address-prefixed listings show the linker's actual intra-bank order from the final map.</p>
</main></html>"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(body)
    print(f"wrote {args.output}: {banks} banks, {used_banks} asset banks, {len(report)} works")

if __name__ == "__main__":
    main()
