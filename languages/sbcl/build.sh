#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/sbcl"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
sbcl --noinform --disable-debugger --load "$root/languages/sbcl/main.lisp" --eval "(sb-ext:save-lisp-and-die \"$out/final/bench\" :toplevel #'main :executable t)" --quit
