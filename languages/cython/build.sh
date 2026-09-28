#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; src="$root/languages/cython"; out="$root/build/cython"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
(cd "$src" && python setup.py build_ext --build-temp "$out/intermediate" --build-lib "$out/final" --force)
cp "$src/driver.py" "$out/final/driver.py"
