using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Networking;

namespace Kagura.Game
{
    /// <summary>
    /// 世界のランキング（Supabase の REST）。Resources/supabase.json に url と anon_key があるときだけ動く。
    /// anon は insert / update / select のみ（RLS）。Godot 版 net.gd の移植。
    /// </summary>
    public class Net : MonoBehaviour
    {
        public static Net I;
        public string url = "", key = "";

        [Serializable] private class Cfg { public string url; public string anon_key; }

        public static Net Create(Transform parent)
        {
            var go = new GameObject("net");
            go.transform.SetParent(parent, false);
            var n = go.AddComponent<Net>();
            I = n;
            var ta = Resources.Load<TextAsset>("supabase");
            if (ta != null)
            {
                try { var c = JsonConvert.DeserializeObject<Cfg>(ta.text); n.url = (c.url ?? "").TrimEnd('/'); n.key = c.anon_key ?? ""; }
                catch (Exception e) { Debug.LogWarning("[Kagura] supabase.json: " + e.Message); }
            }
            return n;
        }

        public bool Configured => url != "" && key != "";

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")] private static extern string KaguraPrompt(string msg, string def);
        [DllImport("__Internal")] private static extern string KaguraUserAgent();
        [DllImport("__Internal")] private static extern int KaguraTouchPoints();
        public static bool HasTouch() { try { return KaguraTouchPoints() > 0; } catch { return false; } }
        public static string UserAgent() { try { return KaguraUserAgent() ?? ""; } catch { return ""; } }
        /// <summary>ブラウザの入力ダイアログ。取り消しなら null。</summary>
        public static string Prompt(string msg, string def)
        {
            try { var r = KaguraPrompt(msg, def ?? ""); return r == null || r.StartsWith("cancel") ? null : r; }
            catch { return null; }
        }
#else
        public static string UserAgent() => "";
        public static bool HasTouch() => Application.isMobilePlatform;
        public static string Prompt(string msg, string def) => null;
#endif

        private IEnumerator Request(string path, string method, string body, Dictionary<string, string> extra, Action<bool, long, string, string> cb)
        {
            if (!Configured) { cb(false, 0, null, ""); yield break; }
            using (var req = new UnityWebRequest(url + path, method))
            {
                req.timeout = 12;
                if (!string.IsNullOrEmpty(body)) req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(body));
                req.downloadHandler = new DownloadHandlerBuffer();
                req.SetRequestHeader("apikey", key);
                req.SetRequestHeader("Authorization", "Bearer " + key);
                req.SetRequestHeader("Content-Type", "application/json");
                req.SetRequestHeader("Accept", "application/json");
                if (extra != null) foreach (var kv in extra) req.SetRequestHeader(kv.Key, kv.Value);
                yield return req.SendWebRequest();
                long code = req.responseCode;
                bool ok = req.result == UnityWebRequest.Result.Success && code >= 200 && code < 300;
                string range = req.GetResponseHeader("content-range") ?? req.GetResponseHeader("Content-Range") ?? "";
                cb(ok, code, req.downloadHandler != null ? req.downloadHandler.text : "", range);
            }
        }

        /// <summary>記録を送る（同じ run_id があれば置き換える）。</summary>
        public void Submit(Records.Entry e, Action<bool> cb)
        {
            if (!BuildInfo.CanSubmit) { cb(false); return; }
            var boons = new JObject();
            foreach (var kv in e.BoonMap()) boons[kv.Key] = new JObject { ["lv"] = kv.Value.lv, ["rar"] = kv.Value.rar };
            var kamiLv = new JObject();
            foreach (var kv in e.KamiLvMap()) kamiLv[kv.Key] = kv.Value;
            var row = new JObject
            {
                ["run_id"] = string.IsNullOrEmpty(e.runKey) ? e.run.ToString() : e.runKey,
                ["name"] = e.name.Length > 16 ? e.name.Substring(0, 16) : e.name,
                ["score"] = e.score, ["wave"] = e.wave, ["stage"] = e.stage, ["level"] = e.lv,
                ["cleared"] = e.cleared, ["endless"] = e.endless,
                ["version"] = e.version, ["commit"] = e.commit, ["build_time"] = e.buildTime, ["platform"] = e.platform,
                ["familiar"] = e.familiar,
                ["gods"] = new JArray(e.GodList()), ["kami_lv"] = kamiLv, ["relics"] = new JArray(e.RelicList()),
                ["boons"] = boons, ["curses"] = new JArray(e.CurseList()), ["duration"] = e.duration,
            };
            StartCoroutine(Request("/rest/v1/scores?on_conflict=run_id", "POST", row.ToString(Formatting.None),
                new Dictionary<string, string> { { "Prefer", "resolution=merge-duplicates,return=minimal" } },
                (ok, code, body, range) => { if (!ok) Debug.LogWarning("[Kagura] submit failed " + code + " " + body); cb(ok); }));
        }

