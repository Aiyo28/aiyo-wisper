#!/bin/bash
# Generate Sparkle appcast.xml from DMG artifacts in build/
# Requires: Sparkle's generate_appcast tool
# Usage: ./scripts/generate-appcast.sh [--download-url-prefix=URL]
#
# EdDSA private key is read from:
#   1. SPARKLE_KEY env var (CI — set from GitHub Secret)
#   2. Keychain (local — stored by generate_keys)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
DOWNLOAD_URL_PREFIX=""

for arg in "$@"; do
    case "$arg" in
        --download-url-prefix=*) DOWNLOAD_URL_PREFIX="${arg#--download-url-prefix=}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

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

EXTRA_ARGS=()

# Pass EdDSA key from env if available (CI)
if [ -n "${SPARKLE_KEY:-}" ]; then
    EXTRA_ARGS+=(--ed-key-file <(echo -n "$SPARKLE_KEY"))
fi

if [ -n "$DOWNLOAD_URL_PREFIX" ]; then
    EXTRA_ARGS+=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
fi

"$GENERATE_APPCAST" "$BUILD_DIR" -o "${PROJECT_DIR}/appcast.xml" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}

echo "Generated: ${PROJECT_DIR}/appcast.xml"
