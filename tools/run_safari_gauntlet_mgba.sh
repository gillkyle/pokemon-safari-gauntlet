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

if [[ "${1:-}" == "--fresh" ]]; then
	rm -rf "$run_dir"
fi

mkdir -p "$run_dir"
cp "$rom" "$run_rom"

pkill -x mGBA 2>/dev/null || true
sleep 1

for _ in 1 2 3 4 5; do
	if open -a /Applications/mGBA.app --args \
		-C mute=1 \
		-C volume=0 \
		-C audioSync=1 \
		-C videoSync=1 \
		-C fpsTarget=60 \
		-C forceFastForward=0; then
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
