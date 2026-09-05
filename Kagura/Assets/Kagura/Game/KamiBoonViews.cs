using System.Collections.Generic;
using UnityEngine;
using Kagura.Core;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>神のデフォルメ絵（Art/kami_icon/&lt;id&gt;.png、透過）。無ければ紋章で代用する。</summary>
    public static class KamiIcon
    {
        public static void Draw(UiLayer L, string id, Vector2 c, float r, float t, float a, bool ring = true)
        {
            var k = Data.KamiOf(id);
            if (k == null) return;
            var kc = Data.ColorOf(k.color);
            if (ring)
            {
                L.back.DrawCircle(c, r + 4f, new Color(0.05f, 0.03f, 0.09f, 0.9f * a));
                L.back.DrawCircle(c, r + 2f, Gd.WithA(kc, 0.18f * a));
            }
            var tex = UiKit.Art("kami_icon/" + id);
            if (tex != null) L.img.Draw(tex, new Rect(c.x - r, c.y - r, r * 2f, r * 2f), new Color(1, 1, 1, a));
            else UiKit.Emblem(L.front, k.emblem, c, r * 0.7f, kc, Data.ColorOf(k.color2), t, a);
            if (ring) L.front.DrawArc(c, r + 4f, 0, Gd.TAU, 40, Gd.WithA(kc, 0.9f * a), 2f);
        }
    }

    // =====================================================================
    /// <summary>神を選ぶ（位上がり）：主神を上に、副神を左右下に置いた三角の配置。主神だけのときも同じ画面で選ぶ。</summary>
    public class MikiView : ChoiceView
    {
        public List<string> ids = new List<string>();
        private static readonly Rect MainR = new Rect(Gd.W * 0.5f - 112f, 150f, 224f, 300f);
        private static readonly Rect SubL = new Rect(36f, 486f, 200f, 270f);
        private static readonly Rect SubR = new Rect(Gd.W - 236f, 486f, 200f, 270f);
        public MikiView(Transform parent) : base(parent, "miki") { }
        public void Open(List<string> i) { ids = i; Show(); }
        public override int Count() => 3;
        public override Rect RectOf(int i) => i == 0 ? MainR : i == 1 ? SubL : SubR;
        public override int CardAt(Vector2 p)
        {
            for (int i = 0; i < ids.Count && i < 3; i++) if (RectOf(i).Contains(p)) return i;
            return -1;
        }

        protected override void Draw()
        {
            var p = GameManager.I.player;
            Backdrop(Gd.C_GOLD);
            float a = anim;
            Txt(Face.Display, new Vector2(0, 74), "位が上がる", 40, Gd.WithA(Gd.C_GOLD, a), TextAnchor.MiddleCenter, Gd.W);
            Txt(Face.Body, new Vector2(0, 104), "神格を上げる神を選ぶ", 14, new Color(0.9f, 0.9f, 1f, 0.85f * a), TextAnchor.MiddleCenter, Gd.W);
            // 三角の結び線（迎えた神どうし）
            Vector2[] cs = { MainR.center, SubL.center, SubR.center };
            for (int i = 0; i < 3; i++)
                for (int j = i + 1; j < 3; j++)
                {
                    bool on = i < ids.Count && j < ids.Count;
                    Color lc = on ? Gd.WithA(Gd.C_GOLD, 0.35f * a) : new Color(1, 1, 1, 0.08f * a);
                    L.back.DrawLine(cs[i], cs[j], lc, on ? 2f : 1f);
                    if (on) { float k = Mathf.Repeat(t * 0.4f + i * 0.3f, 1f); L.back.DrawCircle(Vector2.Lerp(cs[i], cs[j], k), 3f, Gd.WithA(Gd.C_GOLD, 0.8f * a)); }
                }
            for (int i = 0; i < 3; i++)
            {
                var r = RectOf(i);
                float pop = Mathf.Clamp01(a * 1.5f - i * 0.12f);
                if (pop <= 0f) continue;
                if (i < ids.Count) DrawGod(i, ids[i], r, pop, p);
                else
                {
                    var rr = UiKit.Grow(r, -(1f - pop) * 20f);
                    L.back.DrawRect(rr, new Color(0.05f, 0.03f, 0.09f, 0.6f * pop));
                    L.front.DrawRect(rr, new Color(1, 1, 1, 0.18f * pop), false, 1f);
                    L.front.DrawCircle(rr.center + new Vector2(0, -30f), 34f, new Color(1, 1, 1, 0.05f * pop));
                    L.front.DrawArc(rr.center + new Vector2(0, -30f), 34f, 0, Gd.TAU, 32, new Color(1, 1, 1, 0.2f * pop), 1f);
                    Txt(Face.Body, new Vector2(rr.x, rr.center.y + 40f), "位 " + BoonsLogic.RECRUIT_LEVELS[i] + " で副神", 13, new Color(1, 1, 1, 0.5f * pop), TextAnchor.MiddleCenter, rr.width);
                }
            }
            Txt(Face.Body, new Vector2(0, Mathf.Min(Gd.H - 40f, SubL.yMax + 44f)), PickHint("選ぶ"), 14, new Color(0.85f, 0.88f, 1f, 0.9f * a), TextAnchor.MiddleCenter, Gd.W);
        }

        private void DrawGod(int i, string id, Rect r, float pop, Player p)
        {
            var k = Data.KamiOf(id);
            var kc = Data.ColorOf(k.color);
            bool sel = i == hover;
            bool main = i == 0;
            var rr = UiKit.Grow(r, (sel ? 4f : 0f) - (1f - pop) * 20f);
            CardBg(rr, kc, sel, pop);
            // デフォルメ絵を大きく、後光と輪で飾る（元の絵は重ねない）
            float ir = main ? 72f : 58f;
            var ic = new Vector2(rr.center.x, rr.y + (main ? 122f : 100f));
            for (int j = 0; j < 14; j++) { float ang = t * 0.3f + Gd.TAU * j / 14f; L.back.DrawLine(ic + Gd.Dir(ang) * (ir + 6f), ic + Gd.Dir(ang) * (ir + 26f + 8f * Mathf.Sin(t * 2f + j)), Gd.WithA(kc, 0.16f * pop), 5f); }
            L.back.DrawCircle(ic, ir + 8f, Gd.WithA(kc, 0.12f * pop));
            L.back.DrawCircle(ic, ir + 3f, new Color(0.05f, 0.03f, 0.09f, 0.9f * pop));
            KamiIcon.Draw(L, id, ic, ir, t, pop, false);
            L.front.DrawArc(ic, ir + 3f, 0, Gd.TAU, 48, Gd.WithA(kc, 0.9f * pop), 2.5f);
            L.front.DrawArc(ic, ir + 9f, t * 0.8f, t * 0.8f + 2.2f, 24, Gd.WithA(kc, 0.55f * pop), 1.5f);
            Txt(Face.Body, new Vector2(rr.x + 10, rr.y + 20), main ? "主神" : "副神", 11, new Color(1, 0.9f, 0.7f, 0.9f * pop));
            float y = ic.y + ir + 30f;
            Txt(Face.Display, new Vector2(rr.x, y), k.name, main ? 21 : 17, new Color(1, 1, 1, pop), TextAnchor.MiddleCenter, rr.width);
            Txt(Face.Body, new Vector2(rr.x, y + 16f), k.title, 10, Gd.WithA(kc, 0.85f * pop), TextAnchor.MiddleCenter, rr.width);
            int lv = p.KamiLv(id);
            bool capped = lv >= 10;
            Txt(Face.Bold, new Vector2(rr.x, y + 42f), capped ? "神格 " + lv + "（上限）" : "神格 " + lv + " → " + (lv + 1), main ? 17 : 15, Gd.WithA(Gd.C_GOLD, pop), TextAnchor.MiddleCenter, rr.width);
            Txt(Face.Body, new Vector2(rr.x, y + 62f), k.weapon + "  ×" + Fmt(p.KamiPower(id)) + " → ×" + Fmt(Boons.KamiPower(Mathf.Min(lv + 1, 10), Boons.GrowthOf(id))), 11, new Color(0.9f, 0.92f, 1f, pop * 0.9f), TextAnchor.MiddleCenter, rr.width);
            int owned = BoonsLogic.OwnedOf(p, id).Count;
            for (int j = 0; j < BoonsLogic.MAX_PER_KAMI; j++)
            {
                var dot = new Vector2(rr.center.x + (j - 1) * 14f, y + 80f);
                bool filled = j < owned;
                L.front.DrawCircle(dot, 4f, Gd.WithA(kc, (filled ? 0.95f : 0.2f) * pop));
                if (!filled) L.front.DrawArc(dot, 4f, 0, Gd.TAU, 12, Gd.WithA(kc, 0.6f * pop), 1f);
            }
        }
    }

    // =====================================================================
    /// <summary>
    /// 恩恵：上の段に新しい候補 3 つ、下の段にその神の能力 3 枠（持っている能力は強化の変化を示し、空いた枠は「空」）。
    /// offers は 6 つ（0-2 が上、3-5 が下。空の枠は null）。
    /// </summary>
    public class BoonsView : ChoiceView
    {
        public string kamiId = "", title = "神との邂逅";
        public List<Offer> offers = new List<Offer>();
        public int rerolls;
        private const float CW = 192f, CH = 236f, CY = 216f, CY2 = 480f, GAP = 10f;
        public BoonsView(Transform parent) : base(parent, "boons") { }
        public void Open(string kid, List<Offer> o, int r, string ttl) { kamiId = kid; offers = o; rerolls = r; title = ttl; Show(); }
        public override int Count() => offers.Count;
        public override Rect RectOf(int i) => i < 3 ? Row(i, 3, CW, CH, CY, GAP) : Row(i - 3, 3, CW, CH, CY2, GAP);
        public Rect RerollRect() => new Rect(Gd.W * 0.5f - 90f, CY2 + CH + 14f, 180f, 34f);
        public bool Selectable(int i)
        {
            if (i < 0 || i >= offers.Count || offers[i] == null) return false;
            var o = offers[i];
            if (i >= 3 && o.boon != null) { var p = GameManager.I.player; return p != null && p.boons.TryGetValue(o.boon.id, out var cur) && cur.lv < o.boon.MaxLevel; }
            return true;
        }
        /// <summary>札の番号。神籤（引き直し）は 100。</summary>
        public override int CardAt(Vector2 p)
        {
            for (int i = 0; i < offers.Count; i++) if (RectOf(i).Contains(p) && Selectable(i)) return i;
            if (rerolls > 0 && RerollRect().Contains(p)) return 100;
            return -1;
        }

        protected override void Draw()
        {
            var k = Data.KamiOf(kamiId);
            var col = k != null ? Data.ColorOf(k.color) : Gd.C_GOLD;
            Backdrop(col);
            float a = anim;
            var p = GameManager.I.player;
            // 見出し：神のデフォルメ絵と名
            var ec = new Vector2(Gd.W * 0.5f, 92f);
            for (int i = 0; i < 12; i++) { float ang = t * 0.25f + Gd.TAU * i / 12f; L.back.DrawLine(ec + Gd.Dir(ang) * 50f, ec + Gd.Dir(ang) * (110f + 20f * Mathf.Sin(t * 1.5f + i)), Gd.WithA(col, 0.10f * a), 6f); }
            KamiIcon.Draw(L, kamiId, ec, 44f, t, a);
            Txt(Face.Body, new Vector2(0, 26), title, 13, Gd.WithA(Gd.C_GOLD, a), TextAnchor.MiddleCenter, Gd.W);
            if (k != null)
            {
                string role = p != null ? (p.MainGod() == kamiId ? "主神" : "副神") : "";
                Txt(Face.Display, new Vector2(0, 160), k.name, 24, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, Gd.W);
                Txt(Face.Body, new Vector2(0, 178), role + "　神格 " + (p != null ? p.KamiLv(kamiId) : 1) + "　神器：" + k.weapon, 11, Gd.WithA(col, 0.9f * a), TextAnchor.MiddleCenter, Gd.W);
            }
            Txt(Face.Bold, new Vector2(Row(0, 3, CW, CH, CY, GAP).x, CY - 8f), "新しい能力", 12, new Color(0.55f, 0.95f, 1f, 0.9f * a));
            Txt(Face.Bold, new Vector2(Row(0, 3, CW, CH, CY2, GAP).x, CY2 - 8f), "いまの能力", 12, Gd.WithA(Gd.C_GOLD, 0.9f * a));
            for (int i = 0; i < offers.Count; i++)
            {
                float pop = Mathf.Clamp01(a * 1.4f - i * 0.08f);
                if (pop <= 0f) continue;
                if (offers[i] == null) DrawEmpty(i, pop, col);
                else DrawCard(i, pop);
            }
            if (rerolls > 0)
            {
                var rb = RerollRect();
                bool sel = hover == 100;
                L.back.DrawRect(rb, new Color(0.08f, 0.06f, 0.12f, 0.95f * a));
                L.front.DrawRect(rb, Gd.WithA(Gd.C_GOLD, (sel ? 1f : 0.6f) * a), false, 1.5f);
                Txt(Face.Bold, new Vector2(rb.x, rb.y + 22), "神籤を引き直す ×" + rerolls, 13, Gd.WithA(Gd.C_GOLD, a), TextAnchor.MiddleCenter, rb.width);
            }
            Txt(Face.Body, new Vector2(0, CY2 + CH + 68f), PickHint("受け取る"), 13, new Color(0.85f, 0.88f, 1f, 0.9f * a), TextAnchor.MiddleCenter, Gd.W);
        }

        private void DrawEmpty(int i, float pop, Color col)
        {
            var r = RectOf(i);
            var rr = UiKit.Grow(r, -(1f - pop) * 20f);
            L.back.DrawRect(rr, new Color(0.05f, 0.03f, 0.09f, 0.55f * pop));
            L.front.DrawRect(rr, Gd.WithA(col, 0.25f * pop), false, 1f);
            for (int j = 0; j < 4; j++) { float ang = Gd.TAU * j / 4f + Mathf.PI * 0.25f; L.front.DrawLine(rr.center + Gd.Dir(ang) * 10f, rr.center + Gd.Dir(ang) * 22f, Gd.WithA(col, 0.25f * pop), 1.5f); }
            Txt(Face.Display, new Vector2(rr.x, rr.center.y + 10f), "空", 28, Gd.WithA(col, 0.35f * pop), TextAnchor.MiddleCenter, rr.width);
            Txt(Face.Body, new Vector2(rr.x, rr.center.y + 40f), "新しい能力で埋まる", 11, new Color(1, 1, 1, 0.4f * pop), TextAnchor.MiddleCenter, rr.width);
        }

        private void DrawCard(int i, float pop)
        {
            var o = offers[i];
            var r = RectOf(i);
            bool sel = i == hover;
            if (o.type == "curse") { DrawCurseCard(o, r, sel, pop); return; }
            bool bottom = i >= 3;
            bool can = Selectable(i);
            float dim = can ? 1f : 0.5f;
            int rar = o.rar;
            var k = Data.KamiOf(o.kami);
            var kc = Data.ColorOf(k.color);
            var col = Data.ColorOf(RarityTable.Colors[rar]);
            var rr = UiKit.Grow(r, (sel ? 4f : 0f) - (1f - pop) * 20f);
            float a = pop * dim, x0 = rr.x + 12f, w = rr.width - 24f;
            CardBg(rr, col, sel && can, a);
            bool special = o.type == "legendary" || o.type == "duo";
            if (special)
                for (int j = 0; j < 10; j++) { float ang = t * 0.5f + Gd.TAU * j / 10f; var c = rr.center; L.back.DrawLine(c + Gd.Dir(ang) * rr.width * 0.55f, c + Gd.Dir(ang) * rr.width * 0.75f, Gd.WithA(col, 0.12f * a), 8f); }
            L.back.DrawRect(new Rect(rr.x, rr.y + 3, rr.width, 26f), Gd.WithA(col, (sel ? 0.30f : 0.20f) * a));
            Txt(Face.Display, new Vector2(rr.x + 10, rr.y + 22), RarityTable.Names[rar], 16, Gd.WithA(col, a));
            Txt(Face.Body, new Vector2(rr.x + 32, rr.y + 21), RarityTable.LongNames[rar], 9, Gd.WithA(col, a * 0.9f));
            var p = GameManager.I.player;
            var b = o.boon;
            bool ownedNow = p != null && p.boons.ContainsKey(b.id);
            int curLv = ownedNow ? p.boons[b.id].lv : 0;
            int showRar = ownedNow ? Mathf.Max(rar, p.boons[b.id].rar) : rar;
            bool maxed = ownedNow && curLv >= b.MaxLevel;
            string tag = bottom ? (maxed ? "上限" : "強化") : "新"; var tagCol = bottom ? Gd.C_GOLD : new Color(0.55f, 0.95f, 1f);
            if (o.type == "legendary") { tag = "伝説"; tagCol = Data.ColorOf(RarityTable.Colors[(int)Rarity.Legendary]); }
            else if (o.type == "duo") { tag = "双神"; tagCol = Data.ColorOf(RarityTable.Colors[(int)Rarity.Duo]); }
            float tw = tag.Length <= 1 ? 48f : 62f;
            var tr = new Rect(rr.xMax - tw - 6f, rr.y + 32f, tw, 24f);
            L.back.DrawRect(tr, Gd.WithA(tagCol, 0.92f * a));
            L.back.DrawColoredPolygon(new[] { tr.position, tr.position + new Vector2(-8, 12), tr.position + new Vector2(0, 24) }, Gd.WithA(tagCol, 0.92f * a));
            Txt(Face.Display, new Vector2(tr.x, tr.y + 18), tag, tag.Length <= 1 ? 16 : 14, new Color(0.08f, 0.05f, 0.1f, a), TextAnchor.MiddleCenter, tr.width, false);
            UiKit.Emblem(L.front, k.emblem, new Vector2(rr.x + 30f, rr.y + 54f), 18f, kc, Data.ColorOf(k.color2), t, a * 0.95f);
            if (o.type == "duo")
            {
                var k2 = Data.KamiOf(b.kami2);
                if (k2 != null) UiKit.Emblem(L.front, k2.emblem, new Vector2(rr.x + 56f, rr.y + 62f), 12f, Data.ColorOf(k2.color), Data.ColorOf(k2.color2), t, a * 0.95f);
            }
            Txt(Face.Display, new Vector2(rr.x + 58f, rr.y + 60f), b.name, 17, new Color(1, 1, 1, a), TextAnchor.MiddleLeft, rr.width - 66f);
            if (bottom) Txt(Face.Bold, new Vector2(rr.x + 58f, rr.y + 78f), "Lv." + curLv, 11, Gd.WithA(Gd.C_GOLD, a));
            int descLv = bottom ? Mathf.Min(curLv + 1, b.MaxLevel) : curLv + 1;
            Para(Face.Body, new Vector2(x0, rr.y + 100f), Boons.Describe(b, showRar, descLv), w, 12, 4, new Color(0.9f, 0.92f, 1f, a * 0.95f));
            if (bottom)
            {
                if (maxed) Txt(Face.Body, new Vector2(rr.x, rr.yMax - 22f), "これ以上は強くならない", 10, new Color(1, 1, 1, a * 0.7f), TextAnchor.MiddleCenter, rr.width);
                else
                {
                    string prev = Boons.FormatValue(b, Boons.Value(b, showRar, curLv)), nxt = Boons.FormatValue(b, Boons.Value(b, showRar, curLv + 1));
                    L.back.DrawRect(new Rect(x0 - 4, rr.yMax - 56, w + 8, 44), Gd.WithA(Gd.C_GOLD, 0.12f * a));
                    Txt(Face.Bold, new Vector2(x0 + 2, rr.yMax - 39), "強化  Lv." + curLv + " → " + (curLv + 1), 12, Gd.WithA(Gd.C_GOLD, a));
                    Txt(Face.Display, new Vector2(x0 + 2, rr.yMax - 19), prev + "  →  " + nxt, 14, new Color(1, 1, 1, a), TextAnchor.MiddleLeft, w);
                }
            }
            else if (special) Txt(Face.Body, new Vector2(rr.x, rr.yMax - 20f), "重ねることはできない", 10, Gd.WithA(col, a * 0.8f), TextAnchor.MiddleCenter, rr.width);
            else if (p != null)
            {
                int owned = BoonsLogic.OwnedOf(p, b.kami).Count;
                bool full = owned >= BoonsLogic.MAX_PER_KAMI;
                L.back.DrawRect(new Rect(x0 - 4, rr.yMax - 44, w + 8, 30), Gd.WithA(full ? new Color(1f, 0.5f, 0.5f) : kc, 0.10f * a));
                Txt(Face.Bold, new Vector2(x0, rr.yMax - 25), full ? "枠が空いていない" : "枠 " + (owned + 1) + " / " + BoonsLogic.MAX_PER_KAMI + " に入る", 12, Gd.WithA(full ? new Color(1f, 0.6f, 0.6f) : Gd.Lightened(kc, 0.3f), a));
            }
        }

        private void DrawCurseCard(Offer o, Rect r, bool sel, float pop)
        {
            var c = o.curse;
            var col = new Color(0.85f, 0.25f, 0.35f);
            var rr = UiKit.Grow(r, (sel ? 4f : 0f) - (1f - pop) * 20f);
            float a = pop, x0 = rr.x + 12f, w = rr.width - 24f;
            var v = L.back;
            v.DrawRect(UiKit.Grow(rr, 6f), new Color(0, 0, 0, 0.4f * a));
            v.DrawRect(rr, new Color(0.10f, 0.03f, 0.06f, 0.97f * a));
            L.front.DrawRect(rr, Gd.WithA(col, (sel ? 1f : 0.6f) * a), false, sel ? 2f : 1.2f);
            var cc = rr.center;
            for (int j = 0; j < 12; j++) { float ang = -t * 0.4f + Gd.TAU * j / 12f; v.DrawLine(cc + Gd.Dir(ang) * rr.width * 0.5f, cc + Gd.Dir(ang) * rr.width * 0.72f, Gd.WithA(col, 0.10f * a), 6f); }
            v.DrawRect(new Rect(rr.x, rr.y + 3, rr.width, 26f), Gd.WithA(col, 0.28f * a));
            Txt(Face.Display, new Vector2(rr.x + 10, rr.y + 22), "禍神の取引", 15, Gd.WithA(new Color(1, 0.7f, 0.75f), a));
            var ec = new Vector2(rr.x + 30f, rr.y + 54f);
            v.DrawCircle(ec, 18f, new Color(0.05f, 0.02f, 0.04f, a));
            L.front.DrawArc(ec, 18f, 0, Gd.TAU, 32, Gd.WithA(col, 0.9f * a), 2f);
            Txt(Face.Display, new Vector2(ec.x - 20, ec.y + 7), "禍", 18, Gd.WithA(new Color(1, 0.8f, 0.85f), a), TextAnchor.MiddleCenter, 40, false);
            Txt(Face.Display, new Vector2(rr.x + 58f, rr.y + 60f), c.name, 17, new Color(1, 1, 1, a), TextAnchor.MiddleLeft, rr.width - 66f);
            Para(Face.Body, new Vector2(x0, rr.y + 96f), c.desc, w, 11, 2, new Color(1, 0.92f, 0.94f, a * 0.85f));
            v.DrawRect(new Rect(x0 - 4, rr.y + 128, w + 8, 40), new Color(0.2f, 0.6f, 0.35f, 0.18f * a));
            Txt(Face.Bold, new Vector2(x0 + 2, rr.y + 142), "得", 12, new Color(0.6f, 1f, 0.7f, a));
            Para(Face.Body, new Vector2(x0 + 22, rr.y + 142), c.gain ?? "", w - 26, 11, 2, new Color(0.9f, 1f, 0.92f, a));
            v.DrawRect(new Rect(x0 - 4, rr.y + 172, w + 8, 40), new Color(0.7f, 0.2f, 0.3f, 0.18f * a));
            Txt(Face.Bold, new Vector2(x0 + 2, rr.y + 186), "失", 12, new Color(1f, 0.6f, 0.65f, a));
            Para(Face.Body, new Vector2(x0 + 22, rr.y + 186), c.loss ?? "", w - 26, 11, 2, new Color(1f, 0.9f, 0.92f, a));
            Txt(Face.Body, new Vector2(rr.x, rr.yMax - 10), "取り消せない", 10, Gd.WithA(col, a * 0.85f), TextAnchor.MiddleCenter, rr.width);
        }
    }
}
