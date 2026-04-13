#!/bin/bash
set -e

echo "🔨 Building and running AlfredForMe..."

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

# Generate Xcode project
xcodegen generate 2>/dev/null

# Build
xcodebuild -project AlfredForMe.xcodeproj \
    -scheme AlfredForMe \
    -configuration Debug \
    -derivedDataPath build \
    build 2>&1 | tail -5

# Find and run
APP_PATH=$(find build -name "AlfredForMe.app" -type d | head -1)
if [ -n "$APP_PATH" ]; then
    echo "🚀 Launching AlfredForMe..."
    open "$APP_PATH"
else
    echo "❌ Build failed"
    exit 1
fi
