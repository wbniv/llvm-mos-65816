#!/usr/bin/env python3
"""Fetch pinned public-domain museum works and generate deterministic SNES gallery assets.

Run only in the development container. Normal ROM builds consume checked-in derived
files and never access the network.
"""
from __future__ import annotations
import hashlib, io, json, math, pathlib, time, urllib.error, urllib.request
import urllib.parse
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/snes/lzss-gallery"
DERIVED = BASE / "derived"
SOURCE_DIR = BASE / "sources"
SOURCES = BASE / "sources.json"
ART_INDICES = tuple(range(1,28)) + tuple(range(32,112)) + tuple(range(144,256))
ART_COLORS = len(ART_INDICES)
MAX_ART_TILES = 255

def display_height(work: dict) -> int:
    # One 16px mixed-font artist row, title, date, and three-row test console.
    caption = 16 + len(work["display_title"]) * 8 + 8 + 24
    return 224 - caption

def maximum_aspect_frame(ow: int, oh: int, shown_h: int) -> tuple[int,int]:
    """Largest <=255-tile raster within 0.5% of the complete source aspect."""
    ratio=ow/oh; best=None
    for width in range(8,257):
        height=max(8,round(width/ratio))
        tiles=math.ceil(width/8)*math.ceil(height/8)
        error=abs(width/height-ratio)/ratio
        scale=max(width,math.ceil(height*256/shown_h))
        if tiles>MAX_ART_TILES or error>0.005 or scale>255: continue
        key=(width*height,-error,width)
        if best is None or key>best[0]: best=(key,width,height)
    if best is None: raise RuntimeError(f"no aspect-preserving frame for {ow}x{oh}")
    return best[1],best[2]

def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent":"llvm-mos-lzss-gallery/1.0 (asset build; contact via github.com/wbniv/llvm-mos-65816)"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 5: raise
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")

def commons_image(title: str, artist: str):
    query=urllib.parse.urlencode({
      "action":"query","generator":"search","gsrnamespace":"6","gsrlimit":"10",
      "gsrsearch":f'intitle:"{title}" {artist}',"prop":"imageinfo",
      "iiprop":"url|size|extmetadata","iiurlwidth":"1200","format":"json","origin":"*"})
    payload=json.loads(get("https://commons.wikimedia.org/w/api.php?"+query))
    pages=list(payload.get("query",{}).get("pages",{}).values())
    if not pages:
        query=urllib.parse.urlencode({"action":"query","generator":"search","gsrnamespace":"6","gsrlimit":"10",
          "gsrsearch":f"{title} {artist}","prop":"imageinfo","iiprop":"url|size|extmetadata",
          "iiurlwidth":"1200","format":"json","origin":"*"})
        pages=list(json.loads(get("https://commons.wikimedia.org/w/api.php?"+query)).get("query",{}).get("pages",{}).values())
    for p in pages:
        ii=p["imageinfo"][0]; lic=ii.get("extmetadata",{}).get("LicenseShortName",{}).get("value","")
        if "public domain" in lic.lower() or "cc0" in lic.lower():
            return p["title"],ii.get("thumburl",ii["url"]),lic
    raise RuntimeError(f"no public-domain Commons image for {title} / {artist}")

def commons_named(file_title: str):
    query=urllib.parse.urlencode({"action":"query","titles":file_title,"prop":"imageinfo",
      "iiprop":"url|size|extmetadata","iiurlwidth":"1200","format":"json","origin":"*"})
    page=next(iter(json.loads(get("https://commons.wikimedia.org/w/api.php?"+query))["query"]["pages"].values()))
    ii=page["imageinfo"][0]; lic=ii.get("extmetadata",{}).get("LicenseShortName",{}).get("value","")
    if "public domain" not in lic.lower() and "cc0" not in lic.lower():
        raise RuntimeError(f"{file_title}: license is {lic}")
    return page["title"],ii.get("thumburl",ii["url"]),lic

