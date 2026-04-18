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

# Check directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: Run this from apps/macos directory${NC}"
    exit 1
fi

# Clean
echo -e "${YELLOW}🧹 Cleaning...${NC}"
rm -rf "${APP_BUNDLE}" "${APP_NAME}-${VERSION}.zip"
swift package clean

# Build
echo -e "${YELLOW}🔨 Building...${NC}"
swift build -c release

# Create bundle
echo -e "${YELLOW}📦 Creating app bundle...${NC}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

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
    <string>13.0</string>
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
