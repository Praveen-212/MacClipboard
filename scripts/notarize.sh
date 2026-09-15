#!/bin/bash
set -e

# ==============================================================================
# Clipboard Library - Apple Notarization Script
# ==============================================================================
# This script automates submission to Apple's Notary Service and stapling
# the resulting notarization ticket to the DMG.
#
# PREREQUISITES:
# 1. Paid Apple Developer Program membership.
# 2. App must be signed with a valid "Developer ID Application: <Your Name> (<Team ID>)"
#    certificate with Hardened Runtime enabled (done automatically by build_release.sh).
# 3. Store your notarization credentials in macOS Keychain once via:
#
#    xcrun notarytool store-credentials "ClipboardLibrary-Profile" \
#        --apple-id "your-apple-id@example.com" \
#        --team-id "YOUR_TEAM_ID" \
#        --password "xxxx-xxxx-xxxx-xxxx"   # App-specific password from appleid.apple.com
#
# USAGE:
#    ./scripts/notarize.sh [path-to-dmg] [keychain-profile-name]
#
# Default profile name: "ClipboardLibrary-Profile"
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DMG_PATH="${1:-${PROJECT_ROOT}/dist/ClipboardLibrary.dmg}"
PROFILE_NAME="${2:-ClipboardLibrary-Profile}"

if [ ! -f "${DMG_PATH}" ]; then
    echo "❌ Error: DMG not found at ${DMG_PATH}."
    echo "Please run ./scripts/build_release.sh first."
    exit 1
fi

echo "=================================================="
echo "🍎 Submitting to Apple Notarization Service"
echo "=================================================="
echo "DMG Target:       ${DMG_PATH}"
echo "Keychain Profile: ${PROFILE_NAME}"
echo ""

# 1. Submit to Notary Service
echo "📤 Step 1: Uploading and waiting for notary decision..."
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${PROFILE_NAME}" --wait

# 2. Staple Notarization Ticket
echo ""
echo "📎 Step 2: Stapling notarization ticket to DMG..."
xcrun stapler staple "${DMG_PATH}"

# 3. Verify Notarization
echo ""
echo "🔍 Step 3: Verifying notarization with Gatekeeper assessment..."
spctl --assess -vv --type install "${DMG_PATH}"

echo ""
echo "=================================================="
echo "🎉 Notarization and Stapling Complete!"
echo "Your DMG is ready for public distribution without Gatekeeper warnings."
echo "=================================================="