        /// <summary>上位の記録。</summary>
        public void FetchTop(int limit, Action<bool, List<Records.Entry>> cb)
        {
            StartCoroutine(Request("/rest/v1/scores?select=*&order=score.desc,created_at.asc&limit=" + limit, "GET", null, null,
                (ok, code, body, range) =>
                {
                    var rows = new List<Records.Entry>();
                    if (ok)
                    {
                        try { foreach (var r in JArray.Parse(body)) if (r is JObject o) rows.Add(FromRemote(o)); }
                        catch (Exception ex) { Debug.LogWarning("[Kagura] ranking parse: " + ex.Message); ok = false; }
                    }
                    cb(ok, rows);
                }));
        }

        /// <summary>その功徳が世界で何位か（それより高い記録の数 + 1）。</summary>
        public void FetchRank(int score, Action<bool, int> cb)
        {
            StartCoroutine(Request("/rest/v1/scores?select=id&score=gt." + score, "GET", null,
                new Dictionary<string, string> { { "Prefer", "count=exact" }, { "Range-Unit", "items" }, { "Range", "0-0" } },
                (ok, code, body, range) =>
                {
                    int rank = 0;
                    if (!string.IsNullOrEmpty(range))
                    {
                        int slash = range.IndexOf('/');
                        if (slash >= 0 && int.TryParse(range.Substring(slash + 1).Trim(), out var total)) rank = total + 1;
                    }
                    cb(ok && rank > 0, rank);
                }));
        }

        /// <summary>世界の行を端末の記録と同じ形にする。</summary>
        private static Records.Entry FromRemote(JObject r)
        {
            string date = (string)r["created_at"] ?? "";
            if (date.Length >= 10) date = date.Substring(0, 10).Replace("-", "/");
            var e = new Records.Entry
            {
                name = (string)r["name"] ?? "", score = (int?)r["score"] ?? 0, wave = (int?)r["wave"] ?? 0, stage = (int?)r["stage"] ?? 1, lv = (int?)r["level"] ?? 1,
                cleared = (bool?)r["cleared"] ?? false, endless = (bool?)r["endless"] ?? false, date = date,
                version = (string)r["version"] ?? "", commit = (string)r["commit"] ?? "", buildTime = (string)r["build_time"] ?? "", platform = (string)r["platform"] ?? "",
                familiar = (string)r["familiar"] ?? "", duration = (float?)r["duration"] ?? 0f, runKey = (string)r["run_id"] ?? "",
            };
            if (r["gods"] is JArray ga) e.gods = string.Join(",", ga.Select(x => (string)x));
            if (r["relics"] is JArray ra) e.relics = string.Join(",", ra.Select(x => (string)x));
            if (r["curses"] is JArray ca) e.curses = string.Join(",", ca.Select(x => (string)x));
            if (r["kami_lv"] is JObject ko) e.kamiLv = string.Join(",", ko.Properties().Select(p => p.Name + ":" + ((int?)p.Value ?? 1)));
            if (r["boons"] is JObject bo) e.boons = string.Join(",", bo.Properties().Select(p => p.Name + ":" + ((int?)p.Value["lv"] ?? 1) + ":" + ((int?)p.Value["rar"] ?? 0)));
            return e;
        }
    }
}
