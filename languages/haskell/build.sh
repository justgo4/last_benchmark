#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/haskell"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
ghc -O2 -march=native -fforce-recomp -rtsopts -with-rtsopts=-A64m -outputdir "$out/intermediate" -o "$out/final/bench" "$root/languages/haskell/Main.hs"
