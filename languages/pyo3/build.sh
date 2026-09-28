#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; src="$root/languages/pyo3"; out="$root/build/pyo3"; rm -rf "$out"; mkdir -p "$out/intermediate/wheels" "$out/final"
export RUSTFLAGS="-C target-cpu=native"
(cd "$src" && maturin build --release --out "$out/intermediate/wheels")
python -m pip install --force-reinstall "$out"/intermediate/wheels/*.whl
python - <<'PY' "$out/final"
import bench_ext,shutil,sys,pathlib
p=pathlib.Path(bench_ext.__file__)
shutil.copy2(p,pathlib.Path(sys.argv[1])/p.name)
PY
cp "$src/driver.py" "$out/final/driver.py"
