#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rom="$repo_dir/polishedcrystal-3.2.3.gbc"

if [[ ! -f "$rom" ]]; then
	echo "Missing ROM: $rom" >&2
	echo "Run make first." >&2
	exit 1
fi

hash="$(shasum -a 256 "$rom" | awk '{print substr($1, 1, 12)}')"
run_dir="/tmp/mgba-safari-gauntlet-$hash"
run_rom="$run_dir/PKPCRYSTAL-$hash.gbc"

fresh=0
fast=0
for arg in "$@"; do
	case "$arg" in
		--fresh)
			fresh=1
			;;
		--fast)
			fast=1
			;;
		*)
			echo "usage: $0 [--fresh] [--fast]" >&2
			exit 2
			;;
	esac
done

if [[ "$fresh" == 1 ]]; then
	rm -rf "$run_dir"
fi

mkdir -p "$run_dir"
cp "$rom" "$run_rom"

pkill -x mGBA 2>/dev/null || true
sleep 1

force_fast_forward=0
fps_target=60
if [[ "$fast" == 1 ]]; then
	force_fast_forward=1
	fps_target=600
fi

for _ in 1 2 3 4 5; do
	if open -a /Applications/mGBA.app --args \
		-C mute=1 \
		-C volume=0 \
		-C audioSync=1 \
		-C videoSync=0 \
		-C fpsTarget="$fps_target" \
		-C forceFastForward="$force_fast_forward"; then
		break
	fi
	sleep 1
done

sleep 2
for _ in 1 2 3 4 5; do
	if open -a /Applications/mGBA.app "$run_rom"; then
		break
	fi
	sleep 1
done

echo "$run_rom"
