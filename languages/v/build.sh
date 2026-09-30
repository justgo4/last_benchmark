#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/v"
rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
v -prod -cc gcc -cflags "-O3 -march=native -flto -ffp-contract=off" -o "$out/final/bench" "$root/languages/v/main.v"
