#!/bin/bash
set -euo pipefail

# Build, sign, package, and notarize AiyoWisper for distribution
# Usage: ./build-release.sh [--skip-notarize] [--version=X.Y.Z]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="AiyoWisper"
APP_NAME="AiyoWisper"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"
NOTARIZE_PROFILE="AiyoWisper"

SKIP_NOTARIZE=false
VERSION=""

for arg in "$@"; do
    case "$arg" in
        --skip-notarize) SKIP_NOTARIZE=true ;;
        --version=*) VERSION="${arg#--version=}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Also honor SKIP_NOTARIZE env var
if [[ "${SKIP_NOTARIZE:-}" == "1" ]]; then
    SKIP_NOTARIZE=true
fi

ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

# --- Helpers ---

step() {
    echo ""
    echo "==> $1"
    echo "$(printf '%.0s-' {1..60})"
}

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- Step 0: Check prerequisites ---

check_prerequisites() {
    step "Checking prerequisites"

    if ! command -v xcodebuild &>/dev/null; then
        fail "xcodebuild not found. Install Xcode."
    fi

    if [[ "$SKIP_NOTARIZE" == false ]]; then
        if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
            echo ""
            echo "WARNING: No 'Developer ID Application' certificate found."
            echo ""
            echo "To set up for notarized distribution:"
            echo "  1. Enroll in Apple Developer Program (\$99/year)"
            echo "     https://developer.apple.com/programs/"
            echo "  2. Create a Developer ID Application certificate:"
            echo "     Xcode -> Settings -> Accounts -> Manage Certificates -> '+'"
            echo "  3. Store notarization credentials:"
            echo "     xcrun notarytool store-credentials \"$NOTARIZE_PROFILE\" \\"
            echo "       --apple-id \"your@email.com\" --team-id \"8QWT6Z76LH\" \\"
            echo "       --password \"app-specific-password\""
            echo ""
            echo "Or run with --skip-notarize to build an unsigned DMG."
            exit 1
        fi
        echo "Developer ID Application certificate found."
    else
        echo "Skipping notarization (--skip-notarize or SKIP_NOTARIZE=1)."
    fi
}

# --- Step 1: Clean ---

step_clean() {
    step "Cleaning build directory"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    echo "Clean."
}

# --- Step 2: Archive ---

step_archive() {
    step "Archiving $SCHEME (Release)"

    local sign_args=()
    if [[ "$SKIP_NOTARIZE" == false ]]; then
        sign_args=(
            CODE_SIGN_IDENTITY="Developer ID Application"
            CODE_SIGN_STYLE=Manual
            PROVISIONING_PROFILE_SPECIFIER=""
        )
    else
        sign_args=(
            CODE_SIGN_IDENTITY="-"
            CODE_SIGN_STYLE=Automatic
        )
    fi

    xcodebuild archive \
        -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "platform=macOS,arch=arm64" \
        -archivePath "$ARCHIVE_PATH" \
        ${sign_args[@]+"${sign_args[@]}"} \
        DEVELOPMENT_TEAM="8QWT6Z76LH" \
        | tail -5

    if [[ ! -d "$ARCHIVE_PATH" ]]; then
        fail "Archive not created at $ARCHIVE_PATH"
    fi
    echo "Archive created."
}

# --- Step 3: Export ---

step_export() {
    step "Exporting archive"

    if [[ "$SKIP_NOTARIZE" == false ]]; then
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_DIR" \
            -exportOptionsPlist "$EXPORT_OPTIONS" \
            | tail -5
    else
        # For unsigned builds, just copy the app from the archive
        mkdir -p "$EXPORT_DIR"
        cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/"
    fi

    local app_path="$EXPORT_DIR/$APP_NAME.app"
    if [[ ! -d "$app_path" ]]; then
        fail "Exported app not found at $app_path"
    fi

    if [[ "$SKIP_NOTARIZE" == false ]]; then
        echo "Verifying code signature..."
        codesign --verify --deep --strict "$app_path"
        echo "Code signature valid."
    fi

    echo "Export complete."
}

# --- Step 4: Create DMG ---

step_create_dmg() {
    step "Creating DMG"

    # Determine version
    if [[ -z "$VERSION" ]]; then
        VERSION=$(defaults read "$EXPORT_DIR/$APP_NAME.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
    fi

    local dmg_name="${APP_NAME}-${VERSION}.dmg"
    local dmg_path="$BUILD_DIR/$dmg_name"

    if command -v create-dmg &>/dev/null; then
        echo "Using create-dmg for polished layout..."
        create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 190 \
            --app-drop-link 450 190 \
            --no-internet-enable \
            "$dmg_path" \
            "$EXPORT_DIR/$APP_NAME.app" \
            || true  # create-dmg returns non-zero if it can't set background, which is fine
    else
        echo "create-dmg not found, using hdiutil (install with: brew install create-dmg)"

        local staging="$BUILD_DIR/dmg-staging"
        rm -rf "$staging"
        mkdir -p "$staging"
        cp -R "$EXPORT_DIR/$APP_NAME.app" "$staging/"
        ln -s /Applications "$staging/Applications"

        hdiutil create \
            -volname "$APP_NAME" \
            -srcfolder "$staging" \
            -ov \
            -format UDZO \
            "$dmg_path"

        rm -rf "$staging"
    fi

    if [[ ! -f "$dmg_path" ]]; then
        fail "DMG not created at $dmg_path"
    fi

    echo "DMG created: $dmg_path"
}

# --- Step 5: Notarize ---

step_notarize() {
    if [[ "$SKIP_NOTARIZE" == true ]]; then
        echo ""
        echo "Skipping notarization."
        return
    fi

    step "Notarizing DMG"

    if [[ -z "$VERSION" ]]; then
        VERSION=$(defaults read "$EXPORT_DIR/$APP_NAME.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
    fi

    local dmg_name="${APP_NAME}-${VERSION}.dmg"
    local dmg_path="$BUILD_DIR/$dmg_name"

    echo "Submitting to Apple notary service..."
    xcrun notarytool submit "$dmg_path" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$dmg_path"

    echo "Notarization complete."
}

# --- Run all steps ---

check_prerequisites
step_clean
step_archive
step_export
step_create_dmg
step_notarize

step "Done!"
if [[ -z "$VERSION" ]]; then
    VERSION=$(defaults read "$EXPORT_DIR/$APP_NAME.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
fi
echo "Release artifact: $BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
