#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y curl ca-certificates software-properties-common
major="$(
  curl -fsSL https://gcc.gnu.org/releases.html |
  python3 -c 'import re,sys; vs=[tuple(map(int,x)) for x in re.findall(r"GCC ([0-9]+)\.([0-9]+)",sys.stdin.read())]; print(max(vs)[0])'
)"
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install -y "gcc-$major" "g++-$major"
bindir="$HOME/.local/last-benchmark-gcc"
mkdir -p "$bindir"
ln -sf "$(command -v "gcc-$major")" "$bindir/gcc"
ln -sf "$(command -v "g++-$major")" "$bindir/g++"
if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$bindir" >> "$GITHUB_PATH"; fi
echo "resolved stable GCC major=$major"
