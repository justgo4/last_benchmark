#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/racket"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
raco make "$root/languages/racket/main.rkt"
cp -r "$root/languages/racket/compiled" "$out/intermediate/" 2>/dev/null || true
raco exe -o "$out/final/bench" "$root/languages/racket/main.rkt"
