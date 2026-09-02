class_name Records
extends RefCounted

## 記録の永続化（名前・最高記録・上位 10 件の履歴）。
## 保存先は user://save.cfg。Web 版ではブラウザの IndexedDB に置かれ、同じ端末・同じブラウザなら
## 次回も残る（GitHub Pages のような静的配信でも動く）。他の端末や他のプレイヤーとは共有されない。

const PATH := "user://save.cfg"
const MAX_ENTRIES := 10

static var player_name := ""
static var best := {"score": 0, "wave": 0, "clears": 0}
## 各要素：{run, run_key, name, score, wave, stage, lv, gods(Array), kami_lv, relics, boons, familiar,
##          cleared(bool), endless(bool), date, version, commit, build_time, platform, duration}
static var entries: Array = []
static var last_entry := {}
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	player_name = String(cf.get_value("player", "name", ""))
	best["score"] = int(cf.get_value("best", "score", 0))
	best["wave"] = int(cf.get_value("best", "wave", 0))
	best["clears"] = int(cf.get_value("best", "clears", 0))
	var arr: Array = cf.get_value("records", "entries", [])
	entries = []
	for e in arr:
		if e is Dictionary:
			entries.append(e)
	_sort()


static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("best", "score", int(best["score"]))
	cf.set_value("best", "wave", int(best["wave"]))
	cf.set_value("best", "clears", int(best["clears"]))
	cf.set_value("records", "entries", entries)
	cf.save(PATH)


static func display_name() -> String:
	return player_name if player_name.strip_edges() != "" else "名無しの巫女"


static func set_player_name(n: String, run_id: int = -1) -> void:
	player_name = n.strip_edges().left(10)
	# 今回の走りの記録にも名前を反映する
	if run_id >= 0:
		for e in entries:
			if int(e.get("run", -2)) == run_id:
				e["name"] = display_name()
	save_all()


## 今回の走りを記録する。同じ run の記録があれば置き換える（踏破 → 祟りの参道で倒れた場合）。
## 戻り値は順位（1〜MAX_ENTRIES）。上位に入らなければ 0
static func record(run_id: int, score: int, wave: int, lv: int, gods: Array, cleared: bool, endless: bool, extra := {}) -> int:
	best["score"] = maxi(int(best["score"]), score)
	best["wave"] = maxi(int(best["wave"]), wave)
	var prev_cleared := false
	for i in range(entries.size() - 1, -1, -1):
		if int(entries[i].get("run", -2)) == run_id:
			prev_cleared = bool(entries[i].get("cleared", false))
			entries.remove_at(i)
	if cleared and not prev_cleared:
		best["clears"] = int(best["clears"]) + 1
	BuildInfo.load_info()
	var e := {
		"run": run_id, "run_key": String(extra.get("run_key", str(run_id))), "name": display_name(), "score": score, "wave": wave,
		"stage": Cfg.stage_of(maxi(wave, 1)), "lv": lv, "gods": gods.duplicate(),
		"kami_lv": extra.get("kami_lv", {}), "relics": extra.get("relics", []), "boons": extra.get("boons", []),
		"familiar": String(extra.get("familiar", "")), "duration": float(extra.get("duration", 0.0)),
		"cleared": cleared or prev_cleared, "endless": endless,
		"date": Time.get_date_string_from_system().replace("-", "/"),
		"version": BuildInfo.version, "commit": BuildInfo.commit, "build_time": BuildInfo.time, "platform": BuildInfo.platform(),
	}
	last_entry = e
	entries.append(e)
	_sort()
	var rank := 0
	for i in entries.size():
		if int(entries[i].get("run", -2)) == run_id:
			rank = i + 1
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	if rank > MAX_ENTRIES:
		rank = 0
	save_all()
	return rank


static func _sort() -> void:
	entries.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["wave"]) > int(b["wave"]))


static func gods_text(e: Dictionary) -> String:
	var names: Array = []
	for g in e.get("gods", []):
		var k := Kami.kami(String(g))
		if not k.is_empty():
			names.append(String(k["name"]).left(2))
	return "・".join(names) if not names.is_empty() else "神なし"


static func reach_text(e: Dictionary) -> String:
	if bool(e.get("cleared", false)):
		return "踏破" + ("（祟り 第 %d 波）" % int(e["wave"]) if bool(e.get("endless", false)) else "")
	return "第 %d 波" % int(e["wave"])
