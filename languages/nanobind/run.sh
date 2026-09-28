#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$root/build/nanobind/final"; exec python driver.py "$1"
