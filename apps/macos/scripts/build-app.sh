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
MEMORY_SERVICE_DIR="../../services/memory-pglite"

# Check directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: Run this from apps/macos directory${NC}"
    exit 1
fi

if [ ! -f "${MEMORY_SERVICE_DIR}/package.json" ]; then
    echo -e "${RED}Error: Memory PGlite service not found at ${MEMORY_SERVICE_DIR}${NC}"
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
rm -rf "${APP_BUNDLE}" "${APP_NAME}-${VERSION}.zip"
swift package clean

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

# Zip it
echo -e "${YELLOW}📦 Creating zip...${NC}"
zip -qr "${APP_NAME}-${VERSION}.zip" "${APP_BUNDLE}"

echo ""
echo -e "${GREEN}✅ Done!${NC}"
echo ""
echo "Files created:"
echo "  - ${APP_BUNDLE}/ (test locally)"
echo "  - ${APP_NAME}-${VERSION}.zip (distribute this)"
echo ""
echo "Test: open '${APP_BUNDLE}'"
