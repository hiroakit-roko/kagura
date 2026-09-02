class_name Music
extends Node

## BGM の管理。ステージ曲とボス曲を 2 本のプレイヤーでクロスフェードする。
## 長い曲をメモリに展開しないよう、再生方式はストリームにしておく（Web の Sample 方式を避ける）。

static var inst: Music

const TRACKS := {
	"stage": "res://music/stage.mp3",
	"boss": "res://music/boss.mp3",
	"lastboss": "res://music/lastboss.mp3",
}
const BASE_DB := -9.0
const FADE := 1.6          # クロスフェードの秒数

var muted := false
var _players := {}          # name -> AudioStreamPlayer
var _target := {}           # name -> 目標音量(0..1)
var _level := {}            # name -> 現在音量(0..1)
var _current := ""


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in TRACKS.keys():
		var p := AudioStreamPlayer.new()
		var s = load(TRACKS[name])
		if s != null:
			if "loop" in s:
				s.loop = true
			p.stream = s
		p.bus = "Master"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		p.volume_db = -80.0
		add_child(p)
		_players[name] = p
		_target[name] = 0.0
		_level[name] = 0.0


func _process(delta: float) -> void:
	for name in _players.keys():
		var p: AudioStreamPlayer = _players[name]
		var tgt: float = 0.0 if muted else float(_target[name])
		var cur: float = float(_level[name])
		cur = move_toward(cur, tgt, delta / FADE)
		_level[name] = cur
		if cur <= 0.001:
			if p.playing and tgt <= 0.0:
				p.stop()
			continue
		if not p.playing and p.stream != null:
			p.play()
		# 0..1 を dB に（対数で自然なフェード）
		p.volume_db = BASE_DB + linear_to_db(maxf(cur, 0.001))


static func play(name: String) -> void:
	if inst == null or not inst._players.has(name):
		return
	if inst._current == name:
		return
	inst._current = name
	for k in inst._target.keys():
		inst._target[k] = 1.0 if k == name else 0.0


static func stop() -> void:
	if inst == null:
		return
	inst._current = ""
	for k in inst._target.keys():
		inst._target[k] = 0.0


static func set_muted(m: bool) -> void:
	if inst != null:
		inst.muted = m
