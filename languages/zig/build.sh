#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/zig"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
zig build-exe -O ReleaseFast -mcpu native -lc -femit-bin="$out/final/bench" -femit-llvm-ir="$out/intermediate/main.ll" "$root/languages/zig/main.zig"
