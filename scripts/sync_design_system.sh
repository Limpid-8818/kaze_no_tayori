#!/usr/bin/env bash
# 从上游仓库同步设计系统到 packages/natsu_no_tegami/。
# 幂等，可重复跑。契约见 packages/natsu_no_tegami/COPY_IN.md。
#
# 用法：make sync-ds  [UPSTREAM=/path/to/natsu_no_tegami]
# 注意：终端输出一律 ASCII —— Windows 控制台默认 GBK 代码页，中文会乱码。

set -uo pipefail
cd "$(dirname "$0")/.."

UPSTREAM="${UPSTREAM:-/d/CodeRepository/Flutter/natsu_no_tegami}"
TARGET="packages/natsu_no_tegami"

echo "=== sync design system ==="
echo "  from: $UPSTREAM"
echo "  to  : $TARGET"
echo ""

if [ ! -d "$UPSTREAM/lib/src/tokens" ]; then
  echo "[x] upstream not found or has no lib/src/tokens: $UPSTREAM"
  echo "    pass an explicit path: make sync-ds UPSTREAM=/d/path/to/repo"
  exit 1
fi

# Flutter 会把 package 字体注册到 packages/natsu_no_tegami/*。
# 同步前守住上游修复，避免一次 sync 让所有字体静默回落系统字体。
TYPOGRAPHY_FILE="$UPSTREAM/lib/src/tokens/natsu_typography.dart"
FONT_STYLE_COUNT=$(grep -c '^[[:space:]]*fontFamily:' "$TYPOGRAPHY_FILE" || true)
FONT_PACKAGE_COUNT=$(grep -c '^[[:space:]]*package: NatsuFontFamilies.packageName' "$TYPOGRAPHY_FILE" || true)
if [ "$FONT_STYLE_COUNT" -eq 0 ] || [ "$FONT_STYLE_COUNT" -ne "$FONT_PACKAGE_COUNT" ]; then
  echo "[x] upstream typography is missing Flutter package font namespaces"
  echo "    every custom TextStyle must set package: NatsuFontFamilies.packageName"
  exit 1
fi

# 白名单：只拷这些，其余（showcase / 六个平台目录 / design_spec 符号链接）一概不动
copy_dir() {
  local rel="$1"
  if [ ! -e "$UPSTREAM/$rel" ]; then
    echo "  [--] skip $rel (absent upstream)"
    return
  fi
  mkdir -p "$TARGET/$(dirname "$rel")"
  rm -rf "$TARGET/$rel"
  cp -r "$UPSTREAM/$rel" "$TARGET/$rel"
  local n
  n=$(find "$TARGET/$rel" -type f | wc -l | tr -d ' ')
  echo "  [ok] $rel ($n files)"
}

copy_dir "lib/src/tokens"
copy_dir "lib/src/components"
copy_dir "assets/fonts"
copy_dir "test"

# showcase 是画廊 App 而非库，不该进来
rm -rf "$TARGET/lib/showcase" "$TARGET/lib/main.dart"

echo ""
UPSTREAM_SHA=$(git -C "$UPSTREAM" rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "  upstream commit: $UPSTREAM_SHA"

echo ""
echo "=== manual steps left (see COPY_IN.md) ==="
echo "  1. replace the placeholder in lib/natsu_no_tegami.dart with the upstream barrel:"
echo "       export 'src/components/components.dart';"
echo "       export 'src/tokens/natsu_tokens.dart';"
echo "  2. copy the upstream pubspec 'fonts:' block into $TARGET/pubspec.yaml"
echo "  3. drop KazeTempTheme from apps/app/lib/app/theme.dart, build ThemeData from tokens"
echo "  4. cd apps/app && flutter pub get && flutter analyze && flutter test"
echo "  5. record upstream commit $UPSTREAM_SHA in COPY_IN.md"
echo "  6. commit as: chore: 拷入设计系统 $UPSTREAM_SHA"
