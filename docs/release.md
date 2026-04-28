# Safari Gauntlet Release Artifacts

Build release artifacts with:

```bash
python3 utils/build_safari_release_artifacts.py --base-rom /path/to/clean-crystal.gbc
```

By default, artifacts use the Safari Gauntlet release version `1.0.3`. Pass `--version <version>` for a later release.

The clean base ROM should be:

```text
Pokemon - Crystal Version (UE) (V1.0) [C][!].gbc
MD5: 9f2922b235a5eeb78d65594e82ef5dde
```

The script follows the Polished Crystal release flow by building the ROM and symbol file into `build/`. When `--base-rom` is provided, it also writes verified `.bps` and `.ips` patches that recreate the built ROM from the clean base ROM.

`build/` artifacts are generated outputs and are not checked into source control. To publish the ROM-style release assets like Polished Crystal, run the `Safari Gauntlet Release` GitHub Actions workflow. It builds the artifacts on GitHub and attaches them to a GitHub Release.

Expected outputs:

```text
build/safari-gauntlet-<version>.gbc
build/safari-gauntlet-<version>.sym
build/safari-gauntlet-<version>.bps
build/safari-gauntlet-<version>.ips
build/safari-gauntlet-<version>.3ds-vc.patch
```

Use `--no-vc-patch` if you only need Delta/mobile emulator artifacts.

The GitHub release workflow does not create `.bps` or `.ips` patches because the CI runner does not have your clean base ROM. Generate those locally with `--base-rom` and upload them manually if you want patch assets on the release.
