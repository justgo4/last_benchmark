#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/swift"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
swiftc -O -whole-module-optimization -emit-object "$root/languages/swift/main.swift" -o "$out/intermediate/main.o"
swiftc -O "$out/intermediate/main.o" -o "$out/final/bench"
