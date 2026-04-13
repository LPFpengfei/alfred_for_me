#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="AlfredForMe"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Build with Swift Package Manager (Release mode)
swift build -c release 2>&1
echo "✅ Compilation successful!"

# Locate the compiled binary
BINARY="$BUILD_DIR/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found at $BINARY"
    exit 1
fi

echo "📦 Creating $APP_NAME.app bundle..."

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create .app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist with resolved variables
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>AlfredForMe</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.liupengfei.AlfredForMe</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AlfredForMe</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>AlfredForMe needs to send Apple Events to control other applications.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>AlfredForMe needs accessibility access to register global hotkeys.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy icon if present
if [ -f "$SCRIPT_DIR/AlfredForMe/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AlfredForMe/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "🎨 App icon copied"
fi

# Copy entitlements if present
if [ -f "$SCRIPT_DIR/AlfredForMe/Resources/AlfredForMe.entitlements" ]; then
    cp "$SCRIPT_DIR/AlfredForMe/Resources/AlfredForMe.entitlements" "$APP_BUNDLE/Contents/Resources/"
fi

# Ad-hoc code sign
echo "🔏 Code signing..."
codesign --force --sign - --deep "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"
echo ""

# Install to /Applications
read -p "是否安装到 /Applications? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" /Applications/
    echo "✅ 已安装到 /Applications/$APP_NAME.app"
    echo "💡 首次运行请在 系统设置 > 隐私与安全 > 辅助功能 中授权 $APP_NAME"
else
    echo "💡 你可以手动将 $APP_BUNDLE 拖到 /Applications 目录安装"
fi
