#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y   curl ca-certificates software-properties-common build-essential   flex bison libgmp-dev libmpfr-dev libmpc-dev texinfo xz-utils

version="$(
  curl -fsSL https://gcc.gnu.org/releases.html |
  python3 -c '
import re,sys
text=sys.stdin.read()
vs={tuple(map(int,m)) for m in re.findall(r"GCC ([0-9]+)\.([0-9]+)\.([0-9]+)", text)}
if not vs:
    raise SystemExit("could not resolve stable GCC release")
print(".".join(map(str,max(vs))))
'
)"
major="${version%%.*}"
echo "official latest stable GCC=$version"

# Prefer the distro/PPA binary only if its reported release is exactly the
# official stable version. A development/trunk gcc-$major must never qualify.
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update
if sudo apt-get install -y "gcc-$major" "g++-$major"; then
  candidate="$(gcc-$major -dumpfullversion)"
  if [[ "$candidate" == "$version" ]]; then
    bindir="$HOME/.local/last-benchmark-gcc"
    mkdir -p "$bindir"
    ln -sf "$(command -v "gcc-$major")" "$bindir/gcc"
    ln -sf "$(command -v "g++-$major")" "$bindir/g++"
    echo "$bindir" >> "$GITHUB_PATH"
    echo "using packaged stable GCC $candidate"
    exit 0
  fi
  echo "packaged gcc-$major reports $candidate, not official stable $version; building official source"
fi

prefix="$HOME/.local/gcc-$version"
src="/tmp/gcc-$version"
build="/tmp/gcc-build-$version"
curl -fsSL "https://ftp.gnu.org/gnu/gcc/gcc-$version/gcc-$version.tar.xz" -o /tmp/gcc.tar.xz
rm -rf "$src" "$build"
mkdir -p "$src" "$build"
tar -xJf /tmp/gcc.tar.xz --strip-components=1 -C "$src"

(
  cd "$build"
  "$src/configure"     --prefix="$prefix"     --disable-bootstrap     --disable-multilib     --enable-languages=c,c++     --enable-checking=release
  make -j"$(nproc)"
  make install
)

test "$("$prefix/bin/gcc" -dumpfullversion)" = "$version"
echo "$prefix/bin" >> "$GITHUB_PATH"
echo "built official stable GCC $version"
