#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/go"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
go build -trimpath -ldflags="-s -w" -o "$out/final/bench" "$root/languages/go/main.go"
