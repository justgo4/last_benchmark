#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/mojo"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
mojo build -O 3 -o "$out/final/bench" "$root/languages/mojo/main.mojo"
