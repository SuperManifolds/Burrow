#!/bin/bash
# Builds the gotatun binary for local development.
# Called by Xcode's "Build GotaTun" run script phase.
# Skipped if the binary already exists or Cargo is not installed.

set -euo pipefail

OUTPUT="$SRCROOT/Burrow/Resources/gotatun"

if [ -f "$OUTPUT" ]; then
    echo "gotatun binary already exists, skipping build"
    exit 0
fi

if ! command -v cargo &>/dev/null; then
    echo "warning: Cargo not installed — skipping gotatun build. Performance mode will not work."
    echo "Install Rust via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 0
fi

echo "Building gotatun-cli..."
mkdir -p "$(dirname "$OUTPUT")"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cargo install gotatun-cli@0.1.0 \
    --root "$TEMP_DIR" \
    --target aarch64-apple-darwin

cp "$TEMP_DIR/bin/gotatun-cli" "$OUTPUT"
chmod +x "$OUTPUT"
echo "gotatun binary built at $OUTPUT"
