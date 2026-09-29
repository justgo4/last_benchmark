#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
src="$root/languages/pyo3"
out="$root/build/pyo3"
rm -rf "$out"
mkdir -p "$out/intermediate/wheels" "$out/final"
export RUSTFLAGS="-C target-cpu=native"
(cd "$src" && maturin build --release --out "$out/intermediate/wheels")
python -m pip install --force-reinstall "$out"/intermediate/wheels/*.whl
module_path="$(python -c 'import bench_ext; print(bench_ext.__file__)')"
test -f "$module_path"
cp "$module_path" "$out/final/"
cp "$src/driver.py" "$out/final/driver.py"
