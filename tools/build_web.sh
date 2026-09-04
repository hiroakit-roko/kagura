#!/bin/zsh
# Unity の Web ビルドを作り、GitHub Pages で配信する site/ に置く。
#   tools/build_web.sh            ビルドして site/ を更新
#   tools/build_web.sh --deploy   さらにコミットして push（GitHub Actions が Pages に配信）
# 前提：Unity エディタで Kagura/ を開いていないこと（開いていると batchmode が失敗する）
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJ="$ROOT/Kagura"
UNITY=${UNITY:-/Applications/Unity/Hub/Editor/6000.6.0f1/Unity.app/Contents/MacOS/Unity}
LOG=${LOG:-/tmp/kagura_web_build.log}

if [ -f "$PROJ/Temp/UnityLockfile" ]; then
  echo "Unity エディタがプロジェクトを開いています。閉じてから実行してください。" >&2
  exit 1
fi

# 版の刻印：v<コミット数> (<短い SHA>)。ゲーム内の表示に使う
COUNT=$(git -C "$ROOT" rev-list --count HEAD)
SHA=$(git -C "$ROOT" rev-parse --short HEAD)
VERSION="v2.$COUNT"
mkdir -p "$PROJ/Assets/Kagura/Resources"
printf '%s\n%s\n%s\n' "$VERSION" "$SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROJ/Assets/Kagura/Resources/version.txt"
echo "version: $VERSION ($SHA)"

echo "building web… (log: $LOG)"
"$UNITY" -batchmode -nographics -quit -projectPath "$PROJ" -buildTarget WebGL \
  -executeMethod Kagura.Editor.BuildTools.BuildWeb -logFile "$LOG" >/dev/null 2>&1 || {
  echo "ビルド失敗。ログ: $LOG" >&2; grep -E "error CS|Build Failed|Exception" "$LOG" | head -20 >&2; exit 1; }
grep -E "\[Kagura\] web build" "$LOG" || true

OUT="$ROOT/Kagura/Build/Web"
SITE="$ROOT/site"
rm -rf "$SITE"
mkdir -p "$SITE"
cp -R "$OUT"/. "$SITE"/
touch "$SITE/.nojekyll"
# Godot 版が端末に残した Service Worker を無害化するため、同じ名前で素通しの SW を置き続ける
cp "$ROOT/godot/web/service.worker.js" "$SITE/index.service.worker.js"
printf '%s %s\n' "$VERSION" "$SHA" > "$SITE/version.txt"
du -sh "$SITE" | awk '{print "site: " $1}'

if [ "${1:-}" = "--deploy" ]; then
  git -C "$ROOT" add site Kagura/Assets/Kagura/Resources/version.txt
  git -C "$ROOT" commit -q -m "site: Unity Web ビルド $VERSION ($SHA)" || echo "変更なし"
  git -C "$ROOT" push -q origin main
  echo "pushed. GitHub Actions が Pages に配信します。"
fi
