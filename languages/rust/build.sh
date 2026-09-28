#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; out="$root/build/rust"; rm -rf "$out"; mkdir -p "$out/intermediate" "$out/final"
rustc -C opt-level=3 -C target-cpu=native -C lto=fat -C codegen-units=1 -C panic=abort --emit=obj="$out/intermediate/main.o",link="$out/final/bench" "$root/languages/rust/main.rs"
