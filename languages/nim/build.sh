#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/nim"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
nim c -d:release --opt:speed --mm:orc --passC:-O3 --passC:-march=native --passC:-flto --passL:-flto --nimcache:"$out/intermediate" --out:"$out/final/bench" "$root/languages/nim/main.nim"
