#!/bin/bash
set -e

# ==============================================================================
# Clipboard Library - Release Build & DMG Packaging Script
# ==============================================================================
# Usage:
#   ./scripts/build_release.sh
#
# Optional Environment Variables:
#   SIGNING_IDENTITY : Apple Developer / Developer ID certificate name
#                      Default: "-" (Ad-hoc signing with Hardened Runtime)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SCHEME="ClipboardLibrary"
CONFIGURATION="Release"
APP_NAME="ClipboardLibrary"
DISPLAY_NAME="Clipboard Library"
BUNDLE_ID="com.praveen.ClipboardLibrary"

BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${PROJECT_ROOT}/dist"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
RELEASE_APP="${BUILD_DIR}/Release/${APP_NAME}.app"
DMG_STAGE_DIR="${BUILD_DIR}/dmg_staging"
DMG_OUTPUT="${DIST_DIR}/${APP_NAME}.dmg"
ZIP_OUTPUT="${DIST_DIR}/${APP_NAME}.zip"

SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

echo "=================================================="
echo "🚀 Building ${DISPLAY_NAME} (Release v1.0.0)"
echo "=================================================="
echo "Project Root:      ${PROJECT_ROOT}"
echo "Signing Identity:  ${SIGNING_IDENTITY}"
echo "Hardened Runtime:  Enabled"
echo "Output Directory:  ${DIST_DIR}"
echo ""

# 1. Clean output directories
rm -rf "${BUILD_DIR}"
rm -rf "${DIST_DIR}"
mkdir -p "${BUILD_DIR}/Release"
mkdir -p "${DIST_DIR}"

# 2. Archive using xcodebuild
echo "📦 Step 1: Archiving with Xcode..."
xcodebuild archive \
    -project "${PROJECT_ROOT}/${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
    CODE_SIGN_STYLE="Manual" \
    | xcbeautify 2>/dev/null || true

if [ ! -d "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" ]; then
    echo "⚠️ Archive output not found at standard path. Falling back to Release build..."
    xcodebuild build \
        -project "${PROJECT_ROOT}/${APP_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
        CODE_SIGN_STYLE="Manual"
    cp -R "${BUILD_DIR}/DerivedData/Build/Products/Release/${APP_NAME}.app" "${RELEASE_APP}"
else
    echo "✅ Archive succeeded."
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${RELEASE_APP}"
fi

# 3. Verify / Re-sign with Hardened Runtime and Entitlements
echo ""
echo "🔒 Step 2: Verifying Code Signing & Hardened Runtime..."
ENTITLEMENTS="${PROJECT_ROOT}/ClipboardLibrary/ClipboardLibrary.entitlements"

if [ "${SIGNING_IDENTITY}" != "-" ]; then
    codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS}" --sign "${SIGNING_IDENTITY}" --timestamp "${RELEASE_APP}"
else
    codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS}" --sign - "${RELEASE_APP}"
fi

codesign -dvvv "${RELEASE_APP}"

# 4. Prepare DMG Staging
echo ""
echo "💿 Step 3: Preparing DMG layout..."
rm -rf "${DMG_STAGE_DIR}"
mkdir -p "${DMG_STAGE_DIR}"

cp -R "${RELEASE_APP}" "${DMG_STAGE_DIR}/"
# Symlink to /Applications for easy drag-and-drop
ln -s /Applications "${DMG_STAGE_DIR}/Applications"

# 5. Create DMG with hdiutil
echo ""
echo "💿 Step 4: Creating DMG disk image..."
rm -f "${DMG_OUTPUT}"
hdiutil create \
    -volname "${DISPLAY_NAME}" \
    -srcfolder "${DMG_STAGE_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_OUTPUT}"

echo "✅ DMG created: ${DMG_OUTPUT}"

# 6. Create Zip archive as alternate distribution
echo ""
echo "🗜️ Step 5: Creating Zip package..."
(cd "${BUILD_DIR}/Release" && zip -r -q -y "${ZIP_OUTPUT}" "${APP_NAME}.app")
echo "✅ Zip created: ${ZIP_OUTPUT}"

# 7. Verification
echo ""
echo "🔎 Step 6: Verifying DMG image..."
hdiutil verify "${DMG_OUTPUT}"

echo ""
echo "=================================================="
echo "🎉 Release Build Complete!"
echo "=================================================="
echo "Application: ${RELEASE_APP}"
echo "DMG Image:   ${DMG_OUTPUT}"
echo "Zip Package: ${ZIP_OUTPUT}"
echo "=================================================="
