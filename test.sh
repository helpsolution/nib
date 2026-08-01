#!/usr/bin/env bash
# Прогон тестов. Запускать на macOS, зависимостей нет — только swiftc.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MIN_MACOS="13.0"

command -v swiftc >/dev/null || { echo "swiftc не найден. Выполни: xcode-select --install"; exit 1; }
SDK="$(xcrun --show-sdk-path --sdk macosx)"

# Модули, которые работают без запущенного приложения. Editor, EditorScreen и NibApp
# не берём: они требуют живого окна, а NibApp вдобавок содержит @main и конфликтует
# с точкой входа тестов.
UNITS=(Prefs Typo Highlighter MarkdownDocument)

SOURCES=()
for unit in "${UNITS[@]}"; do
  file="$ROOT/Sources/$unit.swift"
  [ -f "$file" ] || { echo "Нет исходника: $file"; exit 1; }
  SOURCES+=("$file")
done

TESTS=("$ROOT"/Tests/*.swift)
[ -e "${TESTS[0]}" ] || { echo "Нет тестов в $ROOT/Tests"; exit 1; }

BIN="$(mktemp -d)/nib-tests"
trap 'rm -rf "$(dirname "$BIN")"' EXIT

swiftc \
  -sdk "$SDK" \
  -target "$(uname -m)-apple-macos${MIN_MACOS}" \
  -framework SwiftUI -framework AppKit \
  -o "$BIN" \
  "${SOURCES[@]}" "${TESTS[@]}"

"$BIN"
