#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/scala"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
scalac -deprecation -feature -d "$out/intermediate" "$root/languages/scala/Bench.scala"
jar --create --file "$out/final/bench.jar" --main-class Bench -C "$out/intermediate" .
