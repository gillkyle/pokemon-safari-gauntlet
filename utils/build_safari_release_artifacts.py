#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

DEFAULT_PREFIX = "safari-gauntlet"
DEFAULT_RELEASE_VERSION = "1.0.7"
EXPECTED_CRYSTAL_MD5 = "9f2922b235a5eeb78d65594e82ef5dde"
PRET_POKECRYSTAL_REPO = "https://github.com/pret/pokecrystal.git"


@dataclass(frozen=True)
class PretBaseRom:
    label: str
    make_goal: str
    rom_name: str
    fixture_name: str
    md5: str
    sha1: str


PRET_BASE_ROMS = (
    PretBaseRom(
        label="crystal-v1.0",
        make_goal="crystal",
        rom_name="pokecrystal.gbc",
        fixture_name="pokemon-crystal-v1.0.gbc",
        md5="9f2922b235a5eeb78d65594e82ef5dde",
        sha1="f4cd194bdee0d04ca4eac29e09b8e4e9d818c133",
    ),
    PretBaseRom(
        label="crystal-v1.1-rev1",
        make_goal="crystal11",
        rom_name="pokecrystal11.gbc",
        fixture_name="pokemon-crystal-v1.1.gbc",
        md5="301899b8087289a6436b0a241fbbb474",
        sha1="f2f52230b536214ef7c9924f483392993e226cfb",
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build Safari Gauntlet release artifacts and verified ROM patches."
        )
    )
    parser.add_argument(
        "-v",
        "--version",
        default=DEFAULT_RELEASE_VERSION,
        help=f"Release version identifier (default: {DEFAULT_RELEASE_VERSION}).",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        help="Number of parallel jobs to pass to make (defaults to CPU count).",
    )
    parser.add_argument(
        "--prefix",
        default=DEFAULT_PREFIX,
        help=f"Output artifact prefix (default: {DEFAULT_PREFIX}).",
    )
    parser.add_argument(
        "--build-dir",
        type=Path,
        help="Directory for artifacts (default: ./build).",
    )
    parser.add_argument(
        "--base-rom",
        type=Path,
        help=(
            "Clean Pokemon Crystal ROM to diff against. When provided, the "
            "script writes verified .bps and .ips patches for this one base."
        ),
    )
    parser.add_argument(
        "--expected-base-md5",
        default=EXPECTED_CRYSTAL_MD5,
        help=(
            "Expected MD5 for --base-rom. Pass an empty string with "
            "--skip-base-md5-check to disable."
        ),
    )
    parser.add_argument(
        "--skip-base-md5-check",
        action="store_true",
        help="Do not require --base-rom to match --expected-base-md5.",
    )
    parser.add_argument(
        "--build-pret-base-roms",
        action="store_true",
        help=(
            "Build Pokemon Crystal v1.0 and v1.1 base ROM fixtures from "
            "pret/pokecrystal and create separate verified patches for both."
        ),
    )
    parser.add_argument(
        "--pret-pokecrystal-dir",
        type=Path,
        help=(
            "Checkout directory for pret/pokecrystal when using "
            "--build-pret-base-roms (default: ./tmp/release-base-roms/pokecrystal)."
        ),
    )
    parser.add_argument(
        "--base-fixture-dir",
        type=Path,
        help=(
            "Directory for generated local base ROM fixtures when using "
            "--build-pret-base-roms (default: ./tmp/rom-fixtures)."
        ),
    )
    parser.add_argument(
        "--no-vc-patch",
        action="store_true",
        help="Skip the 3DS Virtual Console .patch artifact.",
    )
    return parser.parse_args()


