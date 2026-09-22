# NASA footage verification — 2026-09-20

The public SVX2 reel uses two Artemis animation excerpts and one Apollo 11 launch
excerpt, as recorded in `assets/snes/video/README.md` and selected by
`dev/snes-video-artemis-apollo.sh`. The build concatenates video streams into raw
RGB frames (`concat=n=3:v=1:a=0`); source audio is not included.

- [NASA SVS 14191](https://svs.gsfc.nasa.gov/14191/) supplies
  `Pre-launch_through_launch.webm` and `Return_to_Earth.webm`, with credit to NASA's
  Goddard Space Flight Center. No third-party copyright exception is listed for
  these animations.
- [NASA's Apollo item](https://images.nasa.gov/details/KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372)
  is titled “Video - Apollo 11 Pre-Launch and Launch.” The NASA Images search API
  metadata identifies photographer NASA, center KSC, date 1969-07-16. No third-party
  copyright notice appears in that metadata.
- [SVS reuse policy](https://svs.gsfc.nasa.gov/help/) declares its content public
  domain unless otherwise noted and permits downloading, use and redistribution.
  It distinguishes potentially licensed music from public-domain visualizations.
- [NASA media guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/)
  describe NASA content as generally not subject to U.S. copyright, permit factual
  informational use, request NASA credit, and prohibit implying endorsement.
  Third-party material and agency identifiers have separate restrictions.

The media-rights paragraph has been removed from the compiler PR because its test
contains no video assets. Retain these sources and reuse notes beside any future
checked-in test that actually includes the visual excerpts. It does not assert that every NASA
asset, logo, audio track, or possible use is unrestricted.
