#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/gerbil"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
export GERBIL_PATH="$out/intermediate"
gxc -O -full-program-optimization -exe   -cc-options "-O3 -march=native -flto -ffp-contract=off"   -ld-options "-flto"   -o "$out/final/bench" "$root/languages/gerbil/main.ss"
