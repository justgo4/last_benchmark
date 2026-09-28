#!/usr/bin/env bash
python - <<'PY'
import Cython,sys
print("Cython",Cython.__version__,"Python",sys.version.split()[0])
PY
