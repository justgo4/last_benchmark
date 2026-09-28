#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/gambit"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
gsc -exe -cc-options "-O3 -march=native -flto -ffp-contract=off"   -ld-options "-flto" -o "$out/final/bench" "$root/languages/gambit/main.scm"
