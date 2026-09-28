#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec java -XX:+UseParallelGC -jar "$root/build/java/final/bench.jar" "$1"
