#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; exec "$root/build/haskell/final/bench" "$1" +RTS -N1 -RTS
