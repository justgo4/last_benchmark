#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/cpp"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
g++ -x c++ -O3 -march=native -flto -DNDEBUG -ffp-contract=off -fpermissive -std=c++23 -c   "$root/benchmarks/core/c/main.c" -o "$out/intermediate/main.o"
g++ -O3 -march=native -flto -DNDEBUG -ffp-contract=off   "$out/intermediate/main.o" -o "$out/final/bench"
