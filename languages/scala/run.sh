#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec java -jar "$root/build/scala/final/bench.jar" "$1"
