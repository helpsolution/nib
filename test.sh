#!/usr/bin/env bash
# Прогон тестов. Запускать на macOS, зависимостей нет — только swiftc.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MIN_MACOS="13.0"

command -v swiftc >/dev/null || { echo "swiftc не найден. Выполни: xcode-select --install"; exit 1; }
SDK="$(xcrun --show-sdk-path --sdk macosx)"

# Всё, кроме NibApp: там @main, он конфликтует с точкой входа тестов.
# Список берём глобом, как в build.sh: раньше он был выписан руками и отставал
# от Sources/ при каждом новом файле.
SOURCES=()
for file in "$ROOT"/Sources/*.swift; do
  [ "$(basename "$file")" = "NibApp.swift" ] && continue
  SOURCES+=("$file")
done
[ ${#SOURCES[@]} -gt 0 ] || { echo "Нет исходников в $ROOT/Sources"; exit 1; }

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
