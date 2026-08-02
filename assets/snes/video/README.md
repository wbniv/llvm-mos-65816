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

## Public Artemis 2x + Apollo 59.94p reel

`dev/snes-video-artemis-apollo.sh` builds the public 1,200-frame, 20-second reel.
It uses one source frame per cartridge VBlank throughout—without interpolation:

- `Pre-launch_through_launch.webm`, NASA SVS item 14191, progressive
  `30000/1001`, SHA-256
  `28f9e843111466b3ce1869975283d71a1779f593974f49d76a6da9683c769a3d`;
- `Return_to_Earth.webm`, NASA SVS item 14191, progressive `30000/1001`,
  SHA-256
  `bc0d89e9cf9ca33a3faa2fed6d653c9eddede0458d0ab010c228535621516dc8`;
- `apollo11-daylight-5994p.mp4`, a 600-frame excerpt beginning at 00:56:50
  from the NASA Images Apollo 11 press-site `~large.mp4`, progressive
  `220999/3687` (approximately 59.94 fps), SHA-256
  `0691dda94cd0ffc9da557a3a3e5855118b8b616765f43cd470dd204eae43758f`.

The full Apollo master is not vendored: it is 2,366,402,930 bytes and has
SHA-256 `4e7c693a2c6480b4450343bd7482eaac9a758a39240d61f37d4db7b98c1d401b`.
The first two 300-frame sections intentionally display 29.97p animation at 2x;
the Apollo section preserves 600 consecutive temporal samples at its native
approximately-59.94p cadence.
