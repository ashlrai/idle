#!/bin/zsh
# Downloads ccminer (Apple Silicon arm64 build by Mr-Bossman) for Verus CPU
# mining and installs it where Idle's Mining.swift expects to find it.
#
# Source: https://github.com/Mr-Bossman/ccminer (open source, derivative of
# tpruvot/ccminer, ARM64-optimized for Apple Silicon, supports VerusHash 2.2).
# Single Mach-O binary, ~3.4 MB. We don't bundle it inside Idle's MIT-licensed
# .app to keep the licensing tree clean (ccminer is GPL).

set -euo pipefail

DEST_DIR="$HOME/Library/Application Support/Idle/miner"
DEST_BIN="$DEST_DIR/cpuminer"
SOURCE_URL="https://github.com/Mr-Bossman/ccminer/releases/download/7db3a94/ccminer"

echo "==> Installing Verus miner for Apple Silicon"
echo "    Destination: $DEST_BIN"
mkdir -p "$DEST_DIR"

echo "==> Downloading ccminer (Mr-Bossman build)"
curl -fL --progress-bar -o "$DEST_BIN" "$SOURCE_URL"
chmod +x "$DEST_BIN"

# Verify the binary is the right architecture.
if file "$DEST_BIN" | grep -q "Mach-O.*arm64"; then
    echo "==> Verified: arm64 Mach-O binary"
else
    echo "==> WARNING: binary is not arm64 — check $DEST_BIN" >&2
fi

# Quick sanity check: does it accept the --help flag?
if "$DEST_BIN" --help 2>&1 | head -1 | grep -qi "ccminer\|usage"; then
    echo "==> Binary runs"
else
    echo "==> NOTE: binary may not run on your macOS version. Check Gatekeeper:"
    echo "         xattr -d com.apple.quarantine \"$DEST_BIN\""
fi

echo
echo "==> Done. Next steps:"
echo "    1. Get a VRSC payout address (Verus Desktop wallet or KuCoin/Bittrex deposit)"
echo "    2. Open Idle → set the address in Mining settings (or paste into UserDefaults:"
echo "         defaults write ai.ashlr.idle idle.mining.address -string 'YOUR_VRSC_ADDR')"
echo "    3. Click 'Start' on the Verus mining row in the Idle popover"
echo
echo "Pool: stratum+tcp://na.luckpool.net:3956 (default in Idle)"
echo "Estimated income on M-series Air at 24/7 plug-in: \$30-90 / month"
