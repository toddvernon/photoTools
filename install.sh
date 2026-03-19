#!/bin/sh
#
# PhotoToolsSwift installer
# Installs binary and creates tool symlinks
#

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
BINARY="PhotoToolsSwift"
TOOLS="photocopy photorenumber photodedup photocheck photocheckexif videocheckqt"

echo "Installing PhotoToolsSwift to $PREFIX..."

# Install binary
if [ -f "$BINARY" ]; then
    sudo cp "$BINARY" "$BIN_DIR/$BINARY"
    sudo chmod 755 "$BIN_DIR/$BINARY"
    # Clear quarantine on macOS
    sudo xattr -cr "$BIN_DIR/$BINARY" 2>/dev/null
    echo "  $BIN_DIR/$BINARY"
else
    echo "Error: $BINARY binary not found"
    exit 1
fi

# Create symlinks
for tool in $TOOLS; do
    sudo ln -sf "$BIN_DIR/$BINARY" "$BIN_DIR/$tool"
    echo "  $BIN_DIR/$tool -> $BINARY"
done

echo "Done."
echo ""
echo "Press Enter to close..."
read dummy
