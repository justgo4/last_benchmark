#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/java"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
javac -g:none -d "$out/intermediate" "$root/languages/java/Bench.java"
jar --create --file "$out/final/bench.jar" --main-class Bench -C "$out/intermediate" .
