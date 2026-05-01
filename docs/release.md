# Safari Gauntlet Release Artifacts

Safari Gauntlet releases should publish patch files, not ROM files. The release
helper still builds a local `.gbc` and `.sym` so every patch can be verified
against the exact output before a tag is published.

Build the full release set with:

```bash
python3 utils/build_safari_release_artifacts.py --version 1.0.8 --build-pret-base-roms
```

Before bumping or publishing a release, keep a local test build under ignored
`tmp/`:

```bash
python3 utils/build_safari_release_artifacts.py \
  --version 1.0.8 \
  --build-pret-base-roms \
  --build-dir tmp/release-checks/v1.0.8
```

This stores local verification ROMs and patches without making them release
assets:

```text
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8.gbc
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8.sym
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8-crystal-v1.0.bps
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8-crystal-v1.0.ips
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8-crystal-v1.1-rev1.bps
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8-crystal-v1.1-rev1.ips
tmp/release-checks/v1.0.8/safari-gauntlet-1.0.8.3ds-vc.patch
tmp/release-checks/v1.0.8/MD5SUMS
tmp/release-checks/v1.0.8/SHA256SUMS
tmp/release-checks/v1.0.8/LOCAL_MD5SUMS
tmp/release-checks/v1.0.8/LOCAL_SHA256SUMS
```

The generated `.gbc` files are local verification outputs only. Do not upload
or distribute them. `LOCAL_*SUMS` includes hashes for local verification
outputs, including the generated `.gbc`; public `MD5SUMS` and `SHA256SUMS`
include only patch assets intended for release.

## Patch Bases

The release helper can build both supported base ROM fixtures from
`pret/pokecrystal` and verifies their checksums before patch creation.

```text
Pokemon - Crystal Version (UE) (V1.0) [C][!].gbc
MD5: 9f2922b235a5eeb78d65594e82ef5dde
SHA1: f4cd194bdee0d04ca4eac29e09b8e4e9d818c133

Pokemon - Crystal Version (USA, Europe) (Rev 1).gbc
MD5: 301899b8087289a6436b0a241fbbb474
SHA1: f2f52230b536214ef7c9924f483392993e226cfb
```

BPS is the preferred player-facing format because it verifies the source ROM
before applying. IPS is included for patcher compatibility.

## GitHub Release

Run the `Safari Gauntlet Release` GitHub Actions workflow with the target
version and tag, for example `1.0.8` and `v1.0.8`.

The workflow builds the local `.gbc` for verification but uploads only:

```text
build/safari-gauntlet-<version>-crystal-v1.0.bps
build/safari-gauntlet-<version>-crystal-v1.0.ips
build/safari-gauntlet-<version>-crystal-v1.1-rev1.bps
build/safari-gauntlet-<version>-crystal-v1.1-rev1.ips
build/safari-gauntlet-<version>.3ds-vc.patch
build/MD5SUMS
build/SHA256SUMS
```

The public checksum manifests include only the uploaded patch assets. Local
test-build manifests with generated `.gbc` hashes stay under ignored `tmp/`.
