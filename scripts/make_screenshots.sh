#!/bin/bash
# 用演示数据渲染 README 截图到 docs/images/。不读写真实配置，也不会启动拦截。
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
EXTRA_FLAGS=()
STALE="$(dirname "$(dirname "$(xcrun --find swiftc)")")/include/swift/module.modulemap"
if [[ -f "$STALE" && -f "$(dirname "$STALE")/bridging.modulemap" ]]; then
    : > build/empty.modulemap
    cat > build/overlay.yaml <<YAML
{ "version": 0, "case-sensitive": "false", "roots": [
  { "type": "file", "name": "$STALE", "external-contents": "$PWD/build/empty.modulemap" } ] }
YAML
    EXTRA_FLAGS=(-vfsoverlay build/overlay.yaml -Xcc -ivfsoverlay -Xcc build/overlay.yaml)
fi

swiftc -O -parse-as-library -D SCREENSHOTS ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-name FocusGuard \
    Sources/FocusGuard/*.swift scripts/screenshots/Screenshots.swift \
    -o build/screenshots

DEMO_DIR="$(mktemp -d)"
trap 'rm -rf "$DEMO_DIR"' EXIT
FOCUSGUARD_DATA_DIR="$DEMO_DIR" build/screenshots docs/images

# 遮罩截图是渐变大图，转成 jpg 体积小很多
sips -Z 1200 -s format jpeg -s formatOptions 85 docs/images/shield-prompt.png --out docs/images/shield-prompt.jpg >/dev/null
rm docs/images/shield-prompt.png
