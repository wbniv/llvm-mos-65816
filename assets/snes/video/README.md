# SNES video source assets

## Native-60 XRISM reel

`XRISM_360_4k_60fps_h264.mp4` is the native 60-fps master used by
`dev/snes-video-native60.sh`.

- Source: [NASA Scientific Visualization Studio item 20374 — XRISM Beauty Shots](https://svs.gsfc.nasa.gov/20374/)
- Direct asset: `https://svs.gsfc.nasa.gov/vis/a020000/a020300/a020374/XRISM_360_4k_60fps_h264.mp4`
- Published format: 3840×2160, 60 fps
- Local `ffprobe`: 3,599 frames, `r_frame_rate=60/1`, `avg_frame_rate=60/1`,
  duration 59.983333 seconds
- SHA-256: `ce09abd9d0cea0a82bc32b53f32862e7e09dbd992178b454b3ed44d62143abd2`
- Credit requested by the source page: NASA's Goddard Space Flight Center Conceptual Image Lab

The cartridge uses native source frames 0–599, 1200–1799, and 2400–2999. It does
not duplicate 30-fps frames or synthesize intermediate frames.
