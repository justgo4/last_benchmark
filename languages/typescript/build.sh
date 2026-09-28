#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/typescript"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
tsc --target ES2022 --module NodeNext --moduleResolution NodeNext --skipLibCheck --removeComments --outDir "$out/intermediate" "$root/languages/typescript/bench.ts"
cp "$out/intermediate/bench.js" "$out/final/bench.mjs"
