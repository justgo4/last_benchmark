#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/swift"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
clang -O3 -c "$root/languages/swift/black_box.c" -o "$out/intermediate/black_box.o"
swiftc -O -whole-module-optimization -emit-object "$root/languages/swift/main.swift" -o "$out/intermediate/main.o"
swiftc -O "$out/intermediate/main.o" "$out/intermediate/black_box.o" -o "$out/final/bench"
