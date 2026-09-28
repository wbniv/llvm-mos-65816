#!/usr/bin/env bash
# Compile the specialized web cartridges; publication runs the manifest gates.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
slug="${1:?ROM ID required}"
ROM="$BUILD/$slug.sfc"
MAP="$BUILD/$slug.map"
GEN="$BUILD/web-rom-assets/$slug"
mkdir -p "$GEN"
cfg="$INSTALL/bin/mos-snes.cfg"
src="$ROOT/examples/snes/$slug.c"
flags=(-Os)
sources=()
mapping=lorom
speed=slow
size=
stream=
case "$slug" in
  bankwalk|farptrcmp)
    cfg="$INSTALL/bin/mos-snes-hirom.cfg"
    mapping=hirom
    python3 "$ROOT/tools/gen-bankwalk-asm.py" "$GEN/bankwalk-table.s"
    sources+=("$GEN/bankwalk-table.s") ;;
  lzss-gallery)
    cfg="$INSTALL/bin/mos-snes-gallery.cfg"
    flags=(-Oz) ;;
  seamdemo)
    mapping=exhirom; size=6M
    cfg="$INSTALL/bin/mos-snes-cart-seamdemo.cfg"
    python3 "$ROOT/tools/snes-cartcanary.py" emit-platform --mapping "$mapping" \
      --size "$size" --name snes-cart-seamdemo --install "$INSTALL"
    python3 "$ROOT/tools/snes-seamdemo-gen.py" emit-header --mapping "$mapping" \
      --size "$size" --out "$GEN/seamdemo-data.h"
    python3 "$ROOT/tools/snes-seamdemo-gen.py" emit-decode --mapping "$mapping" \
      --size "$size" --out "$GEN/seamdemo-decode.h"
    flags+=(-I "$GEN") ;;
  cartsize-hirom-4m|cartsize-exhirom-6m|cartsize-exhirom-8m)
    case "$slug" in
      cartsize-hirom-4m) mapping=hirom; size=4M; tag=hirom4 ;;
      cartsize-exhirom-6m) mapping=exhirom; size=6M; tag=exhirom6 ;;
      cartsize-exhirom-8m) mapping=exhirom; size=8M; tag=exhirom8 ;;
    esac
    cfg="$INSTALL/bin/mos-snes-cart-$tag.cfg"
    src="$ROOT/examples/snes/cartsize-canary.c"
    python3 "$ROOT/tools/snes-cartcanary.py" emit-platform --mapping "$mapping" \
      --size "$size" --name "snes-cart-$tag" --install "$INSTALL"
    python3 "$ROOT/tools/snes-cartcanary.py" emit-header --mapping "$mapping" \
      --size "$size" --out "$GEN/cartsize-canary-data.h" --label "$tag $mapping $size slow"
    flags+=(-I "$GEN") ;;
  apollo-daylight)
    # The paired header and compressed stream are baked by dev/apollo-reel.sh.
    for asset in apollo-reel-assets.h apollo-reel-stream.bin; do
      [ -s "$BUILD/$asset" ] || { echo "Missing $asset; run dev/apollo-reel.sh"; exit 1; }
      cp "$BUILD/$asset" "$GEN/$asset"
    done
    grep -qx '#define VIDEO_REEL_FRAME_COUNT 600u' "$GEN/apollo-reel-assets.h"
    cfg="$INSTALL/bin/mos-snes-hirom.cfg"
    src="$ROOT/examples/snes/apollo-reel.c"
    mapping=hirom; speed=fast
    stream="$GEN/apollo-reel-stream.bin"
    flags+=(-DSVC_USE_ASM -DAPOLLO_REEL_FASTROM -DAPOLLO_REEL_VBLANKS_PER_FRAME=1 -I "$GEN")
    sources+=("$ROOT/examples/snes/apollo-reel-fast.s") ;;
  svx2-fastrom-video)
    # Use the 1,200-frame publication corpus, independent of other reel builds.
    for ext in tiles pal; do
      [ -s "$BUILD/artemis-apollo-60.$ext" ] || {
        echo "Missing artemis-apollo-60.$ext; run dev/snes-video-artemis-apollo.sh"; exit 1;
      }
    done
    mapping=exhirom; speed=fast
    cfg="$INSTALL/bin/mos-snes-video-exhirom.cfg"
    python3 "$ROOT/tools/snes-cartcanary.py" emit-platform --mapping exhirom \
      --size 8M --name snes-video-exhirom --install "$INSTALL"
    stream="$GEN/snes-video-reel-stream.bin"
    python3 "$ROOT/tools/snes-video-reel-assets.py" --frames 1200 --packed-far \
      --keyframe-interval 60 --exhirom --exhirom-seam-frame 600 \
      --segment '0:SVS LAUNCH / 2X' --segment '300:SVS RETURN / 2X' \
      --segment '600:APOLLO 11 / 60P' --stream-output "$stream" \
      "$BUILD/artemis-apollo-60.tiles" "$BUILD/artemis-apollo-60.pal" "$GEN/snes-video-reel-assets.h"
    src="$ROOT/examples/snes/snes-video-reel.c"
    flags+=(-DSVC_USE_ASM -DVIDEO_REEL_VBLANKS_PER_FRAME=1 -I "$GEN")
    sources+=("$ROOT/examples/snes/snes-video-reel-fast.s") ;;
  *) echo "Unknown special cartridge: $slug" >&2; exit 2 ;;
esac
if [ -n "$stream" ]; then
  sources+=("$ROOT/examples/snes/snes-video-codec.c"
    "$ROOT/examples/snes/snes-video-dma.c" "$ROOT/examples/snes/snes-video-codec-fast.s")
fi
"$TOOL/mos-clang" --config "$cfg" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 "${flags[@]}" -I "$ROOT/examples/snes" \
  -Wl,-Map="$MAP" -o "$ROM" "$src" "${sources[@]}"
case "$slug" in
  seamdemo)
    python3 "$ROOT/tools/snes-seamdemo-gen.py" check-extents --mapping "$mapping" \
      --size "$size" --rom "$ROM" --json "$GEN/extents.json"
    python3 "$ROOT/tools/snes-seamdemo-gen.py" fill --mapping "$mapping" \
      --size "$size" --rom "$ROM" --report "$GEN/fill.json" ;;
  cartsize-*)
    python3 "$ROOT/tools/snes-cartcanary.py" fill --mapping "$mapping" \
      --size "$size" --rom "$ROM" --json "$GEN/fill.json" ;;
  apollo-daylight|svx2-fastrom-video)
    python3 "$ROOT/tools/snes-video-pack-$mapping.py" "$ROM" "$stream" ;;
esac
python3 "$ROOT/tools/snes-checksum.py" --mapping "$mapping" --speed "$speed" "$ROM"
python3 "$ROOT/tools/snes-checksum.py" --inspect --mapping "$mapping" --speed "$speed" "$ROM"
