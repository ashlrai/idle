#!/bin/zsh
# Builds cpuminer-opt (JayDDee, actively maintained, supports current Verus
# pool protocol) from source. Use this if Mr-Bossman's pre-built ccminer
# (in install_verus.sh) is rejected by pools with "pool nonce missing" —
# that's a sign you need a miner version newer than Aug 2022.
#
# JayDDee/cpuminer-opt is GPL, so we keep it out of Idle's MIT bundle and
# build it on-demand via this script.

set -euo pipefail

DEST_DIR="$HOME/Library/Application Support/Idle/miner"
DEST_BIN="$DEST_DIR/cpuminer"
BUILD_DIR="$(mktemp -d)"

echo "==> Installing build dependencies via Homebrew"
brew install autoconf automake libtool pkg-config curl jansson openssl@3 gmp 2>/dev/null || true

echo "==> Cloning JayDDee/cpuminer-opt"
cd "$BUILD_DIR"
git clone --depth 1 https://github.com/JayDDee/cpuminer-opt.git
cd cpuminer-opt

echo "==> Building (4-6 min on Apple Silicon)"
./autogen.sh >/dev/null 2>&1
export CFLAGS="-O3 -march=armv8-a+crypto+sha2 -mtune=native"
export LDFLAGS="-L$(brew --prefix openssl@3)/lib -L$(brew --prefix curl)/lib"
export CPPFLAGS="-I$(brew --prefix openssl@3)/include -I$(brew --prefix curl)/include"
./configure --with-curl=$(brew --prefix curl) >/dev/null 2>&1
make -j$(sysctl -n hw.ncpu)

echo "==> Installing"
mkdir -p "$DEST_DIR"
cp cpuminer "$DEST_BIN"
chmod +x "$DEST_BIN"
rm -rf "$BUILD_DIR"

echo "==> Done. cpuminer-opt installed at $DEST_BIN"
echo "    Try mining with:"
echo "    $DEST_BIN -a verus -o stratum+tcp://na.luckpool.net:3956 -u <YOUR_VRSC_ADDR>.idle-mac -p d=6 -t 6"
