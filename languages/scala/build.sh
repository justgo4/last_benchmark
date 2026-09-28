#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/scala"
rm -rf "$out"
mkdir -p "$out/intermediate" "$out/final"
scala-cli package "$root/languages/scala/Bench.scala"   --server=false --assembly --power --force   --main-class Bench   -o "$out/final/bench.jar"
cp "$root/languages/scala/Bench.scala" "$out/intermediate/Bench.scala"
