extends SceneTree

## ゲームデータを JSON に書き出す（Unity 移行用）
##   godot --headless --path . -s tools/dump_data.gd
## 出力: export/data/{kami,boons,curses,relics,growth,enemies,abilities_by_level}.json

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://export/data"))
	_write("kami", Kami.LIST)
	_write("boons", Kami.BOONS)
	_write("curses", Kami.CURSES)
	_write("relics", Relics.LIST)
	_write("growth", Kami.GROWTH)
	_write("enemies", {"names": Enemy.KIND_NAMES, "unlock": Game.UNLOCK, "cost": Game.COST})
	# 能力の Lv ごとの実効値と説明（数式の移植を検証するための正解データ）
	var rows: Array = []
	for b in Kami.BOONS:
		var maxlv := int(b.get("maxlv", 3))
		var rar: int = int(b["tier"]) if b.has("tier") else int(b.get("rar", 0))
		var levels: Array = []
		for lv in range(1, maxlv + 1):
			levels.append({"lv": lv, "value": Kami.value(b, rar, lv), "text": Kami.describe(b, rar, lv)})
		rows.append({"id": String(b["id"]), "rar": rar, "levels": levels})
	_write("abilities_by_level", rows)
	print("wrote export/data/*.json")
	quit()


func _write(name: String, data) -> void:
	var f := FileAccess.open("res://export/data/%s.json" % name, FileAccess.WRITE)
	f.store_string(JSON.stringify(_plain(data), "  ", false))
	f.close()


## Color など JSON にならない型を素の値へ
func _plain(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			for k in v.keys():
				d[String(k)] = _plain(v[k])
			return d
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_COLOR:
			return [snappedf(v.r, 0.001), snappedf(v.g, 0.001), snappedf(v.b, 0.001), snappedf(v.a, 0.001)]
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_CALLABLE:
			return null
		_:
			return v
