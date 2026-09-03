class_name Cfg
extends RefCounted

## 画面・当たり判定レイヤ・配色などの共通定数。

const W := 640.0
## 基準の高さ。縦長の端末（スマホ）では横幅を基準に伸ばすので、実行時に Game が更新する。
const H_BASE := 960.0
static var H := 960.0
## 軽量描画（スマホ）。発光の省略・アンチエイリアス無し・粒を減らす
static var LITE := false
## 実機での切り分け用（URL の ?noglow ?noscenery ?fps=24 ?dpr=1.5 で切替）
static var NOGLOW := false
static var NOSCENERY := false
## 計測用：--skip=stars,hud のように描画を系ごとに止める
static var SKIP: PackedStringArray = []
static var AA := true
const MARGIN := 20.0

# 衝突レイヤ（ビットマスク値）
const L_PLAYER := 1
const L_ENEMY := 2
const L_PBULLET := 4
const L_EBULLET := 8
const L_PICKUP := 16

# Z順
const Z_STARS := -20
const Z_PICKUP := 3
const Z_PBULLET := 6
const Z_EBULLET := 7
const Z_ENEMY := 9
const Z_PLAYER := 12
const Z_FX := 40

# 配色
const C_PLAYER := Color(0.82, 0.62, 1.0)
const C_PLAYER_DARK := Color(0.30, 0.16, 0.48)
const C_ENEMY := Color(1.0, 0.36, 0.50)
const C_ENEMY2 := Color(1.0, 0.68, 0.26)
const C_ENEMY3 := Color(0.72, 0.45, 1.0)
const C_BOSS := Color(1.0, 0.25, 0.35)
const C_PBULLET := Color(0.85, 0.75, 1.0)
const C_EBULLET := Color(1.0, 0.45, 0.85)
const C_XP := Color(0.55, 0.9, 1.0)
const C_HP := Color(0.45, 1.0, 0.55)
const C_SHIELD := Color(0.55, 0.75, 1.0)
const C_CRIT := Color(1.0, 0.9, 0.35)
const C_BG := Color(0.035, 0.025, 0.07)
const C_GOLD := Color(1.0, 0.84, 0.45)
const C_PAPER := Color(0.96, 0.92, 0.84)
const C_INK := Color(0.10, 0.07, 0.12)

# 恩恵のレアリティ（Hades の Common / Rare / Epic / Heroic / Legendary / Duo に対応）
enum Rar {COMMON, RARE, EPIC, HEROIC, LEGENDARY, DUO}
const RAR_COLOR := [
	Color(0.86, 0.88, 0.92),  # 凡 白
	Color(0.40, 0.72, 1.00),  # 稀 青
	Color(0.80, 0.50, 1.00),  # 秀 紫
	Color(1.00, 0.42, 0.42),  # 英 赤
	Color(1.00, 0.72, 0.25),  # 伝 橙
	Color(0.45, 1.00, 0.62),  # 双 緑
]
const RAR_NAME := ["凡", "稀", "秀", "英", "伝", "双"]
const RAR_LONG := ["COMMON", "RARE", "EPIC", "HEROIC", "LEGENDARY", "DUO"]
## レアリティごとの効果倍率。Hades では Rare ×1.3〜1.5 / Epic ×1.8〜2.0 / Heroic ×2.3〜2.5。
const RAR_MULT := [1.0, 1.35, 1.8, 2.3, 1.0, 1.0]
## 神酒（Pom of Power）によるレベル補正。Hades と同じく逓減する（+28%, +20%, +14%, +10%, +7%）。
const LV_BONUS := [0.0, 0.28, 0.48, 0.62, 0.72, 0.79, 0.84, 0.88]

# 恩恵スロット
enum Slot {ATTACK, SPECIAL, CAST, DASH, CALL, PASSIVE}
const SLOT_NAME := ["攻撃", "特技", "詠唱", "疾走", "神招き", "加護"]
const SLOT_HINT := [
	"通常弾に神威を宿す",
	"周期的に放つ御札に神威を宿す",
	"詠唱弾（Z/J）に神威を宿す",
	"疾走（Space・指を弾く）に神威を宿す",
	"神招き（X/K）で神を降ろす",
	"常時発動の加護",
]


# ステージ構成：8 波ごとに 1 ステージ。各ステージの最後の波がボス、第 3 ステージの最後がラスボス
## 画面全体の発光後処理を使うか。false なら手描きの光輪だけ（軽い）
const GLOW_POST := false
## 詠唱の札が敵から落ちる確率（1 体ごと）
const TALISMAN_DROP := 0.02
## スマホの指への追従の基準（1.0 で指と同じ移動量）
const TOUCH_SENS := 0.7
const STAGE_LEN := 8
const STAGE_COUNT := 3
const STAGE_NAME := ["参道", "拝殿", "奥宮"]
const STAGE_KANJI := ["一", "二", "三"]
const STAGE_TINT := [Color(0.45, 0.30, 0.80), Color(0.75, 0.30, 0.45), Color(0.25, 0.20, 0.55)]


static func stage_of(wave: int) -> int:
	# 踏破後（エンドレス）は 3 ステージを巡回する
	return int((maxi(wave, 1) - 1) / STAGE_LEN) % STAGE_COUNT + 1


static func is_boss_wave(wave: int) -> bool:
	return wave % STAGE_LEN == 0


static func is_final_wave(wave: int) -> bool:
	return wave == STAGE_LEN * STAGE_COUNT


static func play_rect() -> Rect2:
	return Rect2(MARGIN, MARGIN, W - MARGIN * 2.0, H - MARGIN * 2.0)


static func off_screen(p: Vector2, pad := 80.0) -> bool:
	return p.x < -pad or p.x > W + pad or p.y < -pad or p.y > H + pad


static func with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
