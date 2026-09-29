#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
case "$1" in
  integer50) size=200000000 ;;
  json_escape) size=16000000 ;;
  binary_trees) size=16 ;;
  mandelbrot) size=1600 ;;
  *) exit 64 ;;
esac
exec "$root/build/swift/final/bench" "$1" "$size" 7
