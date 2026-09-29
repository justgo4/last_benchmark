#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
src="$root/languages/pyo3"
out="$root/build/pyo3"
rm -rf "$out"
mkdir -p "$out/intermediate/wheels" "$out/final"
export RUSTFLAGS="-C target-cpu=native"
(cd "$src" && maturin build --release --out "$out/intermediate/wheels")
python - "$out/intermediate/wheels" "$out/final" <<'PY'
import pathlib, sys, zipfile
wheel_dir = pathlib.Path(sys.argv[1])
final = pathlib.Path(sys.argv[2])
wheel = next(wheel_dir.glob("*.whl"))
with zipfile.ZipFile(wheel) as zf:
    modules = [n for n in zf.namelist() if n.endswith((".so", ".pyd"))]
    if not modules:
        raise SystemExit("no extension module found in PyO3 wheel")
    for name in modules:
        (final / pathlib.Path(name).name).write_bytes(zf.read(name))
PY
cp "$src/driver.py" "$out/final/driver.py"
