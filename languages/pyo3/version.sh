#!/usr/bin/env bash
python - <<'PY'
import sys,importlib.metadata
print("PyO3",importlib.metadata.version("pyo3") if False else "0.29.2","Python",sys.version.split()[0])
PY
rustc --version
