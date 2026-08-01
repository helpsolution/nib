#!/usr/bin/env bash
# Сборка Nib.app и Nib.dmg. Запускать на macOS.
# Требуется: Xcode Command Line Tools (xcode-select --install) или полный Xcode.

set -euo pipefail

APP_NAME="Nib"
BUNDLE_ID="local.nib.editor"
VERSION="1.1.1"
MIN_MACOS="13.0"
ARCHS="arm64 x86_64"   # universal binary: Apple Silicon + Intel

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"

command -v swiftc >/dev/null || { echo "swiftc не найден. Выполни: xcode-select --install"; exit 1; }
SDK="$(xcrun --show-sdk-path --sdk macosx)"

SOURCES=("$ROOT"/Sources/*.swift)
[ -e "${SOURCES[0]}" ] || { echo "Нет исходников в $ROOT/Sources"; exit 1; }

echo "==> Чистка"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/slices"

for arch in $ARCHS; do
  echo "==> Компиляция ($arch, ${#SOURCES[@]} файлов, macOS $MIN_MACOS+, SDK: $(basename "$SDK"))"
  swiftc \
    -O -whole-module-optimization \
    -parse-as-library \
    -sdk "$SDK" \
    -target "${arch}-apple-macos${MIN_MACOS}" \
    -framework SwiftUI -framework AppKit \
    -o "$BUILD/slices/$APP_NAME-$arch" \
    "${SOURCES[@]}"
done

echo "==> Склейка universal binary ($ARCHS)"
SLICES=""
for arch in $ARCHS; do SLICES="$SLICES $BUILD/slices/$APP_NAME-$arch"; done
lipo -create $SLICES -output "$APP/Contents/MacOS/$APP_NAME"
rm -rf "$BUILD/slices"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Local build</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Markdown</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
        <string>public.plain-text</string>
        <string>public.text</string>
      </array>
    </dict>
  </array>
  <key>UTImportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>net.daringfireball.markdown</string>
      <key>UTTypeDescription</key><string>Markdown</string>
      <key>UTTypeConformsTo</key>
      <array><string>public.plain-text</string></array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>md</string><string>markdown</string>
          <string>mdown</string><string>mkd</string><string>mdx</string>
        </array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -f "$ROOT/icon_1024.png" ]; then
  echo "==> Иконка"
  ICONSET="$BUILD/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for sz in 16 32 128 256 512; do
    sips -z $sz $sz       "$ROOT/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}.png"      >/dev/null
    sips -z $((sz*2)) $((sz*2)) "$ROOT/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

echo "==> Подпись (ad-hoc)"
codesign --force --sign - "$APP"   # --deep объявлен Apple устаревшим; вложенного кода в бандле нет

echo "==> DMG"
DMG="$BUILD/$APP_NAME-$VERSION.dmg"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$STAGE" -ov -format UDZO \
  "$DMG" >/dev/null
rm -rf "$STAGE"

echo
echo "Готово:"
echo "  $APP"
echo "  $DMG"
echo
echo "Открой DMG, перетащи $APP_NAME в Applications."
echo "Потом: правый клик на .md → Открыть в программе → $APP_NAME."
