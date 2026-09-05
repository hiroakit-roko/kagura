using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>提示の 1 枚。type: upgrade / legendary / duo / curse</summary>
    public class Offer
    {
        public string type;
        public BoonDef boon;
        public CurseDef curse;
        public int rar;
        public string kami;
        public string Id => boon != null ? boon.id : curse?.id ?? "";
    }

    /// <summary>恩恵の抽選・取得（Godot 版 boons.gd）。</summary>
    public static class BoonsLogic
    {
        public const int MAX_KAMI = 3, MAX_PER_KAMI = 3;
        public static readonly int[] RECRUIT_LEVELS = { 2, 4, 6 };

        public static List<string> KamiIds() => Data.Kami.Select(k => k.id).ToList();

        public static int NextRecruitLevel(Player p) => p.gods.Count >= MAX_KAMI ? -1 : RECRUIT_LEVELS[p.gods.Count];
        public static bool RecruitDue(Player p) { int need = NextRecruitLevel(p); return need > 0 && p.level >= need; }

        public static List<string> RollKamiChoices(Player p, int n = 3)
        {
            var pool = KamiIds().Where(id => p == null || !p.gods.Contains(id)).ToList();
            Shuffle(pool);
            return pool.Take(n).ToList();
        }

        public static string PickKami(Player p)
        {
            var cands = new List<string>(); var weights = new List<float>();
            foreach (var id in p.gods)
            {
                bool hasPool = PoolFor(p, id).Count > 0 || LegendaryFor(p, id) != null || DuosFor(p, id).Count > 0;
                if (!hasPool) continue;
                cands.Add(id); weights.Add(id == p.MainGod() ? 1.5f : 1f);
            }
            if (cands.Count == 0) return "";
            float total = weights.Sum();
            float r = Random.value * total;
            for (int i = 0; i < cands.Count; i++) { r -= weights[i]; if (r <= 0f) return cands[i]; }
            return cands[cands.Count - 1];
        }

        public static List<BoonDef> UpgradesOf(string kamiId) => Boons.UpgradesOf(Data.Boons, kamiId).ToList();
        public static List<BoonDef> OwnedOf(Player p, string kamiId) => UpgradesOf(kamiId).Where(b => p.boons.ContainsKey(b.id)).ToList();
        public static List<BoonDef> NewPool(Player p, string kamiId) => OwnedOf(p, kamiId).Count >= MAX_PER_KAMI ? new List<BoonDef>() : UpgradesOf(kamiId).Where(b => !p.boons.ContainsKey(b.id)).ToList();
        public static List<BoonDef> LvPool(Player p, string kamiId) => OwnedOf(p, kamiId).Where(b => p.boons[b.id].lv < b.MaxLevel).ToList();
        public static List<BoonDef> PoolFor(Player p, string kamiId) { var l = NewPool(p, kamiId); l.AddRange(LvPool(p, kamiId)); return l; }

        private static BoonDef DrawNew(Player p, List<BoonDef> cands, string kamiId)
        {
            float total = 0f; var ws = new List<float>();
            foreach (var b in cands)
            {
                int tier = b.tier ?? 0;
                float w = tier == 0 ? 1f : tier == 1 ? 0.7f : 0.4f;
                if (tier == 1) w += 0.02f * p.level + (kamiId == p.MainGod() ? 0.1f : 0f);
                else if (tier == 2) w += 0.03f * p.level + (kamiId == p.MainGod() ? 0.1f : 0f);
                ws.Add(w); total += w;
            }
            float r = Random.value * total;
            for (int i = 0; i < cands.Count; i++) { r -= ws[i]; if (r <= 0f) { var b = cands[i]; cands.RemoveAt(i); return b; } }
            var last = cands[cands.Count - 1]; cands.RemoveAt(cands.Count - 1); return last;
        }

        public static BoonDef LegendaryFor(Player p, string kamiId)
        {
            if (kamiId != p.MainGod()) return null;
            var b = Boons.LegendaryOf(Data.Boons, kamiId);
            if (b == null || p.boons.ContainsKey(b.id)) return null;
            return UpgradesOf(kamiId).Count(u => p.boons.ContainsKey(u.id)) >= 2 ? b : null;
        }

        public static List<BoonDef> DuosFor(Player p, string kamiId)
        {
            var outL = new List<BoonDef>();
            foreach (var b in Data.Boons)
            {
                if (string.IsNullOrEmpty(b.kami2) || p.boons.ContainsKey(b.id)) continue;
                if (b.kami != kamiId && b.kami2 != kamiId) continue;
                if (!p.gods.Contains(b.kami) || !p.gods.Contains(b.kami2)) continue;
                if (UpgradeCount(p, b.kami) >= 1 && UpgradeCount(p, b.kami2) >= 1) outL.Add(b);
            }
            return outL;
        }

        private static int UpgradeCount(Player p, string kamiId) => UpgradesOf(kamiId).Count(u => p.boons.ContainsKey(u.id));

        public static List<Offer> MakeOffer(Player p, string kamiId, int count = 3, int minRar = 0)
        {
            var outL = new List<Offer>();
            var leg = LegendaryFor(p, kamiId);
            var duos = DuosFor(p, kamiId);
            if (leg != null && Random.value < 0.5f) outL.Add(new Offer { type = "legendary", boon = leg, rar = (int)Rarity.Legendary, kami = kamiId });
            else if (duos.Count > 0 && Random.value < 0.6f) { var d = duos[Random.Range(0, duos.Count)]; outL.Add(new Offer { type = "duo", boon = d, rar = (int)Rarity.Duo, kami = d.kami }); }
            else if (GameManager.I.Wave >= 4 && Random.value < 0.14f)
            {
                var avail = Data.Curses.Where(c => !p.boons.ContainsKey(c.id)).ToList();
                if (avail.Count > 0) outL.Add(new Offer { type = "curse", curse = avail[Random.Range(0, avail.Count)], rar = (int)Rarity.Heroic, kami = kamiId });
            }
            FillFrom(p, kamiId, outL, count, minRar);
            if (outL.Count < count) foreach (var id in p.gods) if (id != kamiId && outL.Count < count) FillFrom(p, id, outL, count, minRar);
            return outL.Take(count).ToList();
        }

        private static void FillFrom(Player p, string kamiId, List<Offer> outL, int count, int minRar)
        {
            int remaining = count - outL.Count;
            if (remaining <= 0) return;
            var news = NewPool(p, kamiId);
            if (minRar > 0) { var hi = news.Where(b => (b.tier ?? 0) >= minRar).ToList(); if (hi.Count > 0) news = hi; }
            var lvs = LvPool(p, kamiId);
            Shuffle(lvs);
            int free = MAX_PER_KAMI - OwnedOf(p, kamiId).Count;
            int nLv = Mathf.Clamp(remaining - free, (lvs.Count > 0 && remaining >= 2) ? 1 : 0, lvs.Count);
            int nNew = Mathf.Min(Mathf.Min(free, remaining - nLv), news.Count);
            nLv = Mathf.Min(lvs.Count, remaining - nNew);
            for (int i = 0; i < nNew; i++) { var b = DrawNew(p, news, kamiId); outL.Add(new Offer { type = "upgrade", boon = b, rar = b.tier ?? 0, kami = kamiId }); }
            for (int i = 0; i < nLv; i++) { var b = lvs[i]; outL.Add(new Offer { type = "upgrade", boon = b, rar = p.boons[b.id].rar, kami = kamiId }); }
        }

        public static void Take(Player p, Offer o)
        {
            if (o.type == "curse") { p.boons[o.curse.id] = ((int)Rarity.Heroic, 1); p.OnBoonsChanged(); return; }
            string id = o.boon.id;
            if (p.boons.TryGetValue(id, out var cur)) p.boons[id] = (cur.rar, cur.lv + 1);
            else p.boons[id] = (o.boon.tier ?? o.rar, 1);
            p.OnBoonsChanged();
        }

        public static List<string> MikiTargets(Player p) => p.gods.Where(id => p.KamiLv(id) < 10).ToList();

        public static void MikiApply(Player p, string kamiId)
        {
            if (!p.gods.Contains(kamiId)) return;
            p.kamiXp[kamiId] = 0f;
            p.KamiLevelUp(kamiId);
        }

        public static List<RelicDef> OfferRelics(Player p, int n = 3)
        {
            var pool = Data.Relics.Where(r => !r.shop && !p.relics.Contains(r.id)).ToList();
            Shuffle(pool);
            return pool.Take(n).ToList();
        }

        private static void Shuffle<T>(IList<T> list)
        {
            for (int i = list.Count - 1; i > 0; i--) { int j = Random.Range(0, i + 1); (list[i], list[j]) = (list[j], list[i]); }
        }
    }
}
