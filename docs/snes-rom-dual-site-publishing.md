# Publishing SNES ROMs to both sites

Every SNES ROM release is a paired publication. A release is incomplete unless the same ROM is
available from both biohack.net and indri.studio, with a playable page, preview, manifest entry, and
matching SHA-256 on each site.

Compiler-behavior demos may also have a contract in `dev/natural-rom-contracts/`. For those demos,
the publisher fails closed unless the demo gate has created `build/<slug>.natural-pass`. The receipt
binds the pass to the exact ROM bytes, natural source, declared evidence, and contract. Editing the
source or contract, rebuilding different ROM bytes, or failing before the emulator differential
therefore makes the artifact unpublishable.

If a demo originally exposes a compiler defect, it also has a public-provenance
contract. Register it in
[`snes-demo-compiler-bug-pages.json`](snes-demo-compiler-bug-pages.json) and
follow the detailed discovery-page requirements in
[`investigations/2026-09-26-snes-demo-bug-page-audit.md`](investigations/2026-09-26-snes-demo-bug-page-audit.md).
The paired-publication preflight rejects a registered demo unless the biohack
page has its machine-readable `compilerBug` marker, which activates the required
**Compiler defect this ROM exposed** section. The gallery's bug badge is derived
from that same marker. A later regression-only demo is not registered merely
because it exercises an earlier fix.

Before an upstream PR is recorded for a discovery, add its reviewed internal PR simulation to the
registry. The generated discovery map fails if a `prs` entry lacks `pr_simulations`.

For the compiler stress-test battery, passing the host/default/a16/xy16 gate is not the end of the
per-ROM workflow. Unless the user explicitly says not to publish, “done” also requires this paired
publication gate, both site builds, both manifest self-checks, and live page/ROM verification.

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
