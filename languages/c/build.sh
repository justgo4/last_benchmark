#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/c"
rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
gcc -O3 -march=native -flto -DNDEBUG -ffp-contract=off -std=c11 -c "$root/benchmarks/v2/c/main.c" -o "$out/intermediate/main.o"
gcc -O3 -march=native -flto -DNDEBUG -ffp-contract=off "$out/intermediate/main.o" -o "$out/final/bench"
