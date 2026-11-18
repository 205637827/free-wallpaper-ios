#!/usr/bin/env bash
# FreeWallpaperiOS 一键打包 IPA（在 Mac + Xcode 上运行）
# 用法:  cd 到项目目录 && bash build_ipa.sh
set -euo pipefail

PROJ="FreeWallpaperiOS.xcodeproj"
SCHEME="FreeWallpaperiOS"
OUT="build"
IPA_OUT="$OUT/FreeWallpaperiOS.ipa"
TEAM="${DEVELOPMENT_TEAM:-}"

echo "==> 清理旧产物"
rm -rf "$OUT"

echo "==> 选择 Xcode"
if command -v xcodebuild >/dev/null 2>&1; then
  XC="$(xcode-select -p)"
  echo "    using $XC"
else
  echo "未找到 Xcode / xcodebuild，请在 Mac 上安装 Xcode 27+ 后重试。" >&2
  exit 1
fi

COMMON=(
  -project "$PROJ"
  -scheme "$SCHEME"
  -configuration Release
  -destination 'generic/platform=iOS'
  CODE_SIGNING_ALLOWED=NO
)
if [ -n "$TEAM" ]; then
  COMMON+=(DEVELOPMENT_TEAM="$TEAM")
fi

echo "==> Archive"
xcodebuild archive \
  "${COMMON[@]}" \
  -archivePath "$OUT/FreeWallpaperiOS.xcarchive" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "==> 制作 IPA 包"
APP="$OUT/FreeWallpaperiOS.xcarchive/Products/Applications/FreeWallpaperiOS.app"
if [ ! -d "$APP" ]; then
  echo "找不到 .app 产物: $APP" >&2
  exit 1
fi
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -qry "$IPA_OUT" Payload )

echo "==> 完成"
echo "    IPA: $(cd "$OUT" && pwd)/FreeWallpaperiOS.ipa"
echo "    大小: $(du -h "$IPA_OUT" | cut -f1)"

echo
echo "提示：上面产出的是未签名(ad-hoc 结构)IPA。"
echo "若要安装到真机，可用开发者证书重签："
echo "  codesign -f -s 'iPhone Developer: ...' --entitlements ent.plist Payload/FreeWallpaperiOS.app"
echo "或设置 DEVELOPMENT_TEAM=你的TeamID 后重跑本脚本走自动签名。"
