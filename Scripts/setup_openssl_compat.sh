#!/bin/zsh
# Symlinks openssl@3 dylibs as openssl@1.1 names so older miners (like
# Mr-Bossman ccminer) can find the libs they expect. ABI between 3.x and
# 1.1.x isn't fully compatible, but for the simple crypto primitives most
# CPU miners use it works in practice.
#
# Run this once after installing a miner that fails with:
#   "Library not loaded: /opt/homebrew/opt/openssl@1.1/lib/libcrypto.1.1.dylib"

set -euo pipefail

OPENSSL3="/opt/homebrew/opt/openssl@3/lib"
OPENSSL11="/opt/homebrew/opt/openssl@1.1/lib"

if [[ ! -d "$OPENSSL3" ]]; then
    echo "openssl@3 not found at $OPENSSL3 — install with: brew install openssl@3" >&2
    exit 1
fi

mkdir -p "$OPENSSL11"
ln -sf "$OPENSSL3/libcrypto.dylib" "$OPENSSL11/libcrypto.1.1.dylib"
ln -sf "$OPENSSL3/libssl.dylib" "$OPENSSL11/libssl.1.1.dylib"

echo "==> Done. openssl@3 dylibs aliased as 1.1 names in $OPENSSL11"
ls -la "$OPENSSL11"
