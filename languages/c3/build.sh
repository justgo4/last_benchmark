#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/c3"
rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
c3c -O3 --emit-llvm --llvm-out "$out/intermediate" --obj-out "$out/intermediate" -o "$out/final/bench" compile "$root/languages/c3/main.c3"
