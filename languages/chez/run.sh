#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec scheme --program "$root/build/chez/final/bench.so" "$1"
