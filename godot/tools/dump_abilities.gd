extends SceneTree

## 全能力の一覧を docs/abilities.md に書き出す（数値は Lv ごとの実効値）
##   godot --headless --path . -s tools/dump_abilities.gd

func _init() -> void:
	var out: Array = []
	out.append("# 神楽 -KAGURA ASCENT- 能力一覧")
	out.append("")
	out.append("自動生成：`godot --headless --path . -s tools/dump_abilities.gd`。「威力 N%」は 基礎攻撃 × 神格倍率 に対する割合。")
	out.append("")
	for k in Kami.LIST:
		var kid := String(k["id"])
		out.append("## %s（%s）— 神器 %s　神格の伸び +%d%%/段" % [String(k["name"]), String(k["kana"]), String(k["weapon"]), int(round(Kami.growth_of(kid) * 100.0))])
		out.append("")
		out.append("- 神器：%s" % String(k["weapon_desc"]))
		out.append("- 神威：%s — %s" % [String(k["status"]), String(k["status_desc"])])
		out.append("- 詠唱：%s — %s" % [String(k["cast"]), String(k["cast_desc"])])
		out.append("- 神招き：%s — %s" % [String(k["call"]), String(k["call_desc"])])
		out.append("- 代償：%s" % String(k["cost"]))
		out.append("")
		out.append("| 格 | 能力 | 最大Lv | Lv1 | Lv2 | Lv3 | Lv4 |")
		out.append("|---|---|---|---|---|---|---|")
		var ups := Kami.upgrades_of(kid)
		ups.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]))
		for b in ups:
			var maxlv := int(b.get("maxlv", 3))
			var cells: Array = []
			for lv in range(1, 5):
				cells.append(Kami.describe(b, int(b["tier"]), lv) if lv <= maxlv else "-")
			out.append("| %s | **%s** | %d | %s | %s | %s | %s |" % [Cfg.RAR_NAME[int(b["tier"])], String(b["name"]), maxlv, cells[0], cells[1], cells[2], cells[3]])
		var leg := Kami.legendary_of(kid)
		if not leg.is_empty():
			out.append("| 伝 | **%s**（主神のみ・能力 2 つ以上） | %d | %s | %s | - | - |" % [String(leg["name"]), int(leg.get("maxlv", 2)), Kami.describe(leg, Cfg.Rar.LEGENDARY, 1), Kami.describe(leg, Cfg.Rar.LEGENDARY, 2)])
		out.append("")
	out.append("## 双神（2 柱を迎え、それぞれの能力を 1 つ以上持つと出る）")
	out.append("")
	out.append("| 組 | 名 | Lv1 | Lv2 |")
	out.append("|---|---|---|---|")
	for b in Kami.BOONS:
		if b.has("kami2"):
			out.append("| %s × %s | **%s** | %s | %s |" % [String(Kami.kami(String(b["kami"]))["name"]), String(Kami.kami(String(b["kami2"]))["name"]), String(b["name"]), Kami.describe(b, Cfg.Rar.DUO, 1), Kami.describe(b, Cfg.Rar.DUO, 2)])
	out.append("")
	out.append("## 禍神の取引（第 4 波以降に稀に。取り消せない）")
	out.append("")
	out.append("| 名 | 得 | 失 |")
	out.append("|---|---|---|")
	for c in Kami.CURSES:
		out.append("| **%s** | %s | %s |" % [String(c["name"]), String(c["gain"]), String(c["loss"])])
	out.append("")
	out.append("## 神宝（ボス撃破の褒賞。3 択、重複なし）")
	out.append("")
	out.append("| 名 | 効果 |")
	out.append("|---|---|")
	for r in Relics.LIST:
		out.append("| **%s** | %s |" % [String(r["name"]), String(r["desc"])])
	out.append("")
	out.append("## 使い魔")
	out.append("")
	for f in Familiar.LIST:
		out.append("- **%s**（%s）：%s　加護：%s" % [String(f["name"]), String(f["role"]), String(f["desc"]), String(f["passive"])])
	out.append("")
	var fa := FileAccess.open("res://docs/abilities.md", FileAccess.WRITE)
	fa.store_string("\n".join(out))
	fa.close()
	print("wrote docs/abilities.md (%d lines)" % out.size())
	quit()
