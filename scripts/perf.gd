class_name Perf
## 処理時間の内訳（--perf のとき autoplay が集計して表示）。
## 各 _process/_draw を包んで、系ごとの usec を足し込む。

static var on := false
static var acc: Dictionary = {}


static func add(key: String, t0: int) -> void:
	if not on:
		return
	acc[key] = int(acc.get(key, 0)) + (Time.get_ticks_usec() - t0)


static func report(frames: int) -> String:
	if frames <= 0 or acc.is_empty():
		return ""
	var parts: PackedStringArray = []
	var keys := acc.keys()
	keys.sort_custom(func(a, b): return int(acc[a]) > int(acc[b]))
	for k in keys:
		parts.append("%s=%.2f" % [k, float(acc[k]) / float(frames) / 1000.0])
	acc.clear()
	return " ".join(parts)
