#!/bin/zsh
cd /Users/liupengfei/worker/alfred_for_me

# 自签名证书
SIGN_IDENTITY="4D75E41CC9C606663C515A2E420C654020277EDE"
KEYCHAIN="$HOME/.alfreddev/signing.keychain-db"

swift build -c release 2>&1 | grep -E "error:|warning:|Build complete"
if [ $? -eq 0 ]; then
  pkill -f AlfredForMe 2>/dev/null
  sleep 0.5
  cp .build/release/AlfredForMe /Applications/AlfredForMe.app/Contents/MacOS/AlfredForMe
  mkdir -p /Applications/AlfredForMe.app/Contents/Resources
  cp AlfredForMe/Resources/AppIcon.icns /Applications/AlfredForMe.app/Contents/Resources/ 2>/dev/null

  # Try signing with dedicated keychain first, fall back to login keychain, then ad-hoc
  if [ -f "$KEYCHAIN" ]; then
    security unlock-keychain -p "alfred" "$KEYCHAIN" 2>/dev/null
    codesign --force --sign "$SIGN_IDENTITY" --keychain "$KEYCHAIN" --deep /Applications/AlfredForMe.app 2>&1
  else
    codesign --force --sign "$SIGN_IDENTITY" --deep /Applications/AlfredForMe.app 2>&1
  fi

  if [ $? -ne 0 ]; then
    echo "⚠️  Certificate signing failed, falling back to ad-hoc signing..."
    codesign --force --sign - --deep /Applications/AlfredForMe.app
  fi

  open /Applications/AlfredForMe.app
  echo "DEPLOYED"
fi
