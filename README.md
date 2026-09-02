# KAGURA ASCENT ― 神楽

Godot 4.7 製の縦スクロールシューティング。魔法少女が参道を登り、八百万の神々から
恩恵（Boon）を授かって強くなる。成長システムは『Hades』の恩恵システムを
日本神話に置き換えたもので、**最初に選んだ神が主神、のちに恩恵を受けた 2 柱が副神**になる。

- 自機は `image/walk.gif` の後半（自然な歩行部分）から切り出した後ろ姿のスプライト
- タイトルは `image/title.png`
- 敵・弾・エフェクト・UI はすべて `_draw()` によるプロシージャル描画、効果音は起動時に波形合成
- 将来のブラウザ配信を前提に、レンダラーは Compatibility、日本語フォントはプロジェクトに同梱

## 遊び方

```sh
godot --path .          # 直接起動
godot -e --path .       # エディタで開く
```

| 操作 | キー |
| --- | --- |
| 移動 | WASD / 矢印キー |
| 攻撃 | 自動 |
| 特技（御札） | 自動（周期的に放つ） |
| 詠唱 | Z / J（強い一撃。2 発まで貯まる） |
| 疾走 | Space（短時間無敵） |
| 神招き | X / K（ゲージ 1/4 以上で発動。満タンなら大神招き） |
| 低速移動（当たり判定表示） | Shift |
| 選択 | 1〜9 またはクリック |
| 神籤の引き直し | R（恩恵選択ごとに 1 回） |
| 小休止 / ミュート | P / M |
| タイトルへ戻る / 終了 | Esc |

### スマホ（タッチ操作）

- 画面のどこでも指をなぞると、その移動量ぶん自機が動く（指で自機が隠れない相対移動）
- 画面下の丸ボタン：左が**疾走**、右が**詠唱**、その上が**神招き**。右上の「休」で小休止
- 選択画面・タイトル・ゲームオーバーはタップで選ぶ
- 縦長の端末では横幅を基準に画面いっぱいまでプレイ領域が広がる（黒帯なし）

## ゲームの流れ

1. ウェーブごとに穢れ（敵）が降ってくる。全滅させるとクリア。5 ウェーブごとに大妖（ボス）。
2. 敵を倒すと勾玉（経験値）が落ちる。レベルが上がるとゲームが止まり、神との邂逅になる。
3. **最初のレベルアップでは 3 柱から主神を選ぶ。** 主神はすぐに稀以上の恩恵を授ける。
4. 以降のレベルアップでは 1 柱の神が現れ、3 つの恩恵から 1 つを選ぶ。
   3 柱揃うまでは新しい神も現れ、その神の恩恵を受け取ると副神になる。
5. 3 波ごと、およびボス撃破時に**神酒**（Hades の Pom of Power）が降りてくる。拾うと
   所持している恩恵をひとつ選んでレベルを上げられる。
6. ボス撃破の褒賞は主神からの秀（Epic）以上の恩恵。

## 恩恵システム（Hades との対応）

| Hades | 本作 |
| --- | --- |
| Attack / Special / Cast / Dash / Call のスロット | 攻撃 / 特技（御札） / 詠唱 / 疾走 / 神招き |
| 神ごとの状態異常（Jolted, Doom, Weak…） | 神ごとの**神威**（帯電・宿命・弱体…） |
| Common / Rare / Epic / Heroic | 凡 / 稀 / 秀 / 英（倍率 ×1.0 / 1.35 / 1.8 / 2.3） |
| Exchange（他神の恩恵で上書き、レア +1） | 交換（同じ。レベルは引き継ぐ） |
| Legendary（同神の恩恵 2 つが前提） | 伝説（**主神のみ**） |
| Duo Boon（2 神の恩恵が前提） | 双神 |
| Pom of Power（レベルアップ、逓減） | 神酒（+28% → +20% → +14% → …） |
| God Gauge / Greater Call | 神招きゲージ（1/4 で発動、満タンで大神招き） |
| Fated Persuasion（再抽選） | 神籤の引き直し |

