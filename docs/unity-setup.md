# 神楽 -KAGURA ASCENT- Unity 版

Godot 版（`scripts/`）から Unity 6 へ移す作業場所。目的は **iOS 向けの発売**で、ブラウザ版（Chrome）はテストプレイと宣伝用。

## 構成

| フォルダ | 中身 |
|---|---|
| `KaguraCore/` | エンジンに依存しない中核（能力の数式、格、神格の伸び、波の生成、敵の成長）。C# 9 / .NET Standard 2.1 で Unity 6 にそのまま入る |
| `KaguraCore.Tests/` | Godot 版の出力 `export/data/*.json` と一致するかの照合テスト（`dotnet test`） |
| `../export/data/` | Godot 版から書き出したデータ（神・能力・神宝・禍・敵）。`godot --headless --path . -s tools/dump_data.gd` で再生成 |

中核をエンジンから切り離してあるので、ゲームの数値やバランスは Unity エディタを開かずに `dotnet test` で検証できる。

## 手元の準備（ユーザーが行う手順）

1. **Unity Hub**：`brew install --cask unity-hub` 済み。`/Applications/Unity Hub.app` を開き、Unity ID でサインインする（Personal は年商 20 万ドル以下なら無料、Unity 6 からスプラッシュも任意）。
2. **Unity Editor**：Hub の Installs から **Unity 6 LTS（6000.x、最新の LTS）** を入れる。モジュールは次の 3 つにチェック。
   - iOS Build Support
   - Web Build Support（旧 WebGL）
   - Mac Build Support（手元での動作確認用）
3. **Xcode**：26.6 が入っているので追加作業なし。App Store 配信には Apple Developer Program（年 99 ドル）の登録が必要。
4. **プロジェクト作成**：Hub の New project で **Universal 2D** テンプレート、名前 `Kagura`、場所はこのリポジトリの `unity/Kagura/`。
5. **パッケージ**：Window > Package Manager から
   - `com.unity.nuget.newtonsoft-json`（データ JSON の読込）
   - `com.unity.inputsystem`（タッチとキーボード）
   - `com.unity.textmeshpro`（日本語フォント。Universal 2D テンプレートには同梱）
6. `KaguraCore/*.cs` を `unity/Kagura/Assets/Kagura/Core/` へ、`export/data/*.json` を `Assets/Kagura/Data/`（Resources か StreamingAssets）へコピーする。

## 移植の方針

- **描画**：Godot 版は線・円弧・多角形を毎フレーム描いていた。Unity では敵・弾・アイテム・発光を **スプライト**（Midjourney の絵 + 発光を焼き込んだ 1 枚）にし、SpriteRenderer と **加算合成マテリアル**で描く。弾は `ObjectPool` で使い回し、Sprite Atlas で 1 ドローコールにまとめる。
- **エフェクト**：粒・輪・斬撃は ParticleSystem と Shader Graph（URP 2D）。
- **UI**：Canvas + TextMeshPro。フォントは `fonts/` の Shippori Mincho / Zen Kaku Gothic を SDF 化（日本語は Dynamic SDF で不足文字を実行時生成）。
- **音**：BGM は MP3 のまま AudioSource（iOS はハード復号）。効果音は Godot 版の合成音を WAV に書き出して AudioClip に。
- **記録・ランキング**：ローカルは `PlayerPrefs` か `Application.persistentDataPath` の JSON。世界ランキングは Supabase REST を `UnityWebRequest` で呼ぶ（Web ビルドでは CORS のため Supabase 側で GitHub Pages のオリジンを許可）。
- **プラットフォーム**：iOS は縦固定・120Hz 対応（`Application.targetFrameRate = 60`）。Web は Chrome を対象にし、Safari は動作保証しない。

## 進捗

- [x] Godot 版のデータを JSON に書き出し（神 9・能力 118・神宝 18・禍・敵）
- [x] 中核の C# 移植と照合テスト（能力の値と説明文、格、神格、段と波、波の生成）
- [ ] Unity プロジェクト作成（ユーザーの Hub サインイン後）
- [ ] 自機・弾・敵・当たり判定
- [ ] 9 神の神器・詠唱・神招き・状態異常
- [ ] ボス 3 体
- [ ] UI（タイトル・神選択・能力カード・神宝・ランキング・カットイン・ストーリー）
- [ ] 記録と Supabase
- [ ] iOS ビルドと TestFlight
- [ ] Web ビルド（Chrome）と GitHub Pages 配信
