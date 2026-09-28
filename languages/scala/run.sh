#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"; exec scala -classpath "$root/build/scala/final/bench.jar" Bench "$1"
