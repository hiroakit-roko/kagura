using System.Collections.Generic;
using Newtonsoft.Json;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>ゲームデータ（神・能力・神宝・禍）。Resources/Data の JSON（Godot 版から書き出した正本）を読む。</summary>
    public static class Data
    {
        private static List<KamiDef> _kami;
        private static List<BoonDef> _boons;
        private static List<RelicDef> _relics;
        private static List<ShopItemDef> _shopItems;
        private static List<CurseDef> _curses;
        private static readonly Dictionary<string, KamiDef> _kamiById = new Dictionary<string, KamiDef>();
        private static readonly Dictionary<string, BoonDef> _boonById = new Dictionary<string, BoonDef>();
        private static readonly Dictionary<string, RelicDef> _relicById = new Dictionary<string, RelicDef>();
        private static readonly Dictionary<string, CurseDef> _curseById = new Dictionary<string, CurseDef>();
        private static readonly Dictionary<string, Color> _colors = new Dictionary<string, Color>();

        public static List<KamiDef> Kami { get { Load(); return _kami; } }
        public static List<BoonDef> Boons { get { Load(); return _boons; } }
        public static List<RelicDef> Relics { get { Load(); return _relics; } }
        public static List<ShopItemDef> ShopItems { get { Load(); return _shopItems; } }
        public static List<CurseDef> Curses { get { Load(); return _curses; } }

        private static T Read<T>(string name)
        {
            var ta = Resources.Load<TextAsset>("Data/" + name);
            if (ta == null) { Debug.LogError("[Kagura] data not found: " + name); return default; }
            return JsonConvert.DeserializeObject<T>(ta.text);
        }

        private static void Load()
        {
            if (_kami != null) return;
            _kami = Read<List<KamiDef>>("kami") ?? new List<KamiDef>();
            _boons = Read<List<BoonDef>>("boons") ?? new List<BoonDef>();
            _relics = Read<List<RelicDef>>("relics") ?? new List<RelicDef>();
            _shopItems = Read<List<ShopItemDef>>("shop_items") ?? new List<ShopItemDef>();
            _curses = Read<List<CurseDef>>("curses") ?? new List<CurseDef>();
            foreach (var k in _kami) _kamiById[k.id] = k;
            foreach (var b in _boons) _boonById[b.id] = b;
            foreach (var r in _relics) _relicById[r.id] = r;
            foreach (var c in _curses) _curseById[c.id] = c;
        }

        public static KamiDef KamiOf(string id) { Load(); return id != null && _kamiById.TryGetValue(id, out var k) ? k : null; }
        public static BoonDef Boon(string id) { Load(); return id != null && _boonById.TryGetValue(id, out var b) ? b : null; }
        public static RelicDef Relic(string id) { Load(); return id != null && _relicById.TryGetValue(id, out var r) ? r : null; }
        public static CurseDef Curse(string id) { Load(); return id != null && _curseById.TryGetValue(id, out var c) ? c : null; }

        public static Color ColorOf(float[] c) => c != null && c.Length >= 3 ? new Color(c[0], c[1], c[2], c.Length > 3 ? c[3] : 1f) : Color.white;
        public static Color KamiColor(string id) { var k = KamiOf(id); return k != null ? ColorOf(k.color) : Gd.C_PLAYER; }
        public static Color KamiColor2(string id) { var k = KamiOf(id); return k != null ? ColorOf(k.color2) : Gd.C_PLAYER_DARK; }
    }
}
