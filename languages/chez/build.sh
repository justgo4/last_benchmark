#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/chez"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
cp "$root/languages/chez/main.ss" "$out/intermediate/main.ss"
printf '(compile-program "%s" "%s")\n(exit)\n'   "$out/intermediate/main.ss" "$out/final/bench.so" | scheme -q
