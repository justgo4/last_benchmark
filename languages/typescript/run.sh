#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; exec node --max-old-space-size=4096 "$root/build/typescript/final/bench.mjs" "$1"