def run_make(repo_root: Path, version: str, jobs: int, goals: list[str]) -> None:
    job_flag = f"-j{jobs}" if jobs > 0 else "-j"
    cmd = ["make", job_flag, f"VERSION={version}"] + goals
    print(" ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=repo_root, check=True)


def run_command(cmd: list[str], cwd: Path) -> None:
    print(" ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def move_artifact(repo_root: Path, build_dir: Path, source_name: str, dest_name: str) -> Path:
    source = repo_root / source_name
    if not source.exists():
        raise FileNotFoundError(f"Expected artifact missing: {source_name}")

    dest = build_dir / dest_name
    if dest.exists():
        dest.unlink()
    shutil.move(str(source), str(dest))
    return dest


def file_md5(path: Path) -> str:
    return file_digest(path, "md5")


def file_sha1(path: Path) -> str:
    return file_digest(path, "sha1")


def file_sha256(path: Path) -> str:
    return file_digest(path, "sha256")


def file_digest(path: Path, algorithm: str) -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_pret_pokecrystal_checkout(checkout_dir: Path) -> None:
    checkout_dir.parent.mkdir(parents=True, exist_ok=True)
    if (checkout_dir / ".git").exists():
        run_command(["git", "fetch", "--quiet", "origin"], checkout_dir)
        run_command(["git", "checkout", "--quiet", "origin/master"], checkout_dir)
        return

    run_command(
        ["git", "clone", "--quiet", "--depth", "1", PRET_POKECRYSTAL_REPO, str(checkout_dir)],
        checkout_dir.parent,
    )


def build_pret_base_roms(
    repo_root: Path,
    jobs: int,
    checkout_dir: Path,
    fixture_dir: Path,
) -> list[tuple[str, Path]]:
    ensure_pret_pokecrystal_checkout(checkout_dir)
    fixture_dir.mkdir(parents=True, exist_ok=True)

    job_flag = f"-j{jobs}" if jobs > 0 else "-j"
    run_command(["make", job_flag, *[base.make_goal for base in PRET_BASE_ROMS]], checkout_dir)

    base_roms: list[tuple[str, Path]] = []
    for base in PRET_BASE_ROMS:
        built_rom = checkout_dir / base.rom_name
        fixture_rom = fixture_dir / base.fixture_name
        if not built_rom.exists():
            raise FileNotFoundError(f"Expected pret/pokecrystal ROM missing: {built_rom}")

        shutil.copy2(built_rom, fixture_rom)
        actual_md5 = file_md5(fixture_rom)
        actual_sha1 = file_sha1(fixture_rom)
        if actual_md5 != base.md5:
            raise ValueError(
                f"{base.label} MD5 mismatch: expected {base.md5}, got {actual_md5}"
            )
        if actual_sha1 != base.sha1:
            raise ValueError(
                f"{base.label} SHA1 mismatch: expected {base.sha1}, got {actual_sha1}"
            )

        print(f"Prepared {fixture_rom.relative_to(repo_root)} ({base.label})")
        base_roms.append((base.label, fixture_rom))

    return base_roms


def bps_encode_number(value: int) -> bytes:
    if value < 0:
        raise ValueError("BPS numbers cannot be negative")

    encoded = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value == 0:
            encoded.append(byte | 0x80)
            break
        encoded.append(byte)
        value -= 1
    return bytes(encoded)


def bps_action(action: int, length: int) -> bytes:
    if length <= 0:
        raise ValueError("BPS action length must be positive")
    return bps_encode_number(((length - 1) << 2) | action)


def make_bps_patch(source: bytes, target: bytes, metadata: bytes = b"") -> bytes:
    patch = bytearray(b"BPS1")
    patch += bps_encode_number(len(source))
    patch += bps_encode_number(len(target))
    patch += bps_encode_number(len(metadata))
    patch += metadata

    offset = 0
    while offset < len(target):
        if offset < len(source) and source[offset] == target[offset]:
            start = offset
            limit = min(len(source), len(target))
            while offset < limit and source[offset] == target[offset]:
                offset += 1
            patch += bps_action(0, offset - start)
            continue

        start = offset
        while offset < len(target):
            if offset < len(source) and source[offset] == target[offset]:
                break
            offset += 1
        patch += bps_action(1, offset - start)
        patch += target[start:offset]

    patch += zlib.crc32(source).to_bytes(4, "little")
    patch += zlib.crc32(target).to_bytes(4, "little")
    patch += zlib.crc32(patch).to_bytes(4, "little")
    return bytes(patch)


def make_ips_patch(source: bytes, target: bytes) -> bytes:
    patch = bytearray(b"PATCH")
    limit = len(target)
    offset = 0

    while offset < limit:
        source_byte = source[offset] if offset < len(source) else None
        if source_byte == target[offset]:
            offset += 1
            continue

        start = offset
        data = bytearray()
        while offset < limit and len(data) < 0xFFFF:
            source_byte = source[offset] if offset < len(source) else None
            if source_byte == target[offset]:
                break
            data.append(target[offset])
            offset += 1

        if start > 0xFFFFFF:
            raise ValueError("IPS cannot encode offsets above 0xFFFFFF")
        patch += start.to_bytes(3, "big")
        patch += len(data).to_bytes(2, "big")
        patch += data

    patch += b"EOF"
    if len(target) < len(source):
        patch += len(target).to_bytes(3, "big")
    return bytes(patch)


def bps_decode_number(data: bytes, position: int) -> tuple[int, int]:
    value = 0
    shift = 1
    while True:
        byte = data[position]
        position += 1
        value += (byte & 0x7F) * shift
        if byte & 0x80:
            return value, position
        shift <<= 7
        value += shift


def apply_bps_patch(source: bytes, patch: bytes) -> bytes:
    if patch[:4] != b"BPS1":
        raise ValueError("Not a BPS patch")
    if zlib.crc32(patch[:-4]) != int.from_bytes(patch[-4:], "little"):
        raise ValueError("BPS patch CRC does not match")

    source_size, position = bps_decode_number(patch, 4)
    target_size, position = bps_decode_number(patch, position)
    metadata_size, position = bps_decode_number(patch, position)
    position += metadata_size

    if source_size != len(source):
        raise ValueError("BPS source size does not match")
    if zlib.crc32(source) != int.from_bytes(patch[-12:-8], "little"):
        raise ValueError("BPS source CRC does not match")

    target = bytearray()
    end = len(patch) - 12
    while position < end:
        command, position = bps_decode_number(patch, position)
        action = command & 3
        length = (command >> 2) + 1

        if action == 0:
            start = len(target)
            target += source[start : start + length]
        elif action == 1:
            target += patch[position : position + length]
            position += length
        else:
            raise ValueError("This verifier only expects SourceRead and TargetRead actions")

    if len(target) != target_size:
        raise ValueError("BPS target size does not match")
    if zlib.crc32(target) != int.from_bytes(patch[-8:-4], "little"):
        raise ValueError("BPS target CRC does not match")
    return bytes(target)


def apply_ips_patch(source: bytes, patch: bytes) -> bytes:
    if patch[:5] != b"PATCH":
        raise ValueError("Not an IPS patch")

    target = bytearray(source)
    position = 5
    truncate_to: int | None = None
    while True:
        marker = patch[position : position + 3]
        position += 3
        if marker == b"EOF":
            if position + 3 == len(patch):
                truncate_to = int.from_bytes(patch[position : position + 3], "big")
            break

        offset = int.from_bytes(marker, "big")
        size = int.from_bytes(patch[position : position + 2], "big")
        position += 2
        if size == 0:
            size = int.from_bytes(patch[position : position + 2], "big")
            value = patch[position + 2]
            position += 3
            data = bytes([value]) * size
        else:
            data = patch[position : position + size]
            position += size

        required_size = offset + len(data)
        if required_size > len(target):
            target.extend(b"\x00" * (required_size - len(target)))
        target[offset:required_size] = data

    if truncate_to is not None:
        del target[truncate_to:]
    return bytes(target)


def write_rom_patches(base_rom: Path, target_rom: Path, patch_name: str) -> list[Path]:
    source = base_rom.read_bytes()
    target = target_rom.read_bytes()

    metadata = (
        f"Sourced from {base_rom.name}; generated by "
        "utils/build_safari_release_artifacts.py"
    ).encode("utf-8")
    bps_patch = make_bps_patch(source, target, metadata)
    ips_patch = make_ips_patch(source, target)

    bps_path = target_rom.with_name(f"{patch_name}.bps")
    ips_path = target_rom.with_name(f"{patch_name}.ips")
    bps_path.write_bytes(bps_patch)
    ips_path.write_bytes(ips_patch)

    if apply_bps_patch(source, bps_patch) != target:
        raise ValueError(f"Generated BPS patch did not reproduce {patch_name}")
    if apply_ips_patch(source, ips_patch) != target:
        raise ValueError(f"Generated IPS patch did not reproduce {patch_name}")

    return [bps_path, ips_path]


def write_checksums(build_dir: Path, paths: list[Path]) -> list[Path]:
    unique_paths = sorted({path.resolve() for path in paths})
    checksum_paths: list[Path] = []
    for algorithm, filename in (("md5", "MD5SUMS"), ("sha256", "SHA256SUMS")):
        checksum_path = build_dir / filename
        with checksum_path.open("w", encoding="utf-8") as file:
            for path in unique_paths:
                if path.exists():
                    file.write(f"{file_digest(path, algorithm)}  {path.name}\n")
        checksum_paths.append(checksum_path)
    return checksum_paths


def main() -> None:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    version = args.version

    jobs = args.jobs or (os.cpu_count() or 1)
    build_dir = (args.build_dir or repo_root / "build").resolve()
    build_dir.mkdir(parents=True, exist_ok=True)

    base_roms: list[tuple[str | None, Path]] = []
    base_rom = args.base_rom.resolve() if args.base_rom else None
    if base_rom:
        if not base_rom.exists():
            print(f"Base ROM does not exist: {base_rom}", file=sys.stderr)
            sys.exit(1)
        if not args.skip_base_md5_check:
            actual_md5 = file_md5(base_rom)
            if actual_md5 != args.expected_base_md5:
                print(
                    f"Base ROM MD5 mismatch: expected {args.expected_base_md5}, got {actual_md5}",
                    file=sys.stderr,
                )
                sys.exit(1)
        base_roms.append((None, base_rom))

    if args.build_pret_base_roms:
        pret_checkout_dir = (
            args.pret_pokecrystal_dir or repo_root / "tmp" / "release-base-roms" / "pokecrystal"
        ).resolve()
        base_fixture_dir = (args.base_fixture_dir or repo_root / "tmp" / "rom-fixtures").resolve()
        try:
            base_roms.extend(
                build_pret_base_roms(repo_root, jobs, pret_checkout_dir, base_fixture_dir)
            )
        except (subprocess.CalledProcessError, FileNotFoundError, ValueError) as error:
            print(error, file=sys.stderr)
            sys.exit(1)

    source_prefix = f"polishedcrystal-{version}"
    dest_prefix = f"{args.prefix}-{version}"
    generated_paths: list[Path] = []

    try:
        print(f"Building {dest_prefix}")
        run_make(repo_root, version, jobs, [])
        rom_path = move_artifact(
            repo_root,
            build_dir,
            f"{source_prefix}.gbc",
            f"{dest_prefix}.gbc",
        )
        generated_paths.append(rom_path)
        move_artifact(
            repo_root,
            build_dir,
            f"{source_prefix}.sym",
            f"{dest_prefix}.sym",
        )

        if base_roms:
            for base_label, patch_base_rom in base_roms:
                patch_name = dest_prefix if base_label is None else f"{dest_prefix}-{base_label}"
                for patch_path in write_rom_patches(patch_base_rom, rom_path, patch_name):
                    generated_paths.append(patch_path)
                    print(f"Wrote {patch_path.relative_to(repo_root)}")
        else:
            print("Skipping .bps/.ips patches; pass --base-rom or --build-pret-base-roms.")

        for checksum_path in write_checksums(build_dir, generated_paths):
            print(f"Wrote {checksum_path.relative_to(repo_root)}")

        run_make(repo_root, version, jobs, ["tidy"])

        if not args.no_vc_patch:
            print(f"Building {dest_prefix} 3DS Virtual Console patch")
            run_make(repo_root, version, jobs, ["vc"])
            vc_patch_path = move_artifact(
                repo_root,
                build_dir,
                f"{source_prefix}.patch",
                f"{dest_prefix}.3ds-vc.patch",
            )
            generated_paths.append(vc_patch_path)
            for checksum_path in write_checksums(build_dir, generated_paths):
                print(f"Wrote {checksum_path.relative_to(repo_root)}")
            run_make(repo_root, version, jobs, ["tidy"])
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)

    print(f"All artifacts ready in {build_dir}")


if __name__ == "__main__":
    main()
