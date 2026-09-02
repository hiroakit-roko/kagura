class_name BuildInfo
extends RefCounted

## ビルドの版と由来。res://build.cfg を読む（デプロイ時に GitHub Actions が書き換える）

static var version := "dev"
static var commit := "local"
static var time := ""
static var _loaded := false


static func load_info() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load("res://build.cfg") == OK:
		version = String(cf.get_value("build", "version", "dev"))
		commit = String(cf.get_value("build", "commit", "local"))
		time = String(cf.get_value("build", "time", ""))


static func label() -> String:
	load_info()
	return "v%s (%s)" % [version, commit]


static func platform() -> String:
	if OS.has_feature("web"):
		return "web-touch" if (Game.inst != null and Game.inst.is_touch()) else "web"
	return OS.get_name().to_lower()
