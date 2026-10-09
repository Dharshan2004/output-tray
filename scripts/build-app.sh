#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/work/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/swift-cache"
swift build -c release --disable-sandbox --cache-path "$PWD/work/package-cache"
APP="$PWD/outputs/Output Tray.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/outputs/Live Outputs"
cp .build/release/OutputTray "$APP/Contents/MacOS/OutputTray"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>OutputTray</string><key>CFBundleIdentifier</key><string>local.outputtray.app</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleDisplayName</key><string>Output Tray</string><key>CFBundleName</key><string>Output Tray</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>0.1</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/><key>LSMinimumSystemVersion</key><string>14.0</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
