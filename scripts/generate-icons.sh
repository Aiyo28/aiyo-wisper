#!/bin/bash
set -euo pipefail

# Generate all macOS app icon sizes from a master 1024x1024 PNG
# Usage: ./generate-icons.sh path/to/master-icon.png

MASTER="${1:-}"
if [[ -z "$MASTER" ]]; then
    echo "Usage: $0 <path-to-1024x1024-png>"
    exit 1
fi

if [[ ! -f "$MASTER" ]]; then
    echo "Error: File not found: $MASTER"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_DIR="$SCRIPT_DIR/../AiyoWisper/Assets.xcassets/AppIcon.appiconset"

if [[ ! -d "$ICON_DIR" ]]; then
    echo "Error: AppIcon.appiconset directory not found at $ICON_DIR"
    exit 1
fi

# All required pixel sizes for macOS icons (1x and 2x for 16, 32, 128, 256, 512pt)
SIZES=(16 32 64 128 256 512 1024)

echo "Generating macOS app icons from: $MASTER"

for SIZE in "${SIZES[@]}"; do
    OUTPUT="$ICON_DIR/icon_${SIZE}x${SIZE}.png"
    echo "  ${SIZE}x${SIZE} -> $(basename "$OUTPUT")"
    sips -z "$SIZE" "$SIZE" "$MASTER" --out "$OUTPUT" >/dev/null 2>&1
done

echo "Done! Generated ${#SIZES[@]} icon sizes in $(basename "$ICON_DIR")/"
