# Development

This document is for contributors building Safari Gauntlet locally or preparing release artifacts.

## Local Build

If you are building locally without release patches, run:

```bash
make -j8
```

Then load the built `.gbc` in an accurate Game Boy Color emulator such as [mGBA](https://mgba.io/), [SameBoy](https://sameboy.github.io/), [BGB](https://bgb.bircd.org/), or Gambatte. Do not use VBA or VBA-M.

## Release Artifacts

If you want to build release artifacts yourself, use the repo-local release helper:

```bash
python3 utils/build_safari_release_artifacts.py --version 1.0.8 --build-pret-base-roms
```

The release helper builds local test ROMs and verified patch artifacts such as:

```text
build/safari-gauntlet-1.0.8.gbc
build/safari-gauntlet-1.0.8.sym
build/safari-gauntlet-1.0.8-crystal-v1.0.bps
build/safari-gauntlet-1.0.8-crystal-v1.0.ips
build/safari-gauntlet-1.0.8-crystal-v1.1-rev1.bps
build/safari-gauntlet-1.0.8-crystal-v1.1-rev1.ips
build/safari-gauntlet-1.0.8.3ds-vc.patch
build/MD5SUMS
build/SHA256SUMS
```

Do not distribute the generated `.gbc` files. They are local verification outputs only.

Before bumping or publishing a release, prefer writing local verification builds to ignored `tmp/`:

```bash
python3 utils/build_safari_release_artifacts.py \
  --version 1.0.8 \
  --build-pret-base-roms \
  --build-dir tmp/release-checks/v1.0.8
```

See [docs/release.md](docs/release.md) for the full release checklist and patch-base checksums.
