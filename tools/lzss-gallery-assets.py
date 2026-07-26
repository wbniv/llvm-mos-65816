#!/usr/bin/env python3
"""Fetch pinned ArtIC CC0 works and generate deterministic SNES gallery assets.

Run only in the development container. Normal ROM builds consume checked-in derived
files and never access the network.
"""
from __future__ import annotations
import hashlib, io, json, pathlib, time, urllib.error, urllib.request
import urllib.parse
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/snes/lzss-gallery"
DERIVED = BASE / "derived"
SOURCES = BASE / "sources.json"
W, COLORS = 128, 32

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
    spec=json.loads(SOURCES.read_text())
    report=[]; arrays=[]; desc=[]
    for idx,w in enumerate(spec["works"],1):
        if idx > 1: time.sleep(1)
        api=json.loads(get(f"https://api.artic.edu/api/v1/artworks/{w['id']}?fields=id,title,artist_display,date_display,is_public_domain,image_id"))
        d=api["data"]
        if not d.get("is_public_domain") or not d.get("image_id"):
            raise SystemExit(f"{w['id']}: not public domain or no image")
        image_id=d["image_id"]
        commons_title,url,commons_license=commons_named(w["commons_file"])
        source=get(url); im=Image.open(io.BytesIO(source)).convert("RGB")
        ow,oh=im.size; h=w["height"]
        target_ratio=W/h; source_ratio=ow/oh
        if source_ratio>target_ratio:
            nw=round(oh*target_ratio); left=(ow-nw)//2; crop=(left,0,left+nw,oh)
        else:
            nh=round(ow/target_ratio); top=(oh-nh)//2; crop=(0,top,ow,top+nh)
        resized=im.crop(crop).resize((W,h),Image.Resampling.LANCZOS)
        q=resized.quantize(colors=COLORS,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.FLOYDSTEINBERG)
        pal=q.getpalette()[:COLORS*3]
        # Reserve index 0 for black by shifting every image index and use <=31 art colours.
        pixels=bytes(x+1 for x in q.tobytes())
        colors=[(0,0,0)]+[tuple(pal[i:i+3]) for i in range(0,len(pal),3)]
        colors=colors[:32]
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
        desc.append((symbol,w,len(pixels),len(packed),idx))
        report.append({
          "bank":idx,"slug":slug,"artwork_id":w["id"],"title":d["title"],"artist":w["artist"],
          "object_url":f"https://www.artic.edu/artworks/{w['id']}","iiif_url":url,
          "commons_file":commons_title,"commons_license":commons_license,
          "source_dimensions":[ow,oh],"crop":list(crop),"derived_dimensions":[W,h],
          "source_jpeg_bytes":len(source),"raw_indexed_bytes":len(pixels),
          "compressed_bytes":len(packed),"reduction_bytes":len(pixels)-len(packed),
          "reduction_percent":round((1-len(packed)/len(pixels))*100,2),
          "checksum":fold,
          "source_sha256":hashlib.sha256(source).hexdigest(),
          "derived_sha256":hashlib.sha256(pixels).hexdigest(),
          **stats
        })
    hdr=["// GENERATED by tools/lzss-gallery-assets.py; do not edit.","#ifndef LZSS_GALLERY_ASSETS_H","#define LZSS_GALLERY_ASSETS_H",
         "#include <stdint.h>","#define GALLERY_FAR __attribute__((address_space(2)))",
         "#define GALLERY_BANK(name) __attribute__((section(\".gallery_\" #name))) GALLERY_FAR",""]
    # Section macro needs bank token, not symbol: rewrite array declarations explicitly.
    body=[]
    for (symbol,w,raw,packed,bank),chunk in zip(desc,[arrays[i:i+2] for i in range(0,len(arrays),2)]):
        sec=f"{bank:02X}"
        body += [x.replace(f"GALLERY_BANK(gallery_{symbol}_lz)",f'__attribute__((section(".gallery_{sec}"))) GALLERY_FAR')
                 .replace(f"GALLERY_BANK(gallery_{symbol}_pal)",f'__attribute__((section(".gallery_{sec}"))) GALLERY_FAR') for x in chunk]
    hdr += body
    hdr += [f"#define GALLERY_ASSET_COUNT {len(desc)}u",
            "typedef struct { const GALLERY_FAR uint8_t *lz; const GALLERY_FAR uint8_t *pal; uint16_t raw_len,lz_len,checksum; uint8_t height,artist_rows,title_rows,bank; const char *artist[2]; const char *title[2]; } GalleryAsset;",
            f"static const GalleryAsset GALLERY_ASSETS[{len(desc)}] = {{"]
    for symbol,w,raw,packed,bank in desc:
        aa=w["display_artist"]+[""]; tt=w["display_title"]+[""]
        fold=report[bank-1]["checksum"]
        hdr.append(f'  {{gallery_{symbol}_lz,gallery_{symbol}_pal,{raw},{packed},0x{fold:04X},{w["height"]},{len(w["display_artist"])},{len(w["display_title"])},{bank},{{"{aa[0]}","{aa[1]}"}},{{"{tt[0]}","{tt[1]}"}},}},')
    hdr += ["};","#endif"]
    (ROOT/"examples/snes/lzss-gallery-assets.h").write_text("\n".join(hdr)+"\n")
    (DERIVED/"report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))

if __name__=="__main__": main()
