#!/usr/bin/env bash
python - <<'PY'
import sys,Cython
print("Python",sys.version.split()[0],"Cython",Cython.__version__)
PY
