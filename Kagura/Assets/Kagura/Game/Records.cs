using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>この端末の記録（Godot 版 records.gd）。PlayerPrefs に JSON で保存。</summary>
    public static class Records
    {
        [Serializable]
        public class Entry
        {
            public int run; public string runKey = ""; public string name = ""; public int score, wave, stage = 1, lv; public string gods = ""; public bool cleared, endless; public string date = "";
            public string boons = "";    // id:lv:rar,…（禍は含めない）
            public string kamiLv = "";   // id:lv,…
            public string curses = "";   // id,…
            public string relics = ""; public string familiar = ""; public float duration;
            public string version = "", commit = "", buildTime = "", platform = "";

            public List<string> GodList() => string.IsNullOrEmpty(gods) ? new List<string>() : gods.Split(',').Select(s => s.Trim()).Where(s => s != "").ToList();
            public List<string> RelicList() => string.IsNullOrEmpty(relics) ? new List<string>() : relics.Split(',').Select(s => s.Trim()).Where(s => s != "").ToList();
            public List<string> CurseList() => string.IsNullOrEmpty(curses) ? new List<string>() : curses.Split(',').Select(s => s.Trim()).Where(s => s != "").ToList();
            public Dictionary<string, int> KamiLvMap()
            {
                var d = new Dictionary<string, int>();
                if (string.IsNullOrEmpty(kamiLv)) return d;
                foreach (var p in kamiLv.Split(',')) { var kv = p.Split(':'); if (kv.Length >= 2 && int.TryParse(kv[1], out var v)) d[kv[0].Trim()] = v; }
                return d;
            }
            /// <summary>id → (lv, rar)</summary>
            public Dictionary<string, (int lv, int rar)> BoonMap()
            {
                var d = new Dictionary<string, (int, int)>();
                if (string.IsNullOrEmpty(boons)) return d;
                foreach (var p in boons.Split(','))
                {
                    var kv = p.Split(':');
                    if (kv.Length >= 3 && int.TryParse(kv[1], out var lv) && int.TryParse(kv[2], out var rar)) d[kv[0].Trim()] = (lv, rar);
                    else if (kv.Length >= 1 && kv[0].Trim() != "") d[kv[0].Trim()] = (1, 0);
                }
                return d;
            }
        }
        public class BestInfo { public int score, wave, clears; }

        private static List<Entry> _entries;
        private static BestInfo _best;
        private static string _name;
        public static Entry LastEntry;
        public const int Max = 10;

        public static List<Entry> Entries { get { Load(); return _entries; } }
        public static BestInfo Best { get { Load(); return _best; } }
        public static string PlayerName { get { Load(); return _name; } }
        public static string DisplayName() => PlayerName.Trim() == "" ? "名無しの巫女" : PlayerName.Trim();

        private static void Load()
        {
            if (_entries != null) return;
            try
            {
                _entries = JsonConvert.DeserializeObject<List<Entry>>(PlayerPrefs.GetString("kagura.records", "[]")) ?? new List<Entry>();
                _best = JsonConvert.DeserializeObject<BestInfo>(PlayerPrefs.GetString("kagura.best", "{}")) ?? new BestInfo();
                _name = PlayerPrefs.GetString("kagura.name", "");
            }
            catch { _entries = new List<Entry>(); _best = new BestInfo(); _name = ""; }
        }

        private static void Save()
        {
            PlayerPrefs.SetString("kagura.records", JsonConvert.SerializeObject(_entries));
            PlayerPrefs.SetString("kagura.best", JsonConvert.SerializeObject(_best));
            PlayerPrefs.SetString("kagura.name", _name);
            PlayerPrefs.Save();
        }

        /// <summary>名を刻む（10 文字まで）。run_id を渡すとその記録の名前も差し替える。</summary>
        public static void SetPlayerName(string n, int runId = -1)
        {
            Load();
            n = (n ?? "").Trim();
            if (n.Length > 10) n = n.Substring(0, 10);
            _name = n;
            if (runId >= 0) foreach (var e in _entries) if (e.run == runId) e.name = DisplayName();
            if (LastEntry != null && LastEntry.run == runId) LastEntry.name = DisplayName();
            Save();
        }

        /// <summary>今回の走りを記録し、順位（1 始まり、0 なら圏外）を返す。同じ run は置き換える。</summary>
        public static int Record(Entry e)
        {
            Load();
            _entries.RemoveAll(x => x.run == e.run);
            e.name = DisplayName();
            e.date = DateTime.Now.ToString("yyyy/MM/dd");
            e.version = BuildInfo.Version; e.commit = BuildInfo.Commit; e.buildTime = BuildInfo.BuildTime; e.platform = BuildInfo.Platform;
            LastEntry = e;
            _entries.Add(e);
            _entries = _entries.OrderByDescending(x => x.score).ToList();
            if (_entries.Count > Max) _entries = _entries.Take(Max).ToList();
            _best.score = Math.Max(_best.score, e.score);
            _best.wave = Math.Max(_best.wave, e.wave);
            if (e.cleared) _best.clears++;
            Save();
            int idx = _entries.FindIndex(x => x.run == e.run);
            return idx >= 0 ? idx + 1 : 0;
        }

        public static string ReachText(Entry e)
        {
            if (e.cleared) return e.endless ? $"祟り{e.wave}波" : "踏破";
            return $"第{e.wave}波";
        }

        public static string GodsText(Entry e)
        {
            var names = new List<string>();
            foreach (var id in e.GodList()) { var k = Data.KamiOf(id); if (k != null) names.Add(k.name.Length >= 2 ? k.name.Substring(0, 2) : k.name); }
            return names.Count > 0 ? string.Join("・", names) : "神なし";
        }
    }

    /// <summary>ビルドの版（Resources/version.txt：版・短い SHA・日時）。無ければ dev。</summary>
    public static class BuildInfo
    {
        private static bool _loaded;
        private static string _version = "dev", _commit = "", _time = "";
        public static string Version { get { Load(); return _version; } }
        public static string Commit { get { Load(); return _commit; } }
        public static string BuildTime { get { Load(); return _time; } }
        public static string Platform
        {
            get
            {
#if UNITY_WEBGL && !UNITY_EDITOR
                string ua = Net.UserAgent();
                if (ua.Contains("iPhone") || ua.Contains("iPad")) return "web-ios";
                if (ua.Contains("Android")) return "web-android";
                return "web";
#elif UNITY_IOS
                return "ios";
#elif UNITY_EDITOR
                return "editor";
#else
                return Application.platform.ToString().ToLower();
#endif
            }
        }
        /// <summary>手元の開発ビルドからは世界に送らない。</summary>
        public static bool CanSubmit => Version != "dev" && !Application.isEditor;

        private static void Load()
        {
            if (_loaded) return;
            _loaded = true;
            var ta = Resources.Load<TextAsset>("version");
            if (ta == null) return;
            var lines = ta.text.Split('\n');
            if (lines.Length > 0 && lines[0].Trim() != "") _version = lines[0].Trim().TrimStart('v');
            if (lines.Length > 1) _commit = lines[1].Trim();
            if (lines.Length > 2) _time = lines[2].Trim();
        }
    }
}
