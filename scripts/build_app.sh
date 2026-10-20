#!/bin/bash
# 编译并打包成 FocusGuard.app（无需 Xcode）。
#   ./scripts/build_app.sh             只打包到 build/
#   ./scripts/build_app.sh --install   打包并安装到 /Applications
#   ./scripts/build_app.sh --release   打包通用二进制（Apple 芯片 + Intel）并压缩成 zip，用于发布
#   ./scripts/build_app.sh --icon      重新生成 Resources/ 里的 App 图标
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.2.0"
MODE="${1:-}"

APP="build/FocusGuard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

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
compile() {
    swiftc -O -parse-as-library ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
        -target "$1-apple-macosx14.0" \
        -module-name FocusGuard \
        Sources/FocusGuard/*.swift \
        -o "$2"
}

if [[ "$MODE" == "--icon" ]]; then
    swiftc ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} scripts/make_icon.swift -o build/make_icon
    ICONSET="$(build/make_icon Resources)"
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
    rm -rf "$ICONSET"
    echo "已生成 Resources/AppIcon.icns 和 Resources/logo.png"
    exit 0
fi

if [[ "$MODE" == "--release" ]]; then
    mkdir -p build/arch
    compile arm64 build/arch/FocusGuard-arm64
    compile x86_64 build/arch/FocusGuard-x86_64
    lipo -create build/arch/FocusGuard-arm64 build/arch/FocusGuard-x86_64 -output "$APP/Contents/MacOS/FocusGuard"
else
    compile "$(uname -m)" "$APP/Contents/MacOS/FocusGuard"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>FocusGuard</string>
    <key>CFBundleDisplayName</key><string>FocusGuard</string>
    <key>CFBundleIdentifier</key><string>local.focusguard</string>
    <key>CFBundleExecutable</key><string>FocusGuard</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>FocusGuard 需要读取浏览器当前网址，以便在专注期间拦截摸鱼网站。</string>
</dict>
</plist>
PLIST
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# ad-hoc 签名，让「自动化」权限能稳定记住这个 App
codesign --force --sign - "$APP"
echo "已生成 $APP"

# --install：安装到 /Applications，这样启动台和 Spotlight 里都能找到
if [[ "$MODE" == "--install" ]]; then
    osascript -e 'quit app "FocusGuard"' 2>/dev/null || true
    rm -rf /Applications/FocusGuard.app
    cp -R "$APP" /Applications/
    echo "已安装到 /Applications/FocusGuard.app"
fi

# --release：压缩成 zip（ditto 会保留签名和扩展属性）
if [[ "$MODE" == "--release" ]]; then
    ZIP="build/FocusGuard-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "已生成 ${ZIP}（$(lipo -archs "$APP/Contents/MacOS/FocusGuard")）"
fi
