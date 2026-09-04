# 神楽 -KAGURA ASCENT-

魔法少女 × 日本神話の縦画面ローグライト弾幕 STG。八百万の神を迎え、能力を重ね、参道を登る。

公開版（ブラウザ）: https://hiroakit-roko.github.io/kagura/

## 構成（2026-09 から Unity がメイン）

| 場所 | 中身 |
|---|---|
| `Kagura/` | **Unity 6 プロジェクト**（Universal 2D）。iOS 向け発売が主目的、Web ビルドはテストと宣伝用（Chrome を対象） |
| `KaguraCore/` | エンジンに依存しない中核 C#（能力の数式・格・神格・段と波・敵の成長・波の生成）。`Kagura/Assets/Kagura/Core` に同じものを置く |
| `KaguraCore.Tests/` | 中核が Godot 版の出力と一致することを確かめる照合テスト（`dotnet test`） |
| `data/` | ゲームデータの正本（神・能力・神宝・禍・敵）。Godot 版から書き出した JSON。Unity は `Kagura/Assets/Kagura/Resources/Data` にコピーして読む |
| `site/` | GitHub Pages に配信する Unity の Web ビルド（`tools/build_web.sh` が生成） |
| `tools/` | ビルドと配信のスクリプト |
| `godot/` | **旧 Godot 4.7 版（バックアップ）**。設計と数値の原典。動かすには `cd godot && godot --path .` |
| `docs/` | 能力一覧などの資料 |

## 開発の流れ

```sh
# 中核の数式を直したら照合テスト
cd KaguraCore.Tests && dotnet test

# Web ビルドを作って site/ を更新（Unity エディタは閉じておく）
tools/build_web.sh
# 作ってそのまま配信（コミット + push → GitHub Actions が Pages へ）
tools/build_web.sh --deploy
```

- Unity エディタで開くのは `Kagura/`。メニュー `Kagura > Create Main Scene` / `Kagura > Build Web` からも同じことができる。
- ゲーム内の版表示は `Kagura/Assets/Kagura/Resources/version.txt`（ビルド時に `v2.<コミット数>` を刻印）。
- 世界ランキングは Supabase（`godot/supabase/` にスキーマ、`godot/supabase.cfg` に URL と anon key）。Unity 版からも同じテーブルへ送る。

## Godot 版から引き継いだ決まり

- 座標は 1 単位 = Godot 版の 100px（画面幅 640px = 6.4 単位）。数値はそのまま流用できる。
- 神 9 柱、能力は各神 9 種（凡 4・稀 3・秀 2、最大 3 つまで）、神宝 18、段は 3 つ × 8 波、24 波目が最終ボス。
- UI の文言は短く大きく。経緯や仕様の説明を画面に書かない。
