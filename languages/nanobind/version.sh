#!/usr/bin/env bash
python - <<'PY'
import nanobind,sys
print("nanobind",nanobind.__version__,"Python",sys.version.split()[0])
PY
