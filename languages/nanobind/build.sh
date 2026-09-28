#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; src="$root/languages/nanobind"; out="$root/build/nanobind"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
cmake -S "$src" -B "$out/intermediate" -DCMAKE_BUILD_TYPE=Release -DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$out/final"
cmake --build "$out/intermediate" --config Release -j2
cp "$src/driver.py" "$out/final/driver.py"
