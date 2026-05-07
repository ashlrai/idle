#!/bin/zsh
# Downloads and installs cpuminer-verus for Apple Silicon, ready for Idle to launch.
# Source: https://github.com/monkins1010/ccminer (the actively maintained ARM64 fork).
# License: GPLv3 — we don't bundle the binary inside Idle's MIT-licensed app
# bundle for that reason. This script lives in Scripts/, runs once, installs to
# ~/Library/Application Support/Idle/miner/cpuminer.

set -euo pipefail

DEST_DIR="$HOME/Library/Application Support/Idle/miner"
DEST_BIN="$DEST_DIR/cpuminer"
BUILD_DIR="$(mktemp -d)"

echo "==> Installing Verus miner for Apple Silicon"
echo "    Destination: $DEST_BIN"
mkdir -p "$DEST_DIR"

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to build cpuminer-verus. Install it from brew.sh first." >&2
    exit 1
fi

echo "==> Installing build dependencies (curl, automake, openssl)"
brew install autoconf automake libtool openssl@3 curl pkg-config 2>/dev/null || true

echo "==> Cloning cpuminer-verus"
cd "$BUILD_DIR"
git clone --depth 1 https://github.com/monkins1010/ccminer.git 2>&1 | tail -3
cd ccminer

echo "==> Building (this takes ~3 min on an M-series Mac)"
./autogen.sh >/dev/null 2>&1
./configure CFLAGS="-O3 -march=armv8-a+crypto+sha2 -mtune=native" \
    --with-crypto=$(brew --prefix openssl@3) >/dev/null 2>&1
make -j$(sysctl -n hw.ncpu) 2>&1 | tail -3

echo "==> Installing binary"
cp cpuminer "$DEST_BIN"
chmod +x "$DEST_BIN"
rm -rf "$BUILD_DIR"

echo "==> Done. Open Idle, toggle Verus mining ON in the menu bar popover."
echo "    Make sure to set your VRSC payout address in Idle Settings first."
echo
echo "Want a VRSC address? Install Verus Desktop from veruscoin.io or use"
echo "an exchange that supports VRSC (KuCoin, Bittrex)."
