#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/cython"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
cython -3 -o "$out/intermediate/bench.c" "$root/languages/cython/bench.pyx"
clang -O3 -march=native -flto -fPIC $(python3-config --includes) -c "$out/intermediate/bench.c" -o "$out/intermediate/bench.o"
suffix="$(python3-config --extension-suffix)"
clang -shared -flto "$out/intermediate/bench.o" -o "$out/final/benchmod$suffix"
cp "$root/languages/cython/driver.py" "$out/final/driver.py"
