#!/bin/bash
# 编译并打包成 FocusGuard.app（无需 Xcode）。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/FocusGuard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# 部分 Command Line Tools 升级后会残留旧的 usr/include/swift/module.modulemap，
# 与新的 bridging.modulemap 重复定义 SwiftBridging，导致所有框架都无法导入。
# 这里用 VFS overlay 把旧文件替换成空文件，绕过这个问题而不改动系统文件。
EXTRA_FLAGS=()
STALE="$(dirname "$(dirname "$(xcrun --find swiftc)")")/include/swift/module.modulemap"
if [[ -f "$STALE" && -f "$(dirname "$STALE")/bridging.modulemap" ]]; then
    mkdir -p build
    : > build/empty.modulemap
    cat > build/overlay.yaml <<YAML
{ "version": 0, "case-sensitive": "false", "roots": [
  { "type": "file", "name": "$STALE", "external-contents": "$PWD/build/empty.modulemap" } ] }
YAML
    EXTRA_FLAGS=(-vfsoverlay build/overlay.yaml -Xcc -ivfsoverlay -Xcc build/overlay.yaml)
fi

# 直接用 swiftc 编译（不依赖 Xcode / SwiftPM）
swiftc -O -parse-as-library ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-name FocusGuard \
    Sources/FocusGuard/*.swift \
    -o "$APP/Contents/MacOS/FocusGuard"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>FocusGuard</string>
    <key>CFBundleDisplayName</key><string>FocusGuard</string>
    <key>CFBundleIdentifier</key><string>local.focusguard</string>
    <key>CFBundleExecutable</key><string>FocusGuard</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>FocusGuard 需要读取浏览器当前网址，以便在专注期间拦截摸鱼网站。</string>
</dict>
</plist>
PLIST

# ad-hoc 签名，让「自动化」权限能稳定记住这个 App
codesign --force --sign - "$APP"
echo "已生成 $APP"

# --install：安装到 /Applications，这样启动台和 Spotlight 里都能找到
if [[ "${1:-}" == "--install" ]]; then
    osascript -e 'quit app "FocusGuard"' 2>/dev/null || true
    rm -rf /Applications/FocusGuard.app
    cp -R "$APP" /Applications/
    echo "已安装到 /Applications/FocusGuard.app"
fi
