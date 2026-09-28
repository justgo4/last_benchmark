#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; exec python "$root/build/pyo3/final/driver.py" "$1"
