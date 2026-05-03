#!/bin/bash
# Build AuraBot for direct distribution (no Apple account needed)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔨 AuraBot Build Script${NC}"
echo "========================"

APP_NAME="AuraBot"
VERSION="1.0.0"
BUNDLE_ID="com.yourname.aurabot"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
RW_DMG_NAME="${APP_NAME}-${VERSION}-temp.dmg"
MEMORY_SERVICE_DIR="../../services/memory-pglite"
CUA_DRIVER_VERSION="0.1.2"
CUA_DRIVER_VENDOR_DIR="Vendor/CuaDriver"
CUA_DRIVER_ARCH="darwin-arm64"
STAGING_DIR="$(mktemp -d /tmp/aurabot-dmg.XXXXXX)"
DMG_DEVICE=""
DMG_MOUNT_POINT=""

# Check directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: Run this from apps/macos directory${NC}"
    exit 1
fi

if [ ! -f "${MEMORY_SERVICE_DIR}/package.json" ]; then
    echo -e "${RED}Error: Memory PGlite service not found at ${MEMORY_SERVICE_DIR}${NC}"
    exit 1
fi

if [ ! -d "${CUA_DRIVER_VENDOR_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/CuaDriver.app" ]; then
    echo -e "${RED}Error: AuraBot Computer Use engine not found at ${CUA_DRIVER_VENDOR_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/CuaDriver.app${NC}"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}Error: node is required on the packaging machine so it can be bundled into the app${NC}"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}Error: npm is required on the packaging machine to build the memory service${NC}"
    exit 1
fi

# Clean
echo -e "${YELLOW}🧹 Cleaning...${NC}"
rm -rf "${APP_BUNDLE}" "${APP_NAME}-${VERSION}.zip" "${DMG_NAME}" "${RW_DMG_NAME}"
swift package clean

cleanup() {
    if [ -n "${DMG_DEVICE}" ]; then
        hdiutil detach "${DMG_DEVICE}" >/dev/null 2>&1 || true
    fi
    rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

# Build memory backend
echo -e "${YELLOW}🧠 Building memory backend...${NC}"
(cd "${MEMORY_SERVICE_DIR}" && npm install && npm run build)

# Build
echo -e "${YELLOW}🔨 Building...${NC}"
swift build -c release

# Create bundle
echo -e "${YELLOW}📦 Creating app bundle...${NC}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy SwiftPM resource bundles used by Bundle.module.
find ".build/release" -maxdepth 1 -name "*.bundle" -exec cp -R {} "${APP_BUNDLE}/Contents/Resources/" \;

# Bundle the Memory PGlite service and a node executable for normal app launches.
MEMORY_BUNDLE_DIR="${APP_BUNDLE}/Contents/Resources/MemoryPglite"
mkdir -p "${MEMORY_BUNDLE_DIR}/node/bin"
cp -R "${MEMORY_SERVICE_DIR}/dist" "${MEMORY_BUNDLE_DIR}/"
cp -R "${MEMORY_SERVICE_DIR}/node_modules" "${MEMORY_BUNDLE_DIR}/"
cp "${MEMORY_SERVICE_DIR}/package.json" "${MEMORY_BUNDLE_DIR}/"
cp "${MEMORY_SERVICE_DIR}/package-lock.json" "${MEMORY_BUNDLE_DIR}/"
if [ -d "${MEMORY_SERVICE_DIR}/templates" ]; then
    cp -R "${MEMORY_SERVICE_DIR}/templates" "${MEMORY_BUNDLE_DIR}/"
fi
cp "$(command -v node)" "${MEMORY_BUNDLE_DIR}/node/bin/node"
chmod +x "${MEMORY_BUNDLE_DIR}/node/bin/node"

# Bundle the reviewed computer-use engine under AuraBot resources. AuraBot
# copies this helper into Application Support on first launch so users interact
# with only AuraBot while still getting stable macOS privacy attribution.
COMPUTER_USE_BUNDLE_DIR="${APP_BUNDLE}/Contents/Resources/CuaDriver"
mkdir -p "${COMPUTER_USE_BUNDLE_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}"
cp "${CUA_DRIVER_VENDOR_DIR}/manifest.json" "${COMPUTER_USE_BUNDLE_DIR}/manifest.json"
cp -R \
  "${CUA_DRIVER_VENDOR_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/CuaDriver.app" \
  "${COMPUTER_USE_BUNDLE_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/"
if [ -f "${CUA_DRIVER_VENDOR_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/cua-driver-0.1.2-darwin-arm64.tar.gz" ]; then
    cp \
      "${CUA_DRIVER_VENDOR_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/cua-driver-0.1.2-darwin-arm64.tar.gz" \
      "${COMPUTER_USE_BUNDLE_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/"
fi

# Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024</string>
</dict>
</plist>
EOF

echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Ad-hoc sign the bundle so the copied app remains launchable after drag install.
echo -e "${YELLOW}🔏 Signing app bundle...${NC}"
codesign --force --deep --sign - "${COMPUTER_USE_BUNDLE_DIR}/${CUA_DRIVER_VERSION}/${CUA_DRIVER_ARCH}/CuaDriver.app"
codesign --force --deep --sign - --entitlements AuraBot.entitlements "${APP_BUNDLE}"

# Zip it
echo -e "${YELLOW}📦 Creating zip...${NC}"
zip -qr "${APP_NAME}-${VERSION}.zip" "${APP_BUNDLE}"

# DMG staging
echo -e "${YELLOW}💿 Creating DMG...${NC}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -srcfolder "${STAGING_DIR}" \
  -volname "${APP_NAME}" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  "${RW_DMG_NAME}"

MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG_NAME}")
DMG_DEVICE=$(echo "${MOUNT_OUTPUT}" | awk '$2 == "Apple_HFS" { print $1; exit }')
DMG_MOUNT_POINT=$(echo "${MOUNT_OUTPUT}" | awk '$2 == "Apple_HFS" { $1 = ""; $2 = ""; sub(/^[ \t]+/, ""); print; exit }')

if [ -z "${DMG_DEVICE}" ] || [ -z "${DMG_MOUNT_POINT}" ]; then
    echo -e "${RED}Error: failed to mount temporary DMG${NC}"
    exit 1
fi

bless --folder "${DMG_MOUNT_POINT}" --openfolder "${DMG_MOUNT_POINT}" >/dev/null 2>&1 || true

osascript <<EOF
tell application "Finder"
    tell disk "$(basename "${DMG_MOUNT_POINT}")"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 920, 600}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 180
        set text size of theViewOptions to 16
        set position of item "${APP_BUNDLE}" of container window to {220, 260}
        set position of item "Applications" of container window to {610, 260}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

chmod -Rf go-w "${DMG_MOUNT_POINT}" || true
sync
hdiutil detach "${DMG_DEVICE}"
DMG_DEVICE=""
DMG_MOUNT_POINT=""
hdiutil convert "${RW_DMG_NAME}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
rm -f "${RW_DMG_NAME}"

echo ""
echo -e "${GREEN}✅ Done!${NC}"
echo ""
echo "Files created:"
echo "  - ${APP_BUNDLE}/ (test locally)"
echo "  - ${APP_NAME}-${VERSION}.zip (distribute this)"
echo "  - ${DMG_NAME} (drag to Applications)"
echo ""
echo "Test: open '${APP_BUNDLE}'"
