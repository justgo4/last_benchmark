#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; export PYTHONPATH="$root/build/cython/final"; exec python "$root/build/cython/final/driver.py" "$1"