def lzss(data: bytes) -> tuple[bytes, dict]:
    out = bytearray(); pos = 0; literals = matches = longest = 0
    head=[-1]*256; prev=[-1]*4096
    def h3(p):
        if p+2>=len(data): return 0
        return ((data[p]*31) ^ (data[p+1]*17) ^ data[p+2]) & 255
    def insert(p):
        h=h3(p); prev[p&4095]=head[h]; head[h]=p
    while pos < len(data):
        flag_at = len(out); out.append(0); flags = 0
        for bit in range(8):
            if pos >= len(data): break
            best_len = best_dist = 0
            p=head[h3(pos)]; candidates=0
            while p>=0 and pos-p<=4095 and candidates<64:
                n = 1
                while n < 18 and pos + n < len(data) and data[p + n] == data[pos + n]:
                    n += 1
                dist = pos - p
                if n >= 3 and (n > best_len or (n == best_len and dist < best_dist)):
                    best_len, best_dist = n, dist
                p=prev[p&4095]; candidates+=1
            if best_len >= 3:
                flags |= 1 << bit
                out += bytes((best_dist & 255, ((best_dist >> 8) << 4) | (best_len - 3)))
                for q in range(pos,pos+best_len): insert(q)
                pos += best_len; matches += 1; longest = max(longest, best_len)
            else:
                out.append(data[pos]); insert(pos); pos += 1; literals += 1
        out[flag_at] = flags
    return bytes(out), {"literals":literals,"matches":matches,"longest":longest}

def unlzss(src: bytes, outlen: int) -> bytes:
    out=bytearray(); sp=0
    while sp < len(src) and len(out) < outlen:
        flags=src[sp]; sp+=1
        for bit in range(8):
            if len(out)>=outlen or sp>=len(src): break
            if flags & (1<<bit):
                a,b=src[sp],src[sp+1]; sp+=2
                dist=a|((b>>4)<<8); n=(b&15)+3
                if not dist or dist>len(out): raise ValueError("bad match")
                for _ in range(n): out.append(out[-dist])
            else: out.append(src[sp]); sp+=1
    if len(out)!=outlen: raise ValueError((len(out),outlen))
    return bytes(out)

def bgr555(rgb):
    r,g,b=rgb
    return (r>>3)|((g>>3)<<5)|((b>>3)<<10)

def cbytes(name, data, cols=16):
    rows=[]
    for i in range(0,len(data),cols):
        rows.append("  "+", ".join(f"0x{x:02X}" for x in data[i:i+cols])+",")
    return f"static GALLERY_BANK({name}) const uint8_t {name}[{len(data)}] = {{\n"+"\n".join(rows)+"\n};\n"

