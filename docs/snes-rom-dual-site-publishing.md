# Publishing SNES ROMs to both sites

Every SNES ROM release is a paired publication. A release is incomplete unless the same ROM is
available from both biohack.net and indri.studio, with a playable page, preview, manifest entry, and
matching SHA-256 on each site.

Prepare the site-specific metadata and previews, then run the read-only preflight:

```sh
dev/publish-snes-rom-both-sites.sh \
  --slug svx2-fastrom-video \
  --rom build/svx2-video-reel.sfc
```

To copy, build, commit, push, tag, deploy, and live-verify both sites as one operation:

```sh
dev/publish-snes-rom-both-sites.sh \
  --slug svx2-fastrom-video \
  --rom build/svx2-video-reel.sfc \
  --preview build/svx2-video-reel.png \
  --publish
```

The command fails before tagging if either site lacks its page metadata, manifest entry, preview,
or matching ROM. After tagging, it polls all four live URLs and refuses success until both ROM
downloads match the source SHA-256. Its final output always prints both page URLs and both direct
ROM URLs.
