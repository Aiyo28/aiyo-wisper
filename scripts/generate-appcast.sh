#!/bin/bash
# Generate Sparkle appcast.xml from DMG artifacts in build/
# Requires: Sparkle's generate_appcast tool
# Usage: ./scripts/generate-appcast.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"

if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: build/ directory not found. Run build-release.sh first."
    exit 1
fi

# Find generate_appcast in common locations
GENERATE_APPCAST=""
for candidate in \
    "${HOME}/Library/Developer/Xcode/DerivedData/"*"/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    "/usr/local/bin/generate_appcast" \
    "$(which generate_appcast 2>/dev/null || true)"; do
    if [ -x "$candidate" ]; then
        GENERATE_APPCAST="$candidate"
        break
    fi
done

if [ -z "$GENERATE_APPCAST" ]; then
    echo "Error: generate_appcast not found."
    echo "Install via: brew install sparkle"
    echo "Or build Sparkle from source."
    exit 1
fi

echo "Using: $GENERATE_APPCAST"
echo "Scanning: $BUILD_DIR"

"$GENERATE_APPCAST" "$BUILD_DIR" -o "${PROJECT_DIR}/appcast.xml"

echo "Generated: ${PROJECT_DIR}/appcast.xml"
