#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/javascript"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
cp "$root/languages/javascript/bench.mjs" "$out/final/bench.mjs"
