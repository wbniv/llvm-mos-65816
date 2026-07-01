# Generate a 16x16 color-cell "image" (values 0..3), LZSS-encode it, emit a C const array.
# Decoder format (matches lzdec.h): stream = repeated [flag byte][8 tokens].
#   flag bit b (LSB first): 0 = literal (1 byte), 1 = match (2 bytes: b0=low8 offset, b1=hi4 offset|len4)
#   match: offset = ((b1>>4)<<8)|b0  (12-bit, backward distance in output), length = (b1&0xF)+MINMATCH
MIN=3
W=16;H=16
# a symmetric diamond/bands pattern -> lots of repeated rows/runs (compresses well)
img=[]
for y in range(H):
    for x in range(W):
        d=abs(x-8)+abs(y-8)          # diamond distance
        img.append(d & 3)
data=bytes(img)  # 256 bytes, values 0..3

def find_match(data,i):
    best_len=0; best_off=0
    lo=max(0,i-4095)
    # greedy longest match in window [lo, i)
    maxlen=min(MIN+15, len(data)-i)
    for off in range(1, i-lo+1):
        j=i-off; l=0
        while l<maxlen and data[i+l]==data[j+(l%off)]:  # overlap-aware
            l+=1
        if l>=MIN and l>best_len:
            best_len=l; best_off=off
    return best_off,best_len

out=bytearray()
i=0
while i<len(data):
    flag_pos=len(out); out.append(0); flags=0
    for b in range(8):
        if i>=len(data): break
        off,ln=find_match(data,i)
        if ln>=MIN:
            flags|=(1<<b)
            l4=ln-MIN
            b0=off & 0xFF
            b1=((off>>8)&0x0F)<<4 | (l4 & 0x0F)
            out.append(b0); out.append(b1)
            i+=ln
        else:
            out.append(data[i]); i+=1
    out[flag_pos]=flags
print(f"// source {len(data)} bytes -> compressed {len(out)} bytes")
print(f"#define LZ_SRCLEN {len(out)}u")
print(f"#define LZ_OUTLEN {len(data)}u")
print("static const uint8_t LZ_STREAM[LZ_SRCLEN] = {")
for k in range(0,len(out),16):
    print("  "+", ".join(f"0x{c:02X}" for c in out[k:k+16])+",")
print("};")
# sanity: decode and compare
def decode(src):
    dst=bytearray(); sp=0
    while sp<len(src):
        fl=src[sp]; sp+=1
        for b in range(8):
            if sp>=len(src): break
            if fl&(1<<b):
                b0=src[sp]; b1=src[sp+1]; sp+=2
                off=((b1>>4)<<8)|b0; ln=(b1&0xF)+MIN
                frm=len(dst)-off
                for k in range(ln): dst.append(dst[frm+k])
            else:
                dst.append(src[sp]); sp+=1
    return bytes(dst)
dec=decode(bytes(out))
import sys
sys.stderr.write(f"roundtrip {'OK' if dec==data else 'FAIL'} (dec {len(dec)} vs {len(data)})\n")