### 神々

| 神 | 対応する Hades の神 | 神威 | 特色 |
| --- | --- | --- | --- |
| 天照大神 | Athena | 照覧（被ダメ増） | 敵弾の反射・消弾、被ダメ軽減、鏡の護り |
| 須佐之男命 | Poseidon | 裂傷（移動でダメージ） | 押し戻し、大波、衝突ダメージ、天叢雲の一閃 |
| 建御雷神 | Zeus | 帯電（攻撃時に自傷） | 連鎖する雷、落雷、雷雲 |
| 月読命 | Ares | 宿命（遅延ダメージ） | 宿命の爆発、回転する月輪、低 HP 即死 |
| 天宇受売命 | Aphrodite | 弱体（与ダメ減） | 高倍率ダメージ、魅了（敵が仲間を攻撃） |
| 宇迦之御魂神（稲荷） | Artemis | 狐憑き（次弾会心） | 会心、追尾する狐火、眷属の狐 |
| 少名毘古那神 | Dionysus | 酩酊（重なる継続ダメージ） | 酒気の霧、回復、常世の妙薬 |
| 伊邪那美命 | Demeter | 冷気（減速、限界で砕ける） | 凍土、凍結、黄泉の穢れ |
| 猿田彦大神 | Hermes | ― | 移動・発射速度・疾走・詠唱の加護のみ（主神候補外） |

双神は 12 種（天鳴、日月の裁、嵐雷、凍海、月狐、宴と舞、雷酔、黄泉の月、狐雷、艶光、波と舞、凍狐）。
データはすべて `scripts/kami.gd` にあり、数値は `base × レアリティ倍率 + レベル補正` で決まる。

## 構成

```
main.tscn              ルートは Node2D 1 つだけ。中身はすべてコードから生成する
image/
  title.png            タイトル絵
  player_walk.png      walk.gif から抽出した歩行スプライトシート（10 フレーム、ピンポン再生）
  walk.gif             元素材（ゲームでは未使用）
fonts/
  ZenKakuGothicNew-Medium.ttf        本文（全グリフ同梱）
  ShipporiMinchoB1-Bold.subset.ttf   見出し（使用文字だけにサブセット化）
scripts/
  cfg.gd               画面サイズ・レイヤ・配色・レアリティ・スロットの定数
  kami.gd              神と恩恵のデータベース（値の計算・説明文の生成）
  boons.gd             神の出現と恩恵の抽選・取得・交換・神酒
  combat.gd            命中処理の中枢。倍率、神威の付与、雷・宿命・砕け、伝説／双神の発動
  game.gd              進行役。ウェーブ、状態遷移、選択画面の開閉、ヒットストップ
  player.gd            自機。スプライト歩行、5 つの技、恩恵の参照 API（has / val）
  enemy.gd             雑魚敵。神威（状態異常）の保持と tick、魅了時の挙動
  boss.gd              Enemy を継承した大妖
  bullet.gd            自機弾・敵弾。反射／消弾／渦／雷雲／領域生成
  zone.gd              月輪・酒気・凍土・雷雲などの持続領域
  drone.gd             眷属の狐
  pickup.gd            勾玉・御札・神酒
  ui.gd                HUD / 主神選択 / 恩恵選択 / 神酒 / タイトル / ゲームオーバー
  emblem.gd            神々の紋章
  fx.gd                パーティクル・斬撃・残像・稲妻・画面フラッシュ
  sfx.gd               起動時に合成する効果音（鈴・太鼓・龍笛など和風の音を含む）
  starfield.gd         夜空・月・雲・花弁・参道の背景
  autoplay.gd          開発用の自動プレイ＆スクリーンショット
tools/subset_fonts.py  見出しフォントのサブセット化
export_presets.cfg     Web 書き出し設定（Thread Support OFF）
```

### 設計メモ

