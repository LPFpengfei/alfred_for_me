#!/bin/zsh
cd /Users/liupengfei/worker/alfred_for_me
swift build -c release 2>&1 | grep -E "error:|warning:|Build complete"
if [ $? -eq 0 ]; then
  pkill -f AlfredForMe 2>/dev/null
  sleep 0.5
  cp .build/release/AlfredForMe /Applications/AlfredForMe.app/Contents/MacOS/AlfredForMe
  mkdir -p /Applications/AlfredForMe.app/Contents/Resources
  cp AlfredForMe/Resources/AppIcon.icns /Applications/AlfredForMe.app/Contents/Resources/ 2>/dev/null
  codesign --force --sign - --deep /Applications/AlfredForMe.app
  open /Applications/AlfredForMe.app
  echo "DEPLOYED"
fi
