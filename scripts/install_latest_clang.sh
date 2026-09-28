#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y curl ca-certificates lsb-release gnupg
tag="$(curl -fsSL https://api.github.com/repos/llvm/llvm-project/releases/latest | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
major="$(printf '%s' "$tag" | sed -E 's/llvmorg-([0-9]+).*/\1/')"
curl -fsSL https://apt.llvm.org/llvm.sh -o /tmp/llvm.sh
chmod +x /tmp/llvm.sh
sudo /tmp/llvm.sh "$major"
mkdir -p "$HOME/.local/last-benchmark-clang"
ln -sf "/usr/bin/clang-$major" "$HOME/.local/last-benchmark-clang/clang"
ln -sf "/usr/bin/clang++-$major" "$HOME/.local/last-benchmark-clang/clang++"
echo "$HOME/.local/last-benchmark-clang" >> "$GITHUB_PATH"
echo "resolved stable LLVM tag=$tag"