- **命中は必ず `Combat.hit()` を通す。** 照覧・弱体などの倍率、会心、神威の付与、双神・伝説の
  派生効果を一箇所で処理する。弾は「どのスロットの弾か（slot）」と「どの神の弾か（kami）」だけを持つ。
- **恩恵の値は保存しない。** `Player.val(id)` が `Kami.value(base, rar, lv)` を毎回計算する。
  神酒でレベルが変わっても参照側の修正は不要。
- **シグナル処理中にノードを生やさない。** `area_entered` の最中に `Area2D` を `add_child` すると
  物理サーバのフラッシュ中エラーになる。生成は `Game.spawn_deferred()` か `call_deferred` を通す。
- **ヒットストップは `Game.hitstop(dur, scale)`。** 会心・宿命・砕け・ボスのフェーズ変化・神招きで
  時間の流れを一瞬止め、手応えを出す。UI と Game は `PROCESS_MODE_ALWAYS`。
- **ポーズは `get_tree().paused`。** 選択画面はすべてポーズ中に描かれる。

## ブラウザ版

公開先（GitHub Pages）: <https://hiroakit-roko.github.io/kagura/>

`main` に push すると `.github/workflows/deploy-pages.yml` が Godot 4.7.1 のコンテナで Web 版を
書き出し、そのまま GitHub Pages にデプロイする。手元で `build/` をコミットする必要はない。

Godot の Web 書き出しは Compatibility レンダラーのみ対応なので、デスクトップ版も同じ
レンダラーで動かして見た目を揃えている。Glow は Compatibility では簡易実装になるため、
`glow_hdr_threshold` を 1.0 未満（0.82）にしている。OS フォントは Web で使えないので、
日本語フォントを同梱している。

```sh
# エクスポートテンプレート（4.7.1）を入れたうえで
godot --headless --path . --export-release Web build/web/index.html
cd build/web && python3 -m http.server 8080   # http://localhost:8080/
```

- `variant/thread_support=false` にしているので COOP/COEP ヘッダなしで動く（itch.io 等でそのまま可）。
- 効果音は実行時生成の `AudioStreamWAV` なので、Web の既定（Sample 再生）で問題ない。
- ブラウザの自動再生制限により、最初のクリック／キー入力までは音が出ない。
- 見出しフォントは使用文字だけに絞っている。神や恩恵の文言を追加したら
  `python3 tools/subset_fonts.py <ShipporiMinchoB1-Bold.ttf>` を再実行する。

## 開発用ツール

自動プレイしながら要所のスクリーンショットを保存する：

```sh
godot --path . -- --capture              # 120 秒プレイして撮影（主神選択・恩恵・神酒・ボスなど）
godot --path . -- --capture --deathtest  # ゲームオーバー→リスタート→ポーズを確認
```

出力先は `~/Library/Application Support/Godot/app_userdata/KAGURA ASCENT/shots/`。

## 調整ポイント

| 内容 | 場所 |
| --- | --- |
| 自機の初期性能 | `player.gd` の `stats` |
| 恩恵の効果量・説明文 | `kami.gd` の `BOONS`（`base`） |
| レアリティ倍率・神酒の逓減 | `cfg.gd` の `RAR_MULT` / `LV_BONUS` |
| レアリティの基礎確率・神の出現重み | `boons.gd` の `RAR_WEIGHTS` / `pick_kami()` |
| 状態異常の持続と倍率 | `combat.gd` 冒頭の定数と `hit()` |
| 敵の性能・弾幕 | `enemy.gd` の `setup()` / `_behavior()` |
| ウェーブの物量と敵の解禁 | `game.gd` の `_build_wave()` |
| ボスの HP と攻撃パターン | `boss.gd` の `setup_boss()` / `_choose_attack()` |

## ライセンス

- フォント：Zen Kaku Gothic New、Shippori Mincho B1（SIL Open Font License 1.1、`fonts/OFL-*.txt`）
