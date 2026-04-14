#!/bin/zsh
cd /Users/liupengfei/worker/alfred_for_me

# 受信任的自签名证书（已导入 login keychain 并信任，无需独立 keychain）
SIGN_IDENTITY="4D75E41CC9C606663C515A2E420C654020277EDE"

swift build -c release 2>&1 | grep -E "error:|warning:|Build complete"
if [ $? -eq 0 ]; then
  pkill -f AlfredForMe 2>/dev/null
  sleep 0.5
  cp .build/release/AlfredForMe /Applications/AlfredForMe.app/Contents/MacOS/AlfredForMe
  mkdir -p /Applications/AlfredForMe.app/Contents/Resources
  cp AlfredForMe/Resources/AppIcon.icns /Applications/AlfredForMe.app/Contents/Resources/ 2>/dev/null
  codesign --force --sign "$SIGN_IDENTITY" --deep /Applications/AlfredForMe.app
  open /Applications/AlfredForMe.app
  echo "DEPLOYED"
fi
