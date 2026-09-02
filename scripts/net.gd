class_name Net
extends Node

## 世界のランキング（Supabase の REST）。res://supabase.cfg に url と anon_key があるときだけ動く。
## テーブル scores は README の SQL で作る。anon は insert と select のみ（RLS）。

static var inst: Net
var url := ""
var key := ""


func _ready() -> void:
	inst = self
	var cf := ConfigFile.new()
	if cf.load("res://supabase.cfg") == OK:
		url = String(cf.get_value("supabase", "url", "")).trim_suffix("/")
		key = String(cf.get_value("supabase", "anon_key", ""))


func configured() -> bool:
	return url != "" and key != ""


func _headers(extra: Array = []) -> PackedStringArray:
	var h := PackedStringArray(["apikey: " + key, "Authorization: Bearer " + key, "Content-Type: application/json", "Accept: application/json"])
	for e in extra:
		h.append(String(e))
	return h


var _js_ready := false
var _js_cbs := {}   # id -> {"js": JavaScriptObject, "cb": Callable}
var _js_seq := 0


## Web 版：ブラウザの fetch を使う（Godot の HTTPRequest はブラウザが展開済みの gzip を再展開して失敗する）
func _js_request(path: String, method: int, body: String, extra_headers: Array, cb: Callable) -> void:
	if not _js_ready:
		_js_ready = true
		JavaScriptBridge.eval("""
window.kaguraFetch = function(url, method, headersJson, body, cb) {
  var opt = {method: method, headers: JSON.parse(headersJson)};
  if (body && body.length > 0) opt.body = body;
  fetch(url, opt).then(function(r) {
    return r.text().then(function(t) { cb(r.status, t, r.headers.get('content-range') || ''); });
  }).catch(function(e) { cb(0, String(e), ''); });
};""", true)
	var hd := {}
	for h in _headers(extra_headers):
		var hs := String(h)
		var i := hs.find(":")
		if i > 0:
			hd[hs.substr(0, i).strip_edges()] = hs.substr(i + 1).strip_edges()
	_js_seq += 1
	var id := _js_seq
	var js_cb := JavaScriptBridge.create_callback(func(args: Array):
		var code := int(args[0]) if args.size() > 0 else 0
		var txt := String(args[1]) if args.size() > 1 else ""
		var range_h := String(args[2]) if args.size() > 2 else ""
		var parsed: Variant = null
		if txt != "":
			var j := JSON.new()
			if j.parse(txt) == OK:
				parsed = j.data
		var headers := PackedStringArray()
		if range_h != "":
			headers.append("content-range: " + range_h)
		_js_cbs.erase(id)
		cb.call(code >= 200 and code < 300, code, parsed, headers))
	_js_cbs[id] = {"js": js_cb, "cb": cb}
	var mname := "GET"
	match method:
		HTTPClient.METHOD_POST: mname = "POST"
		HTTPClient.METHOD_PATCH: mname = "PATCH"
		HTTPClient.METHOD_DELETE: mname = "DELETE"
	var win := JavaScriptBridge.get_interface("window")
	win.kaguraFetch(url + path, mname, JSON.stringify(hd), body, js_cb)


## 汎用リクエスト。cb(ok: bool, code: int, body: Variant, headers: PackedStringArray)
func _request(path: String, method: int, body: String, extra_headers: Array, cb: Callable) -> void:
	if not configured():
		cb.call(false, 0, null, PackedStringArray())
		return
	if OS.has_feature("web"):
		_js_request(path, method, body, extra_headers, cb)
		return
	var r := HTTPRequest.new()
	r.timeout = 12.0
	# Web 版ではブラウザが gzip を展開済みなのに Godot がもう一度展開しようとして失敗する。展開は任せない
	r.accept_gzip = false
	add_child(r)
	r.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, raw: PackedByteArray):
		var parsed: Variant = null
		if raw.size() > 0:
			var txt := raw.get_string_from_utf8()
			var j := JSON.new()
			if j.parse(txt) == OK:
				parsed = j.data
		var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		cb.call(ok, code, parsed, headers)
		r.queue_free())
	var err := r.request(url + path, _headers(extra_headers), method, body)
	if err != OK:
		cb.call(false, 0, null, PackedStringArray())
		r.queue_free()


## 記録を送る（同じ run_id があれば置き換える）。cb(ok)
## 手元の開発ビルド（version が dev）や自動テストからは送らない
func submit(entry: Dictionary, cb: Callable) -> void:
	BuildInfo.load_info()
	if BuildInfo.version == "dev" or OS.get_cmdline_user_args().has("--capture"):
		cb.call(false)
		return
	var row := {
		"run_id": String(entry.get("run_key", str(entry.get("run", 0)))),
		"name": String(entry.get("name", "")).left(16),
		"score": int(entry.get("score", 0)),
		"wave": int(entry.get("wave", 0)),
		"stage": int(entry.get("stage", 1)),
		"level": int(entry.get("lv", 1)),
		"cleared": bool(entry.get("cleared", false)),
		"endless": bool(entry.get("endless", false)),
		"version": String(entry.get("version", "dev")),
		"commit": String(entry.get("commit", "")),
		"build_time": String(entry.get("build_time", "")),
		"platform": String(entry.get("platform", "")),
		"familiar": String(entry.get("familiar", "")),
		"gods": entry.get("gods", []),
		"kami_lv": entry.get("kami_lv", {}),
		"relics": entry.get("relics", []),
		"boons": entry.get("boons", {}),
		"curses": entry.get("curses", []),
		"duration": float(entry.get("duration", 0.0)),
	}
	_request("/rest/v1/scores?on_conflict=run_id", HTTPClient.METHOD_POST, JSON.stringify(row),
			["Prefer: resolution=merge-duplicates,return=minimal"],
			func(ok: bool, _code: int, _body: Variant, _h: PackedStringArray): cb.call(ok))


## 上位の記録。cb(ok, rows: Array)
func fetch_top(limit: int, cb: Callable) -> void:
	_request("/rest/v1/scores?select=*&order=score.desc,created_at.asc&limit=%d" % limit, HTTPClient.METHOD_GET, "", [],
			func(ok: bool, _code: int, body: Variant, _h: PackedStringArray):
				cb.call(ok and body is Array, body if body is Array else []))


## その功徳が世界で何位か（それより高い記録の数 + 1）。cb(ok, rank)
func fetch_rank(score: int, cb: Callable) -> void:
	_request("/rest/v1/scores?select=id&score=gt.%d" % score, HTTPClient.METHOD_GET, "",
			["Prefer: count=exact", "Range-Unit: items", "Range: 0-0"],
			func(ok: bool, _code: int, _body: Variant, headers: PackedStringArray):
				var rank := 0
				for h in headers:
					var hs := String(h)
					if hs.to_lower().begins_with("content-range:"):
						var total := hs.get_slice("/", 1).strip_edges()
						if total.is_valid_int():
							rank = int(total) + 1
				cb.call(ok and rank > 0, rank))