def main():
    DERIVED.mkdir(parents=True,exist_ok=True)
    SOURCE_DIR.mkdir(parents=True,exist_ok=True)
    # The manifest is authoritative. Without pruning, removed works remain in
    # wildcard-based host-oracle runs and make the reported corpus disagree
    # with the generated header, ROM, contact sheet, and web catalog.
    for pattern in ("*.idx", "*.pal", "*.lz", "*-web.png"):
        for stale in DERIVED.glob(pattern):
            stale.unlink()
    spec=json.loads(SOURCES.read_text())
    report=[]; arrays=[]; desc=[]; previews=[]
    works=[w for w in spec["works"] if w.get("enabled",True)]
    for idx,w in enumerate(works,1):
        source_path=SOURCE_DIR/f"{w['slug']}.jpg"
        if source_path.exists():
            source=source_path.read_bytes()
            commons_title=w["commons_file"]
            commons_license=w.get("license",spec["license"])
            url=w.get("image_url","cached:"+source_path.name)
        else:
            if idx > 1: time.sleep(1)
            if "id" in w:
                api=json.loads(get(f"https://api.artic.edu/api/v1/artworks/{w['id']}?fields=id,title,artist_display,date_display,is_public_domain,image_id"))
                d=api["data"]
                if not d.get("is_public_domain") or not d.get("image_id"):
                    raise SystemExit(f"{w['id']}: not public domain or no image")
            if w.get("image_url"):
                commons_title=w.get(
                    "commons_file",
                    f"{w.get('provider', spec['provider'])} image: {w['title']}",
                )
                url=w["image_url"]
                commons_license=w.get("license",spec["license"])
            else:
                commons_title,url,commons_license=commons_named(w["commons_file"])
            source=get(url)
            source_path.write_bytes(source)
        source_hash=hashlib.sha256(source).hexdigest()
        if w.get("source_sha256") and source_hash != w["source_sha256"]:
            raise SystemExit(f"{w['slug']}: source SHA-256 changed: {source_hash}")
        try:
            im=Image.open(io.BytesIO(source))
            im.verify()
            im=Image.open(io.BytesIO(source)).convert("RGB")
        except Exception as e:
            raise SystemExit(f"{w['slug']}: source is not a valid image: {e}")
        # Tall scrolls and murals can have a smaller short edge while still
        # exceeding the gallery's <=256-pixel derived raster. Keep enough
        # source resolution for a clean downsample without excluding them.
        if len(source)<16384 or min(im.size)<384:
            raise SystemExit(f"{w['slug']}: source unexpectedly small: {len(source)} bytes, {im.size}")
        ow,oh=im.size
        shown_h=display_height(w)
        width,height=maximum_aspect_frame(ow,oh,shown_h)
        scale=max(width,math.ceil(height*256/shown_h))
        render_w=(width*256)//scale; render_h=(height*256)//scale
        cols=math.ceil(width/8); rows=math.ceil(height/8)
        assert cols*rows<=MAX_ART_TILES
        crop=(0,0,ow,oh)
        resized=im.resize((width,height),Image.Resampling.LANCZOS)
        q=resized.quantize(colors=ART_COLORS,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.FLOYDSTEINBERG)
        qpal=list(q.getpalette() or [])
        qpal += [0] * max(0, ART_COLORS * 3 - len(qpal))
        dense_pal=[tuple(qpal[i:i+3]) for i in range(0,ART_COLORS*3,3)]
        pixels=bytes(ART_INDICES[x] for x in q.tobytes())
        colors=[(0,0,0)]*256
        for dst,color in zip(ART_INDICES,dense_pal): colors[dst]=color
        assert all(x in ART_INDICES for x in pixels)
        preview=Image.new("RGB",(256,shown_h),(0,0,0))
        indexed=Image.new("RGB",(width,height));indexed.putdata([colors[x] for x in pixels])
        shown=indexed.resize((render_w,render_h),Image.Resampling.NEAREST)
        preview.paste(shown,((256-render_w)//2,(shown_h-render_h)//2))
        previews.append((w["slug"],preview))
        # A compact, one-file-per-work catalog lets the website expose every
        # candidate at a useful size instead of hiding them in a tall contact
        # sheet. This is the exact indexed artwork the SNES displays.
        preview.save(DERIVED/f"{w['slug']}-web.png",optimize=True)
        palbin=b"".join(bgr555(c).to_bytes(2,"little") for c in colors)
        packed,stats=lzss(pixels)
        assert unlzss(packed,len(pixels))==pixels
        fold=0xffff
        for px in pixels: fold=((fold<<1)|(fold>>15))&0xffff; fold^=px
        slug=w["slug"]
        (DERIVED/f"{slug}.idx").write_bytes(pixels)
        (DERIVED/f"{slug}.pal").write_bytes(palbin)
        (DERIVED/f"{slug}.lz").write_bytes(packed)
        symbol=slug.replace("-","_")
        arrays.append(cbytes(f"gallery_{symbol}_lz",packed))
        arrays.append(cbytes(f"gallery_{symbol}_pal",palbin))
        desc.append((symbol,w,len(pixels),len(packed),idx,width,height,shown_h,scale,cols,rows))
        report.append({
          "bank":idx,"slug":slug,"artwork_id":w.get("id"),"title":w["title"],"artist":w["artist"],
          "date":w["date"],"display_date":w["display_date"],
          "provider":w.get("provider",spec["provider"]),
          "object_url":w.get("object_url") or f"https://www.artic.edu/artworks/{w['id']}",
          "image_url":url,"license":w.get("license",spec["license"]),
          "license_url":w.get("license_url",spec["license_url"]),
          "commons_file":commons_title,"commons_license":commons_license,
          "source_dimensions":[ow,oh],"crop":list(crop),"derived_dimensions":[width,height],
          "display_dimensions":[render_w,render_h],"display_region":[256,shown_h],
          "matrix_scale":scale,"tile_grid":[cols,rows],"artwork_tiles":cols*rows,
          "source_jpeg_bytes":len(source),"raw_indexed_bytes":len(pixels),
          "compressed_bytes":len(packed),"reduction_bytes":len(pixels)-len(packed),
          "reduction_percent":round((1-len(packed)/len(pixels))*100,2),
          "checksum":fold,"artwork_color_capacity":ART_COLORS,
          "artwork_colors_used":len(set(pixels)),"artwork_indices_used":sorted(set(pixels)),
          "palette_sha256":hashlib.sha256(palbin).hexdigest(),
          "source_sha256":source_hash,
          "derived_sha256":hashlib.sha256(pixels).hexdigest(),
          **stats
        })
    # William B. Norris IV's 1992 romopt algorithm: stable first-fit
    # decreasing. Streams and palettes are independent items so the small
    # 512-byte palettes can fill holes left by variable-size streams.
    bins=[]; bank_for={}; slot_for={}; bank_items=[]
    shared_specs=[("FONT16",4096),("FONT8",1024)]
    items=[]
    for symbol,w,raw,packed,order,width,height,shown_h,scale,cols,rows in desc:
        items += [(packed,order,0,symbol,"lz"),(512,order,1,symbol,"pal")]
    for order,(symbol,size) in enumerate(shared_specs,len(desc)):
        items.append((size,order,2,symbol,"shared"))
    for size,order,kind,symbol,part in sorted(items,key=lambda x:(-x[0],x[1],x[2])):
        for bank,used in enumerate(bins,1):
            if used+size<=32768:
                bins[bank-1]+=size
                bank_for[(symbol,part)]=bank
                slot_for[(symbol,part)]=len(bank_items[bank-1])
                bank_items[bank-1].append((symbol,part,size))
                break
        else:
            bins.append(size)
            bank_items.append([(symbol,part,size)])
            bank_for[(symbol,part)]=len(bins)
            slot_for[(symbol,part)]=0
    # Bank $00 is exclusively runtime/shared data. romopt's asset bins are
    # deliberately one-based and may never place a stream or palette there.
    assert bank_for and min(bank_for.values()) == 1
    assert 0 not in bank_for.values()
    for item in report:
        item["manifest_order"]=item["bank"]
        symbol=item["slug"].replace("-","_")
        item["stream_bank"]=bank_for[(symbol,"lz")]
        item["palette_bank"]=bank_for[(symbol,"pal")]
        item["stream_slot"]=slot_for[(symbol,"lz")]
        item["palette_slot"]=slot_for[(symbol,"pal")]
        del item["bank"]
    shared_report=[]
    for symbol,size in shared_specs:
        shared_report.append({
            "symbol":symbol,"bytes":size,
            "bank":bank_for[(symbol,"shared")],
            "slot":slot_for[(symbol,"shared")],
        })
    (ROOT/"examples/snes/lzss-gallery-layout.h").write_text(
        "// GENERATED by tools/lzss-gallery-assets.py; do not edit.\n"
        "#ifndef LZSS_GALLERY_LAYOUT_H\n#define LZSS_GALLERY_LAYOUT_H\n"
        + "\n".join(
            f'#define GALLERY_{item["symbol"]}_SECTION ".gallery_{item["bank"]:02X}.{item["slot"]:02X}"'
            for item in shared_report
        )
        + "\n#endif\n"
    )
    (DERIVED/"packing.json").write_text(json.dumps({
        "algorithm":"romopt stable first-fit decreasing",
        "bank_bytes":32768,"bank_zero_locked":True,
        "shared_assets":shared_report,
        "bank_items":[
            [{"symbol":symbol,"part":part,"bytes":size}
             for symbol,part,size in items]
            for items in bank_items
        ],
        "bank_used":bins,
    },indent=2)+"\n")

    hdr=["// GENERATED by tools/lzss-gallery-assets.py; do not edit.","#ifndef LZSS_GALLERY_ASSETS_H","#define LZSS_GALLERY_ASSETS_H",
         "#include <stdint.h>","#define GALLERY_FAR __attribute__((address_space(2)))",
         "#define GALLERY_BANK(name) __attribute__((section(\".gallery_\" #name))) GALLERY_FAR",""]
    # Section macro needs bank token, not symbol: rewrite array declarations explicitly.
    body=[]
    for (symbol,w,raw,packed,order,width,height,shown_h,scale,cols,rows),chunk in zip(desc,[arrays[i:i+2] for i in range(0,len(arrays),2)]):
        lzsec=(f"{bank_for[(symbol,'lz')]:02X}."
               f"{slot_for[(symbol,'lz')]:02X}")
        palsec=(f"{bank_for[(symbol,'pal')]:02X}."
                f"{slot_for[(symbol,'pal')]:02X}")
        body.append(chunk[0].replace(f"GALLERY_BANK(gallery_{symbol}_lz)",f'__attribute__((section(".gallery_{lzsec}"))) GALLERY_FAR'))
        body.append(chunk[1].replace(f"GALLERY_BANK(gallery_{symbol}_pal)",f'__attribute__((section(".gallery_{palsec}"))) GALLERY_FAR'))
    hdr += body
    corpus_oracle=0xffff
    for item in report:
        for value in (item["checksum"]&255,item["checksum"]>>8,
                      item["compressed_bytes"]&255,item["compressed_bytes"]>>8):
            corpus_oracle=((corpus_oracle<<1)|(corpus_oracle>>15))&0xffff
            corpus_oracle^=value
    hdr += [f"#define GALLERY_ASSET_COUNT {len(desc)}u",
            f"#define GALLERY_CORPUS_ORACLE 0x{corpus_oracle:04X}u",
            "typedef struct { const GALLERY_FAR uint8_t *lz; const GALLERY_FAR uint8_t *pal; uint16_t raw_len,lz_len,checksum; uint8_t width,height; const char *artist_small_before,*artist_large,*artist_small_after,*date; const char *title[2]; } GalleryAsset;",
            f"static const GalleryAsset GALLERY_ASSETS[{len(desc)}] = {{"]
    folds={item["slug"]:item["checksum"] for item in report}
    for symbol,w,raw,packed,order,width,height,shown_h,scale,cols,rows in desc:
        lzbank=bank_for[(symbol,"lz")];palbank=bank_for[(symbol,"pal")]
        before=w["artist_small_before"]; large=w["artist_large"]; after=w["artist_small_after"]
        assert len(before)*8 + len(large)*16 + len(after)*8 <= 256
        tt=w["display_title"]+[""]
        fold=folds[w["slug"]]
        hdr.append(f'  {{gallery_{symbol}_lz,gallery_{symbol}_pal,{raw},{packed},0x{fold:04X},{width},{height},"{before}","{large}","{after}","{w["display_date"]}",{{"{tt[0]}","{tt[1]}"}},}},')
    hdr += ["};","#endif"]
    (ROOT/"examples/snes/lzss-gallery-assets.h").write_text("\n".join(hdr)+"\n")
    (DERIVED/"report.json").write_text(json.dumps(report,indent=2)+"\n")
    catalog=[{
        "slug":item["slug"],"artist":item["artist"],"title":item["title"],
        "date":item["date"],"object_url":item["object_url"],
        "preview":f"/play/preview/lzss-gallery/{item['slug']}-web.png",
    } for item in report]
    (DERIVED/"catalog.json").write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n")
    sheet=Image.new("RGB",(512,math.ceil(len(previews)/2)*224),(16,16,16))
    for i,(slug,preview) in enumerate(previews):
        x=(i%2)*256;y=(i//2)*224
        sheet.paste(preview,(x,y))
    sheet.save(DERIVED/"contact-sheet.png",optimize=False)
    print(json.dumps(report,indent=2))

if __name__=="__main__": main()
