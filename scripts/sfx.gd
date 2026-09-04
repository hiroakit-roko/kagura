class_name Sfx
extends Node

## 効果音を起動時にプロシージャルに合成する（外部アセット不要）。
## AudioStreamWAV を生成しておくだけなので Web 版でもそのまま動く。

const SR := 22050

static var inst: Sfx

var _bank := {}
var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _last := {}
var muted := false


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 28:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_bank()


static func play(name: String, vol_db := 0.0, pitch := 1.0, min_gap := 0.0) -> void:
	if inst != null and not Cfg.NOSFX:
		inst._play(name, vol_db, pitch, min_gap)


func _play(name: String, vol_db: float, pitch: float, min_gap: float) -> void:
	if muted or not _bank.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last.get(name, -99.0)) < min_gap:
		return
	_last[name] = now
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _bank[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * SR)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(SR)
		var v: float = clampf(float(f.call(t)), -1.0, 1.0)
		# 端のプチノイズ対策に短いフェードイン/アウト
		var fade := minf(1.0, minf(float(i), float(n - i)) / 64.0)
		data.encode_s16(i * 2, int(v * fade * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = data
	return s


## 鈴（すず）：非整数倍音の重ね合わせで金属的な余韻を作る
static func _bell(t: float, f: float, decay: float) -> float:
	var v := 0.0
	v += sin(TAU * f * t) * exp(-t * decay)
	v += sin(TAU * f * 2.76 * t) * exp(-t * decay * 1.6) * 0.5
	v += sin(TAU * f * 5.40 * t) * exp(-t * decay * 2.4) * 0.25
	v += sin(TAU * f * 8.93 * t) * exp(-t * decay * 3.5) * 0.12
	return v


func _build_bank() -> void:
	# ---- 基本 ----
	_bank["shoot"] = _gen(0.075, func(t):
		var e: float = exp(-t * 52.0)
		var f: float = lerpf(1500.0, 620.0, minf(t / 0.075, 1.0))
		return (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.4) * e * 0.18)

	_bank["eshot"] = _gen(0.11, func(t):
		var e: float = exp(-t * 26.0)
		var f: float = lerpf(320.0, 180.0, minf(t / 0.11, 1.0))
		return signf(sin(TAU * f * t)) * e * 0.14)

	_bank["hit"] = _gen(0.055, func(t):
		var e: float = exp(-t * 70.0)
		return (randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 900.0 * t) * 0.3) * e * 0.20)

	_bank["hit_heavy"] = _gen(0.12, func(t):
		var e: float = exp(-t * 34.0)
		var f: float = lerpf(420.0, 90.0, minf(t / 0.12, 1.0))
		return (randf_range(-1.0, 1.0) * 0.5 + sin(TAU * f * t) * 0.6) * e * 0.34)

	_bank["explode"] = _gen(0.36, func(t):
		var e: float = exp(-t * 11.0)
		var low: float = sin(TAU * lerpf(220.0, 55.0, minf(t / 0.36, 1.0)) * t)
		return (randf_range(-1.0, 1.0) * 0.55 + low * 0.55) * e * 0.42)

	_bank["boom"] = _gen(0.9, func(t):
		var e: float = exp(-t * 4.2)
		var low: float = sin(TAU * lerpf(140.0, 28.0, minf(t / 0.9, 1.0)) * t)
		return (randf_range(-1.0, 1.0) * 0.45 + low * 0.75) * e * 0.6)

	_bank["pickup"] = _gen(0.16, func(t):
		return _bell(t, 1760.0, 22.0) * 0.16)

	_bank["heal"] = _gen(0.4, func(t):
		return (_bell(t, 880.0, 9.0) * 0.6 + _bell(t, 1320.0, 12.0) * 0.4) * 0.2)

	_bank["levelup"] = _gen(0.55, func(t):
		var notes := [659.25, 783.99, 987.77, 1318.5]
		var idx: int = mini(int(t / 0.1), 3)
		var f: float = notes[idx]
		var lt: float = t - idx * 0.1
		return _bell(lt, f, 9.0) * 0.26)

	_bank["hurt"] = _gen(0.32, func(t):
		var e: float = exp(-t * 8.5)
		var f: float = lerpf(430.0, 65.0, minf(t / 0.32, 1.0))
		var saw: float = fmod(f * t, 1.0) * 2.0 - 1.0
		return (saw * 0.65 + randf_range(-1.0, 1.0) * 0.35) * e * 0.42)

	_bank["shield"] = _gen(0.22, func(t):
		var e: float = exp(-t * 14.0)
		var f: float = lerpf(1600.0, 700.0, minf(t / 0.22, 1.0))
		return (sin(TAU * f * t) * 0.6 + randf_range(-1.0, 1.0) * 0.2) * e * 0.3)

	_bank["chain"] = _gen(0.16, func(t):
		var e: float = exp(-t * 22.0)
		return (randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 2400.0 * t) * 0.5) * e * 0.22)

	_bank["warn"] = _gen(0.8, func(t):
		var e: float = 1.0 - minf(t / 0.8, 1.0)
		var f: float = lerpf(90.0, 260.0, minf(t / 0.8, 1.0))
		var wob: float = sin(TAU * 7.0 * t) * 0.5 + 0.5
		return signf(sin(TAU * f * t)) * e * (0.25 + wob * 0.2) * 0.5)

	_bank["select"] = _gen(0.1, func(t):
		var e: float = exp(-t * 24.0)
		return (sin(TAU * 1200.0 * t) * 0.7 + sin(TAU * 2400.0 * t) * 0.3) * e * 0.14)

	_bank["hover"] = _gen(0.06, func(t):
		var e: float = exp(-t * 40.0)
		return sin(TAU * 1800.0 * t) * e * 0.08)

	_bank["gameover"] = _gen(1.2, func(t):
		var e: float = exp(-t * 2.2)
		var f: float = lerpf(300.0, 45.0, minf(t / 1.2, 1.0))
		var saw: float = fmod(f * t, 1.0) * 2.0 - 1.0
		return saw * e * 0.4)

	# ---- 和風 ----
	## 太鼓：低い皮の鳴りと打撃ノイズ
	_bank["taiko"] = _gen(0.55, func(t):
		var e: float = exp(-t * 7.0)
		var f: float = lerpf(120.0, 62.0, minf(t / 0.12, 1.0))
		var skin: float = sin(TAU * f * t)
		var slap: float = randf_range(-1.0, 1.0) * exp(-t * 60.0)
		return (skin * 0.8 + slap * 0.5) * e * 0.7)

	## 拍子木：短く乾いた木の音
	_bank["clap"] = _gen(0.09, func(t):
		var e: float = exp(-t * 60.0)
		return (randf_range(-1.0, 1.0) * 0.4 + sin(TAU * 2600.0 * t) * 0.4
				+ sin(TAU * 3900.0 * t) * 0.2) * e * 0.3)

	## 神楽鈴：小さな鈴が同時に鳴る
	_bank["suzu"] = _gen(0.7, func(t):
		var v: float = 0.0
		v += _bell(t, 2093.0, 6.0)
		v += _bell(maxf(0.0, t - 0.02), 2637.0, 7.0) * 0.7
		v += _bell(maxf(0.0, t - 0.045), 3136.0, 8.0) * 0.5
		return v * 0.12)

	## 龍笛：ビブラートの付いた笛（神招きの合図）
	_bank["flute"] = _gen(1.1, func(t):
		var atk: float = minf(t / 0.12, 1.0)
		var rel: float = 1.0 - clampf((t - 0.75) / 0.35, 0.0, 1.0)
		var vib: float = sin(TAU * 5.5 * t) * 6.0
		var f: float = 1046.5 + vib + (0.0 if t < 0.35 else 174.0)
		var breath: float = randf_range(-1.0, 1.0) * 0.06
		return (sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.15 + breath) * atk * rel * 0.32)

	## 降神：低い唸りと鈴の重なり（神を選んだとき）
	_bank["descend"] = _gen(1.4, func(t):
		var e: float = 1.0 - clampf((t - 0.8) / 0.6, 0.0, 1.0)
		var drone: float = (sin(TAU * 110.0 * t) + sin(TAU * 165.0 * t) * 0.6) * minf(t / 0.3, 1.0)
		var bells: float = _bell(maxf(0.0, t - 0.3), 1568.0, 4.0) + _bell(maxf(0.0, t - 0.55), 2093.0, 4.5)
		return (drone * 0.35 + bells * 0.4) * e * 0.5)

	# ---- 神威ごとの命中音 ----
	_bank["hit_light"] = _gen(0.09, func(t):
		var e: float = exp(-t * 40.0)
		return (sin(TAU * 2200.0 * t) * 0.5 + sin(TAU * 3300.0 * t) * 0.3 + randf_range(-1, 1) * 0.2) * e * 0.2)

	_bank["hit_thunder"] = _gen(0.14, func(t):
		var e: float = exp(-t * 24.0)
		var crack: float = randf_range(-1.0, 1.0) * exp(-t * 90.0)
		return (crack * 0.8 + randf_range(-1.0, 1.0) * 0.3 + sin(TAU * 180.0 * t) * 0.4) * e * 0.3)

	_bank["hit_storm"] = _gen(0.18, func(t):
		var e: float = exp(-t * 16.0)
		var f: float = lerpf(700.0, 180.0, minf(t / 0.18, 1.0))
		return (randf_range(-1.0, 1.0) * 0.6 + sin(TAU * f * t) * 0.4) * e * 0.3)

	_bank["hit_ice"] = _gen(0.16, func(t):
		var e: float = exp(-t * 20.0)
		return (_bell(t, 2960.0, 30.0) * 0.6 + randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.5) * e * 0.22)

	_bank["doom"] = _gen(0.3, func(t):
		var e: float = exp(-t * 12.0)
		var f: float = lerpf(90.0, 40.0, minf(t / 0.3, 1.0))
		return (sin(TAU * f * t) * 0.8 + randf_range(-1.0, 1.0) * 0.35) * e * 0.5)

	_bank["charm"] = _gen(0.35, func(t):
		var e: float = exp(-t * 7.0)
		var f: float = 880.0 + sin(TAU * 9.0 * t) * 60.0
		return (sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.5 * t) * 0.3) * e * 0.2)

	_bank["deflect"] = _gen(0.14, func(t):
		var e: float = exp(-t * 26.0)
		var f: float = lerpf(900.0, 2200.0, minf(t / 0.14, 1.0))
		return (sin(TAU * f * t) * 0.7 + randf_range(-1, 1) * 0.15) * e * 0.22)

	_bank["fox"] = _gen(0.12, func(t):
		var e: float = exp(-t * 30.0)
		var f: float = lerpf(1900.0, 1200.0, minf(t / 0.12, 1.0))
		return sin(TAU * f * t) * e * 0.14)

	_bank["cast"] = _gen(0.3, func(t):
		var e: float = exp(-t * 9.0)
		var f: float = lerpf(300.0, 1400.0, minf(t / 0.3, 1.0))
		return (sin(TAU * f * t) * 0.6 + sin(TAU * f * 0.5 * t) * 0.3) * e * 0.26)

	_bank["charge"] = _gen(0.5, func(t):
		var k: float = minf(t / 0.5, 1.0)
		var f: float = lerpf(200.0, 1800.0, k * k)
		return sin(TAU * f * t) * k * 0.16)

	_bank["dash"] = _gen(0.16, func(t):
		var e: float = exp(-t * 18.0)
		var f: float = lerpf(500.0, 1300.0, minf(t / 0.16, 1.0))
		return (randf_range(-1.0, 1.0) * 0.4 + sin(TAU * f * t) * 0.4) * e * 0.2)

	_bank["miki"] = _gen(0.5, func(t):
		var e: float = exp(-t * 6.0)
		var f: float = lerpf(500.0, 900.0, minf(t / 0.5, 1.0))
		var bub: float = sin(TAU * f * t) * (0.5 + 0.5 * sin(TAU * 18.0 * t))
		return bub * e * 0.22)
