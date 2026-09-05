using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using Kagura.Core;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>選択系ビューの共通部分（Godot 版 ChoiceView）。UiLayer に毎フレーム描く。</summary>
    public abstract class ChoiceView
    {
        protected UiLayer L;
        public bool visible;
        protected float anim, t;
        protected int hover = -1;

        protected ChoiceView(Transform parent, string name) { L = UiLayer.Create(parent, name, Gd.ZHud + 10); L.Clear(); }

        public virtual void Show() { visible = true; anim = 0f; hover = -1; }
        public void Hide() { visible = false; L.Clear(); }

        public void Tick(float dt, Vector2? mousePx)
        {
            if (!visible) return;
            t += dt;
            anim = Mathf.Min(1f, anim + dt * 3f);
            if (mousePx.HasValue)
            {
                int h = CardAt(mousePx.Value);
                if (h != hover) { hover = h; if (h >= 0) Sfx.Play("hover", -18f, 1f, 0.05f); }
            }
            else hover = -1;
            L.Begin();
            Draw();
            L.End();
        }

        public abstract int Count();
        public abstract Rect RectOf(int i);
        protected abstract void Draw();

        public virtual int CardAt(Vector2 p)
        {
            for (int i = 0; i < Count(); i++) if (RectOf(i).Contains(p)) return i;
            return -1;
        }

        protected Rect Row(int i, int total, float cw, float ch, float cy, float gap = 12f)
        {
            float w = total * cw + (total - 1) * gap;
            return new Rect((Gd.W - w) * 0.5f + i * (cw + gap), cy, cw, ch);
        }

        protected void Backdrop(Color col)
        {
            var v = L.back;
            v.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.03f, 0.02f, 0.06f, 0.88f * anim));
            UiKit.Pattern(v, new Rect(0, 0, Gd.W, Gd.H), Gd.WithA(col, 0.05f * anim), 52f, t);
            v.DrawRect(new Rect(0, 0, Gd.W, 6), Gd.WithA(col, 0.6f * anim));
            v.DrawRect(new Rect(0, Gd.H - 6, Gd.W, 6), Gd.WithA(col, 0.6f * anim));
            v.DrawRect(new Rect(0, 6, Gd.W, 1), new Color(1, 1, 1, 0.15f * anim));
            v.DrawRect(new Rect(0, Gd.H - 7, Gd.W, 1), new Color(1, 1, 1, 0.15f * anim));
        }

        /// <summary>和紙風のカード地。</summary>
        protected void CardBg(Rect r, Color col, bool sel, float a)
        {
            var v = L.back;
            v.DrawRect(UiKit.Grow(r, 6f), new Color(0, 0, 0, 0.35f * a));
            v.DrawRect(r, new Color(0.08f, 0.06f, 0.12f, 0.97f * a));
            v.DrawRect(new Rect(r.x, r.y, r.width, 3f), Gd.WithA(col, a));
            v.DrawRect(new Rect(r.x, r.yMax - 3f, r.width, 3f), Gd.WithA(col, a * 0.6f));
            v.DrawRect(r, Gd.WithA(col, (sel ? 1f : 0.5f) * a), false, sel ? 2f : 1.2f);
            if (sel) { v.DrawRect(UiKit.Grow(r, 5f), Gd.WithA(col, 0.35f * a), false, 1.5f); v.DrawRect(r, Gd.WithA(col, 0.06f * a)); }
            foreach (float cx in new[] { r.x + 8f, r.xMax - 8f })
                foreach (float cy in new[] { r.y + 10f, r.yMax - 10f })
                    v.DrawCircle(new Vector2(cx, cy), 1.8f, Gd.WithA(col, 0.8f * a));
        }

        /// <summary>絵の下端を暗くして文字を載せる。</summary>
        protected void Fade(Rect pr, float h, float a, int n = 6, Color? baseCol = null)
        {
            var c = baseCol ?? new Color(0.08f, 0.06f, 0.12f);
            for (int gi = 0; gi < n; gi++)
            {
                float kk = (float)gi / n;
                L.front.DrawRect(new Rect(pr.x, pr.yMax - h + kk * h, pr.width, h / n + 1f), new Color(c.r, c.g, c.b, 0.85f * kk * a));
            }
        }

        protected static string PickHint(string verb, int n = 3)
        {
            return "タップで" + verb;   // 数字キーの案内は出さない（スマホ優先。キーは黙って効く）
        }

        protected void Txt(Face f, Vector2 pos, string s, float size, Color col, TextAnchor align = TextAnchor.MiddleLeft, float width = -1f, bool shadow = true) => UiKit.Txt(L, f, pos, s, size, col, align, width, shadow);
        protected void Para(Face f, Vector2 pos, string s, float width, float size, int lines, Color col, TextAnchor align = TextAnchor.MiddleLeft) => UiKit.Para(L, f, pos, s, width, size, lines, col, align);
        protected static string Fmt(float v) => v.ToString("0.00");
    }

    // =====================================================================
    /// <summary>神との契約の確認（絵・説明・契約の代償）。</summary>
    public class ConfirmView : ChoiceView
    {
        public string kamiId = "", role = "主神";
        public Action onOk;
        private Texture2D _portrait;
        private const float BW = 200f, BH = 48f;
        public ConfirmView(Transform parent) : base(parent, "confirm") { }

        public void Open(string id, string r, Action ok) { kamiId = id; role = r; onOk = ok; _portrait = UiKit.Art("kami/" + id); Show(); }
        public override int Count() => 2;
        public override Rect RectOf(int i) => new Rect(Gd.W * 0.5f + (i == 0 ? -BW - 12f : 12f), Gd.H - 150f, BW, BH);

        protected override void Draw()
        {
            var k = Data.KamiOf(kamiId);
            if (k == null) return;
            var col = Data.ColorOf(k.color);
            Backdrop(col);
            float a = anim;
            var pr = new Rect(60, 60, Gd.W - 120, 300);
            UiKit.Panel(L.back, UiKit.Grow(pr, 6), col, a, 0.9f);
            if (_portrait != null)
            {
                L.img.DrawCover(_portrait, pr, a, 0.35f);
                Fade(pr, 90f, a, 8, new Color(0.03f, 0.02f, 0.06f));
            }
            else
            {
                L.back.DrawRect(pr, new Color(0.05f, 0.03f, 0.09f, 0.95f * a));
                for (int i = 0; i < 14; i++) { float ang = t * 0.3f + Gd.TAU * i / 14f; L.back.DrawLine(pr.center + Gd.Dir(ang) * 70f, pr.center + Gd.Dir(ang) * 200f, Gd.WithA(col, 0.08f * a), 8f); }
                UiKit.Emblem(L.front, k.emblem, pr.center + new Vector2(0, -20), 70f, col, Data.ColorOf(k.color2), t, a);
            }
            Txt(Face.Display, new Vector2(pr.x + 16, pr.yMax - 22), k.name, 34, new Color(1, 1, 1, a));
            Txt(Face.Body, new Vector2(pr.x + 18, pr.yMax - 6), k.kana + "　" + k.title, 12, Gd.WithA(col, a));
            Txt(Face.Display, new Vector2(pr.xMax - 100, pr.y + 26), role + "として", 16, Gd.WithA(Gd.C_GOLD, a), TextAnchor.MiddleRight, 88);
            Txt(Face.Body, new Vector2(0, 392), "「" + k.intro + "」", 14, new Color(0.95f, 0.93f, 1f, 0.9f * a), TextAnchor.MiddleCenter, Gd.W);

            float x0 = 60f, w = Gd.W - 120f, y = 420f;
            UiKit.Panel(L.back, new Rect(x0 - 8, y - 6, w + 16, 190), col, a, 0.8f);
            Txt(Face.Bold, new Vector2(x0 + 6, y + 14), "得意　" + k.role, 12, Gd.WithA(Gd.Lightened(col, 0.2f), a));
            Txt(Face.Body, new Vector2(x0 + 6, y + 36), "神器", 11, new Color(1, 0.9f, 0.7f, a * 0.85f));
            Txt(Face.Display, new Vector2(x0 + 40, y + 38), k.weapon, 16, new Color(1, 1, 1, a));
            int gr = Mathf.RoundToInt(Boons.GrowthOf(k.id) * 100f);
            Txt(Face.Body, new Vector2(x0 + 6, y + 38), "神格の伸び +" + gr + "%", 11, Gd.WithA(gr > 12 ? Gd.C_GOLD : Color.white, a * 0.85f), TextAnchor.MiddleRight, w - 12);
            Para(Face.Body, new Vector2(x0 + 6, y + 56), k.weapon_desc, w - 12, 12, 2, new Color(0.9f, 0.92f, 1f, a * 0.9f));
            if (role == "主神")
            {
                Txt(Face.Body, new Vector2(x0 + 6, y + 96), "詠唱　" + k.cast + "：" + k.cast_desc, 11, new Color(0.9f, 0.92f, 1f, a * 0.85f), TextAnchor.MiddleLeft, w - 12);
                Txt(Face.Body, new Vector2(x0 + 6, y + 114), "神招き　" + k.call + "：" + k.call_desc, 11, new Color(0.9f, 0.92f, 1f, a * 0.85f), TextAnchor.MiddleLeft, w - 12);
            }
            else Txt(Face.Body, new Vector2(x0 + 6, y + 98), "詠唱と神招きは主神のみ", 11, new Color(0.9f, 0.92f, 1f, a * 0.7f));
            if (!string.IsNullOrEmpty(k.status)) Txt(Face.Body, new Vector2(x0 + 6, y + 134), "神威 " + k.status + "：" + k.status_desc, 10, new Color(0.85f, 0.9f, 1f, a * 0.85f), TextAnchor.MiddleLeft, w - 12);
            else Txt(Face.Body, new Vector2(x0 + 6, y + 134), k.status_desc ?? "", 10, new Color(0.85f, 0.9f, 1f, a * 0.85f), TextAnchor.MiddleLeft, w - 12);
            Txt(Face.Body, new Vector2(x0 + 6, y + 160), k.mark ?? "", 11, Gd.WithA(col, a * 0.8f));

            y = 626f;
            var red = new Color(0.85f, 0.2f, 0.3f);
            UiKit.Panel(L.back, new Rect(x0 - 8, y - 6, w + 16, 96), red, a, 0.9f);
            for (int i = 0; i < 5; i++) { float bx = x0 + 20f + i * (w - 40f) / 4f + Mathf.Sin(t * 0.7f + i) * 3f; L.front.DrawCircle(new Vector2(bx, y - 6f), 2f + 0.6f * (i % 2), new Color(0.7f, 0.08f, 0.15f, 0.8f * a)); }
            Txt(Face.Display, new Vector2(x0 + 6, y + 16), "契約の代償", 14, Gd.WithA(new Color(1, 0.45f, 0.5f), a));
            Txt(Face.Body, new Vector2(x0 + 96, y + 15), "神との契りは血判に等しい。捧げたものは、二度と戻らぬ", 10, new Color(1, 0.72f, 0.76f, 0.9f * a));
            Txt(Face.Bold, new Vector2(x0 + 6, y + 40), "一、", 12, new Color(1, 0.7f, 0.75f, a));
            Para(Face.Body, new Vector2(x0 + 30, y + 40), k.cost ?? "", w - 40, 12, 1, new Color(1, 0.92f, 0.94f, a));
            Txt(Face.Bold, new Vector2(x0 + 6, y + 66), "二、", 12, new Color(1, 0.7f, 0.75f, a));
            Para(Face.Body, new Vector2(x0 + 30, y + 66), k.flavor ?? "", w - 40, 12, 2, new Color(1, 0.92f, 0.94f, a * 0.9f));

            bool touch = GameManager.I != null && GameManager.I.IsTouch;
            for (int i = 0; i < 2; i++)
            {
                var r = RectOf(i);
                bool sel = hover == i;
                var bc = i == 0 ? col : new Color(0.7f, 0.7f, 0.8f);
                L.back.DrawRect(r, new Color(0.08f, 0.06f, 0.12f, 0.95f * a));
                L.front.DrawRect(r, Gd.WithA(bc, (sel ? 1f : 0.55f) * a), false, sel ? 2f : 1.2f);
                if (sel) L.back.DrawRect(r, Gd.WithA(bc, 0.12f * a));
                string label = i == 0 ? "契約する" : "考え直す";
                Txt(i == 0 ? Face.Display : Face.Bold, new Vector2(r.x, r.y + 31), label, i == 0 ? 15 : 13, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, r.width);
            }
        }
    }

    // =====================================================================
    /// <summary>使い魔の選択（開始時）。</summary>
    public class FamiliarView : ChoiceView
    {
        private const float CW = 190f, CH = 330f, CY = 300f;
        public FamiliarView(Transform parent) : base(parent, "familiar") { }
        public override int Count() => Familiar.LIST.Count;
        public override Rect RectOf(int i) => Row(i, Familiar.LIST.Count, CW, CH, CY);

        protected override void Draw()
        {
            Backdrop(new Color(0.85f, 0.75f, 1f));
            Txt(Face.Display, new Vector2(0, 200), "使い魔を選べ", 44, Gd.WithA(Gd.C_GOLD, anim), TextAnchor.MiddleCenter, Gd.W);
            Txt(Face.Body, new Vector2(0, 232), "後ろに付いて回り、自動で撃ってくれる相棒。神を迎える前の頼りになる。", 13, new Color(0.9f, 0.9f, 1f, 0.85f * anim), TextAnchor.MiddleCenter, Gd.W);
            Txt(Face.Body, new Vector2(0, 252), "威力は位（レベル）とともに少しずつ伸びる。", 12, new Color(0.9f, 0.9f, 1f, 0.65f * anim), TextAnchor.MiddleCenter, Gd.W);
            for (int i = 0; i < Familiar.LIST.Count; i++)
            {
                var f = Familiar.LIST[i];
                var r = RectOf(i);
                bool sel = i == hover;
                float pop = Mathf.Clamp01(anim * 1.4f - i * 0.15f);
                if (pop <= 0f) continue;
                var col = f.color;
                var rr = UiKit.Grow(r, (sel ? 4f : 0f) - (1f - pop) * 30f);
                CardBg(rr, col, sel, pop);
                float a = pop, x0 = rr.x + 14f, w = rr.width - 28f;
                var c = new Vector2(rr.x + rr.width * 0.5f, rr.y + 70f);
                var tex = UiKit.Art("familiar/" + f.id);
                if (tex != null)
                {
                    var pr = new Rect(rr.x + 4, rr.y + 4, rr.width - 8, 124);
                    L.img.DrawCover(tex, pr, a, 0.3f);
                    Fade(pr, 40f, a);
                }
                else { L.back.DrawCircle(c, 40f, Gd.WithA(col, 0.10f * a)); Familiar.Preview(L.front, f.id, c, t, col, a); }
                Txt(Face.Display, new Vector2(rr.x, rr.y + 142), f.name, 26, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, rr.width);
                Txt(Face.Body, new Vector2(rr.x, rr.y + 160), f.kana, 10, Gd.WithA(col, 0.9f * a), TextAnchor.MiddleCenter, rr.width);
                L.back.DrawRect(new Rect(x0, rr.y + 172, w, 20), Gd.WithA(col, 0.18f * a));
                Txt(Face.Bold, new Vector2(x0 + 6, rr.y + 187), f.role, 11, Gd.WithA(Gd.Lightened(col, 0.2f), a));
                Para(Face.Body, new Vector2(x0, rr.y + 212), f.desc, w, 11, 5, new Color(0.9f, 0.92f, 1f, a * 0.9f));
                Txt(Face.Bold, new Vector2(x0, rr.yMax - 26), "加護　" + f.passive, 11, Gd.WithA(Gd.C_GOLD, a));
            }
            Txt(Face.Body, new Vector2(0, CY + CH + 30), PickHint("選ぶ"), 14, new Color(0.85f, 0.88f, 1f, 0.9f * anim), TextAnchor.MiddleCenter, Gd.W);
        }
    }

    // =====================================================================
    /// <summary>主神／副神の選択。</summary>
    public class KamiChoiceView : ChoiceView
    {
        public List<string> ids = new List<string>();
        public string role = "主神";
        private const float CW = 190f, CH = 590f, CY = 176f;
        public KamiChoiceView(Transform parent) : base(parent, "kami") { }
        public void Open(List<string> i, string r) { ids = i; role = r; Show(); }
        public override int Count() => ids.Count;
        public override Rect RectOf(int i) => Row(i, ids.Count, CW, CH, CY);

        protected override void Draw()
        {
            bool main = role == "主神";
            Backdrop(Gd.C_GOLD);
            Txt(Face.Display, new Vector2(0, 104), main ? "主神を選べ" : "副神を迎えよ", 44, Gd.WithA(Gd.C_GOLD, anim), TextAnchor.MiddleCenter, Gd.W);
            Txt(Face.Body, new Vector2(0, 140), main ? "選んだ神の神器（自動で撃つ武器）が付く" : "神器がもう 1 つ加わる", 14, new Color(0.9f, 0.9f, 1f, 0.85f * anim), TextAnchor.MiddleCenter, Gd.W);
            for (int i = 0; i < ids.Count; i++) DrawCard(i);
            Txt(Face.Body, new Vector2(0, CY + CH + 30), PickHint("選ぶ"), 14, new Color(0.85f, 0.88f, 1f, 0.9f * anim), TextAnchor.MiddleCenter, Gd.W);
            if (hover >= 0 && hover < ids.Count)
            {
                var k = Data.KamiOf(ids[hover]);
                if (k != null) Txt(Face.Body, new Vector2(0, CY + CH + 54), "「" + k.intro + "」", 14, Gd.WithA(Data.ColorOf(k.color), 0.9f), TextAnchor.MiddleCenter, Gd.W);
            }
        }

        private void DrawCard(int i)
        {
            var k = Data.KamiOf(ids[i]);
            if (k == null) return;
            var r = RectOf(i);
            bool sel = i == hover;
            float pop = Mathf.Clamp01(anim * 1.4f - i * 0.15f);
            if (pop <= 0f) return;
            var col = Data.ColorOf(k.color); var col2 = Data.ColorOf(k.color2);
            var rr = UiKit.Grow(r, (sel ? 4f : 0f) - (1f - pop) * 30f);
            CardBg(rr, col, sel, pop);
            float a = pop, cx = rr.x + rr.width * 0.5f, x0 = rr.x + 14f, w = rr.width - 28f;
            var ec = new Vector2(cx - 44f, rr.y + 76f);
            if (sel) L.back.DrawCircle(ec, 48f + 4f * Mathf.Sin(t * 3f), Gd.WithA(col, 0.10f * a));
            UiKit.Emblem(L.front, k.emblem, ec, 34f, col, col2, t, a);
            WeaponPreview(k.id, new Rect(cx + 4f, rr.y + 26f, 72f, 100f), col, a);

            Txt(Face.Display, new Vector2(rr.x, rr.y + 166), k.name, 23, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, rr.width);
            Txt(Face.Body, new Vector2(rr.x, rr.y + 184), k.kana + "　" + k.title, 11, Gd.WithA(col, a * 0.9f), TextAnchor.MiddleCenter, rr.width);
            L.front.DrawLine(new Vector2(x0, rr.y + 196), new Vector2(rr.xMax - 14, rr.y + 196), Gd.WithA(col, 0.4f * a), 1f);
            L.back.DrawRect(new Rect(x0, rr.y + 206, w, 20), Gd.WithA(col, 0.18f * a));
            Txt(Face.Bold, new Vector2(x0 + 6, rr.y + 221), k.role, 12, Gd.WithA(Gd.Lightened(col, 0.2f), a));
            Txt(Face.Body, new Vector2(x0, rr.y + 248), "神器", 11, new Color(1, 0.9f, 0.7f, a * 0.85f));
            Txt(Face.Display, new Vector2(x0 + 32, rr.y + 250), k.weapon, 17, new Color(1, 1, 1, a));
            Para(Face.Body, new Vector2(x0, rr.y + 270), k.weapon_desc, w, 12, 4, new Color(0.9f, 0.92f, 1f, a * 0.9f));
            float y = rr.y + 352f;
            if (!string.IsNullOrEmpty(k.status))
            {
                L.back.DrawRect(new Rect(x0, y - 13, 56, 17), Gd.WithA(col, 0.25f * a));
                Txt(Face.Bold, new Vector2(x0, y), "神威 " + k.status, 11, Gd.WithA(col, a), TextAnchor.MiddleCenter, 56);
                Para(Face.Body, new Vector2(x0, y + 18), k.status_desc, w, 11, 3, new Color(0.85f, 0.9f, 1f, a * 0.85f));
            }
            else Para(Face.Body, new Vector2(x0, y + 2), k.status_desc ?? "", w, 11, 3, new Color(0.85f, 0.9f, 1f, a * 0.85f));
            y = rr.y + 430f;
            L.front.DrawLine(new Vector2(x0, y - 8), new Vector2(rr.xMax - 14, y - 8), Gd.WithA(col, 0.4f * a), 1f);
            int gr = Mathf.RoundToInt(Boons.GrowthOf(k.id) * 100f);
            if (role == "主神")
            {
                Txt(Face.Body, new Vector2(x0, y + 8), "詠唱", 11, new Color(1, 0.9f, 0.7f, a * 0.85f));
                Txt(Face.Display, new Vector2(x0 + 32, y + 9), k.cast, 14, new Color(1, 1, 1, a));
                Para(Face.Body, new Vector2(x0, y + 26), k.cast_desc, w, 11, 2, new Color(0.85f, 0.9f, 1f, a * 0.85f));
                Txt(Face.Body, new Vector2(x0, y + 70), "神招き", 11, new Color(1, 0.9f, 0.7f, a * 0.85f));
                Txt(Face.Display, new Vector2(x0 + 44, y + 71), k.call, 14, new Color(1, 1, 1, a));
                Para(Face.Body, new Vector2(x0, y + 88), k.call_desc, w, 11, 2, new Color(0.85f, 0.9f, 1f, a * 0.85f));
            }
            else Txt(Face.Body, new Vector2(x0, y + 8), "詠唱と神招きは主神のみ", 11, new Color(0.85f, 0.9f, 1f, a * 0.7f));
            Txt(Face.Bold, new Vector2(x0, y + 128), "神格の伸び +" + gr + "%", 12, Gd.WithA(gr > 12 ? Gd.C_GOLD : new Color(0.85f, 0.9f, 1f), a * 0.9f));
        }

        /// <summary>神器の実演（小さな枡の中で動く）。</summary>
        private void WeaponPreview(string id, Rect r, Color col, float a)
        {
            var v = L.front;
            v.DrawRect(r, new Color(0.03f, 0.02f, 0.06f, 0.7f * a));
            v.DrawRect(r, Gd.WithA(col, 0.35f * a), false, 1f);
            var c = new Vector2(r.center.x, r.yMax - 16f);
            float tt = t;
            v.DrawCircle(c, 4f, Gd.WithA(Gd.C_PLAYER, a));
            switch (id)
            {
                case "ama":
                    for (int i = -1; i <= 1; i++) { var d = Gd.Dir(-Mathf.PI * 0.5f + i * 0.25f); v.DrawLine(c, c + d * 80f, Gd.WithA(col, (0.5f + 0.3f * Mathf.Sin(tt * 6f + i)) * a), 4f); }
                    break;
                case "susa":
                    { float k = Mathf.Repeat(tt * 0.9f, 1f); var cw = c + new Vector2(0, -k * 80f); v.DrawArc(cw, 26f, Mathf.PI + 0.35f, Gd.TAU - 0.35f, 16, Gd.WithA(col, (1f - k) * a), 5f); break; }
                case "take":
                    { if (Mathf.Repeat(tt, 1.2f) < 0.25f) { var p0 = new Vector2(r.center.x + Mathf.Sin(tt * 7f) * 20f, r.y + 6f); v.DrawLine(p0, p0 + new Vector2(6, 26), Gd.WithA(col, a), 2.5f); v.DrawLine(p0 + new Vector2(6, 26), p0 + new Vector2(-4, 54), Gd.WithA(col, a), 2.5f); v.DrawLine(p0 + new Vector2(-4, 54), p0 + new Vector2(2, 74), Gd.WithA(col, a), 2f); } break; }
                case "tsuki":
                    for (int i = 0; i < 2; i++) { float ang = tt * 3f + Mathf.PI * i; v.DrawCircle(c + Gd.Dir(ang) * 24f, 4f, Gd.WithA(col, a)); v.DrawArc(c, 24f, ang - 0.6f, ang, 8, Gd.WithA(col, 0.5f * a), 2f); }
                    break;
                case "uzume":
                    { float k = Mathf.Repeat(tt * 0.8f, 1f); float yy = k < 0.5f ? k * 2f : (1f - k) * 2f; v.DrawArc(c + new Vector2(Mathf.Sin(k * Gd.TAU) * 14f, -yy * 76f), 9f, Mathf.PI + 0.3f, Gd.TAU - 0.3f, 10, Gd.WithA(col, a), 5f); break; }
                case "inari":
                    for (int i = 0; i < 3; i++) { float k = Mathf.Repeat(tt * 0.9f + i * 0.33f, 1f); var p = c + new Vector2(Mathf.Sin(k * 9f + i) * 14f, -k * 82f); v.DrawColoredPolygon(new[] { p + new Vector2(0, -8), p + new Vector2(4, 0), p + new Vector2(0, 4), p + new Vector2(-4, 0) }, Gd.WithA(col, (1f - k * 0.6f) * a)); }
                    break;
                case "suku":
                    { float k = Mathf.Repeat(tt * 0.7f, 1f); var p = c + new Vector2(Mathf.Sin(k * 3f) * 10f, -k * 70f); v.DrawCircle(p, 5f, Gd.WithA(Gd.C_PAPER, a)); v.DrawCircle(c + new Vector2(0, -75), 16f + 6f * Mathf.Sin(tt * 2f), Gd.WithA(col, 0.18f * a)); break; }
                case "iza":
                    for (int i = 0; i < 3; i++) { float k = Mathf.Repeat(tt * 1.1f + i * 0.3f, 1f); var p = c + new Vector2((i - 1) * 14f, -k * 84f); v.DrawColoredPolygon(new[] { p + new Vector2(0, -10), p + new Vector2(3, -2), p + new Vector2(2, 5), p + new Vector2(-2, 5), p + new Vector2(-3, -2) }, Gd.WithA(col, a)); }
                    break;
                case "saru":
                    for (int i = 0; i < 2; i++) { float k = Mathf.Repeat(tt * 1.3f + i * 0.5f, 1f); var p = c + new Vector2((i - 0.5f) * 16f, -k * 84f); v.DrawArc(p + new Vector2(0, 6), 12f, Mathf.PI + 0.6f, Gd.TAU - 0.6f, 8, Gd.WithA(col, (1f - k * 0.5f) * a), 3f); }
                    break;
            }
        }
    }

    // =====================================================================
    /// <summary>討伐の褒賞：神宝を 1 つ選ぶ。</summary>
    public class RelicView : ChoiceView
    {
        public List<RelicDef> offers = new List<RelicDef>();
        private const float CW = 190f, CH = 250f, CY = 300f;
        public RelicView(Transform parent) : base(parent, "relic") { }
        public void Open(List<RelicDef> o) { offers = o; Show(); RarityFx.Reveal(2); }
        public override int Count() => offers.Count;
        public override Rect RectOf(int i) => Row(i, offers.Count, CW, CH, CY);

        protected override void Draw()
        {
            Backdrop(Gd.C_GOLD);
            Txt(Face.Display, new Vector2(0, 150), "討伐の褒賞", 48, Gd.WithA(Gd.C_GOLD, anim), TextAnchor.MiddleCenter, Gd.W);
            Txt(Face.Body, new Vector2(0, 188), "神宝を 1 つ選ぶ", 15, new Color(0.9f, 0.9f, 1f, 0.85f * anim), TextAnchor.MiddleCenter, Gd.W);
            for (int i = 0; i < offers.Count; i++)
            {
                var o = offers[i];
                var r = RectOf(i);
                bool sel = i == hover;
                float pop = Mathf.Clamp01(anim * 1.5f - i * 0.1f);
                if (pop <= 0f) continue;
                var rr = UiKit.Grow(r, (sel ? 3f : 0f) - (1f - pop) * 20f);
                CardBg(rr, Gd.C_GOLD, sel, pop);
                RarityFx.Frame(L, rr, Gd.C_GOLD, 2, t, pop);
                var c = rr.position + new Vector2(rr.width * 0.5f, 74);
                var tex = UiKit.Art("relic/" + o.id);
                if (tex != null)
                {
                    var pr = new Rect(rr.x + 4, rr.y + 4, rr.width - 8, 126);
                    L.img.DrawCover(tex, pr, pop, 0.5f);
                    Fade(pr, 30f, pop, 5);
                }
                else
                {
                    L.back.DrawCircle(c, 40f + (sel ? 4f * Mathf.Sin(t * 3f) : 0f), Gd.WithA(Gd.C_GOLD, 0.12f * pop));
                    L.front.DrawArc(c, 32f, 0, Gd.TAU, 40, Gd.WithA(Gd.C_GOLD, 0.9f * pop), 2f);
                    L.front.DrawArc(c, 26f, t * 1.2f, t * 1.2f + 4f, 24, Gd.WithA(Gd.C_GOLD, 0.5f * pop), 1f);
                    Txt(Face.Display, new Vector2(c.x - 30, c.y + 12), o.mark ?? "", 30, new Color(1, 0.96f, 0.85f, pop), TextAnchor.MiddleCenter, 60, false);
                }
                Txt(Face.Display, rr.position + new Vector2(0, 148), o.name, 20, new Color(1, 1, 1, pop), TextAnchor.MiddleCenter, rr.width);
                Para(Face.Body, new Vector2(rr.x + 14, rr.y + 172), o.desc, rr.width - 28, 13, 3, new Color(0.92f, 0.94f, 1f, pop * 0.95f), TextAnchor.MiddleCenter);
            }
            Txt(Face.Body, new Vector2(0, CY + CH + 30f), PickHint("選ぶ"), 14, new Color(0.85f, 0.88f, 1f, 0.9f * anim), TextAnchor.MiddleCenter, Gd.W);
        }
    }

    // =====================================================================
    /// <summary>開幕の物語（起動ごとに 1 回）。</summary>
    public class StoryView : ChoiceView
    {
        private static readonly string[] LINES = { "参道は穢れに沈み、灯は消えた。", "神楽の巫女はひとり、八百万の神々に呼びかける。", "わたしが、やらなきゃ。" };
        public StoryView(Transform parent) : base(parent, "story") { }
        public override void Show() { base.Show(); t = 0f; }
        public float T => t;
        public override int Count() => 0;
        public override Rect RectOf(int i) => new Rect();

        protected override void Draw()
        {
            L.back.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.03f, 0.02f, 0.06f, 1f));
            var tex = UiKit.Art("cutin/opening");
            float a = Mathf.Clamp01(t * 1.5f);
            if (tex != null)
            {
                var pr = new Rect(0, 120, Gd.W, 360);
                L.img.DrawCover(tex, pr, a, 0.4f);
                var bg = new Color(0.03f, 0.02f, 0.06f);
                for (int gi = 0; gi < 8; gi++)
                {
                    float kk = gi / 8f;
                    L.front.DrawRect(new Rect(0, pr.yMax - 100f + kk * 100f, Gd.W, 100f / 8f + 1f), new Color(bg.r, bg.g, bg.b, 0.95f * kk * a));
                    L.front.DrawRect(new Rect(0, pr.y + kk * 60f, Gd.W, 60f / 8f + 1f), new Color(bg.r, bg.g, bg.b, 0.9f * (1f - kk) * a));
                }
            }
            float y = 540f;
            for (int i = 0; i < LINES.Length; i++)
            {
                float la = Mathf.Clamp01((t - 0.8f - i * 0.9f) * 1.5f);
                Txt(Face.Display, new Vector2(0, y), LINES[i], i < 2 ? 20 : 24, i < 2 ? new Color(1, 0.96f, 0.9f, la) : Gd.WithA(Gd.C_GOLD, la), TextAnchor.MiddleCenter, Gd.W);
                y += 44f;
            }
            if (t > 0.6f) { float blink = 0.5f + 0.5f * Mathf.Sin(t * 4f); Txt(Face.Body, new Vector2(0, Gd.H - 60f), "タップで進む", 14, new Color(1, 1, 1, 0.6f * blink), TextAnchor.MiddleCenter, Gd.W); }
        }
    }

    // =====================================================================
    /// <summary>選択画面の束（Godot 版 Ui の選択部分）。入力を受けてイベントを飛ばす。</summary>
    public class Views : MonoBehaviour
    {
        public ConfirmView confirm;
        public FamiliarView familiar;
        public KamiChoiceView kami;
        public BoonsView boons;
        public MikiView miki;
        public RelicView relic;
        public StoryView story;
        public ShopView shop;

        public Action<string> OnKamiChosen, OnFamiliarChosen, OnMikiChosen;
        public Action<int> OnBoonChosen, OnRelicChosen;
        public Action OnReroll, OnStoryDone, OnShopLeave;
        public Action<int> OnShopBuy;

        public static Views Create(Transform parent)
        {
            var go = new GameObject("views");
            go.transform.SetParent(parent, false);
            var v = go.AddComponent<Views>();
            var tr = go.transform;
            v.confirm = new ConfirmView(tr); v.familiar = new FamiliarView(tr); v.kami = new KamiChoiceView(tr);
            v.boons = new BoonsView(tr); v.miki = new MikiView(tr); v.relic = new RelicView(tr); v.story = new StoryView(tr); v.shop = new ShopView(tr);
            return v;
        }

        private IEnumerable<ChoiceView> All() { yield return confirm; yield return familiar; yield return kami; yield return boons; yield return miki; yield return relic; yield return story; yield return shop; }
        public bool ChoiceVisible { get { foreach (var v in All()) if (v.visible) return true; return false; } }
        public void HideCards() { foreach (var v in All()) v.Hide(); }

        public void ShowStory() { HideCards(); story.Show(); }
        public void ShowFamiliarChoice() { HideCards(); familiar.Show(); }
        public void ShowKamiChoice(List<string> ids, string role) { HideCards(); kami.Open(ids, role); }
        public void ShowBoons(string kid, List<Offer> offers, int rerolls, string title) { HideCards(); boons.Open(kid, offers, rerolls, title); }
        public void ShowMiki(List<string> ids) { HideCards(); miki.Open(ids); }
        public void ShowRelics(List<RelicDef> offers) { HideCards(); relic.Open(offers); }
        public void ShowShop(List<ShopOffer> offers, int ryo) { HideCards(); shop.Open(offers, ryo); }
        public void AskContract(string kid, string role, Action ok) { kami.Hide(); boons.Hide(); confirm.Open(kid, role, ok); }

        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            var g = GameManager.I;
            Vector2? mouse = null;
            if (g != null && !g.IsTouch && Mouse.current != null) mouse = TouchUi.ToPx(Mouse.current.position.ReadValue());
            foreach (var v in All()) v.Tick(dt, mouse);
            if (ChoiceVisible) HandleInput();
        }

        private void HandleInput()
        {
            var kb = Keyboard.current; var ms = Mouse.current; var ts = Touchscreen.current;
            bool tap = (ts != null && ts.primaryTouch.press.wasPressedThisFrame) || (ms != null && ms.leftButton.wasPressedThisFrame && (ts == null || !ts.primaryTouch.press.isPressed));
            Vector2 click = new Vector2(-1, -1);
            if (tap) click = TouchUi.ToPx(ts != null && ts.primaryTouch.press.wasPressedThisFrame ? ts.primaryTouch.position.ReadValue() : ms.position.ReadValue());
            int idx = -1;
            bool anyKey = false;
            if (kb != null)
            {
                Key[] nums = { Key.Digit1, Key.Digit2, Key.Digit3, Key.Digit4, Key.Digit5, Key.Digit6, Key.Digit7, Key.Digit8, Key.Digit9 };
                Key[] pads = { Key.Numpad1, Key.Numpad2, Key.Numpad3, Key.Numpad4, Key.Numpad5, Key.Numpad6, Key.Numpad7, Key.Numpad8, Key.Numpad9 };
                for (int i = 0; i < 9; i++) if (kb[nums[i]].wasPressedThisFrame || kb[pads[i]].wasPressedThisFrame) idx = i;
                anyKey = kb.anyKey.wasPressedThisFrame;
            }
            if (story.visible)
            {
                if ((anyKey || tap) && story.T > 0.6f) { story.Hide(); OnStoryDone?.Invoke(); }
                return;
            }
            if (confirm.visible)
            {
                bool ok = false, cancel = false;
                if (kb != null)
                {
                    ok = idx == 0 || kb.enterKey.wasPressedThisFrame || kb.numpadEnterKey.wasPressedThisFrame || kb.spaceKey.wasPressedThisFrame;
                    cancel = idx == 1 || kb.escapeKey.wasPressedThisFrame || kb.backspaceKey.wasPressedThisFrame;
                }
                if (click.x >= 0) { int ci = confirm.CardAt(click); ok |= ci == 0; cancel |= ci == 1; }
                if (ok) { Sfx.Play("descend", -4f, 1.3f); confirm.Hide(); confirm.onOk?.Invoke(); }
                else if (cancel)
                {
                    Sfx.Play("clap", -12f);
                    confirm.Hide();
                    if (kami.ids.Count > 0 && GameManager.I.choice == ChoiceKind.Kami) kami.visible = true;
                    else if (GameManager.I.choice == ChoiceKind.Boon) boons.visible = true;
                }
                return;
            }
            if (familiar.visible)
            {
                if (click.x >= 0) idx = familiar.CardAt(click);
                if (idx >= 0 && idx < Familiar.LIST.Count) { Sfx.Play("select", -8f); OnFamiliarChosen?.Invoke(Familiar.LIST[idx].id); }
            }
            else if (kami.visible)
            {
                if (click.x >= 0) idx = kami.CardAt(click);
                if (idx >= 0 && idx < kami.ids.Count)
                {
                    Sfx.Play("select", -8f);
                    string kid = kami.ids[idx];
                    kami.Hide();
                    AskContract(kid, kami.role, () => OnKamiChosen?.Invoke(kid));
                }
            }
            else if (boons.visible)
            {
                if (kb != null && kb.rKey.wasPressedThisFrame && boons.rerolls > 0) { OnReroll?.Invoke(); return; }
                if (click.x >= 0) idx = boons.CardAt(click);
                if (idx == 100) { if (boons.rerolls > 0) OnReroll?.Invoke(); return; }
                if (idx >= 0 && idx < boons.offers.Count) { Sfx.Play("select", -8f); Fx.ShakeAdd(3f); OnBoonChosen?.Invoke(idx); }
            }
            else if (miki.visible)
            {
                if (click.x >= 0) idx = miki.CardAt(click);
                if (idx >= 0 && idx < miki.ids.Count) { Sfx.Play("select", -8f); OnMikiChosen?.Invoke(miki.ids[idx]); }
            }
            else if (relic.visible)
            {
                if (click.x >= 0) idx = relic.CardAt(click);
                if (idx >= 0 && idx < relic.offers.Count) { Sfx.Play("select", -8f); Fx.ShakeAdd(3f); OnRelicChosen?.Invoke(idx); }
            }
            else if (shop.visible)
            {
                if (click.x >= 0) idx = shop.CardAt(click);
                bool leave = idx == ShopView.LEAVE || (kb != null && (kb.escapeKey.wasPressedThisFrame || kb.enterKey.wasPressedThisFrame));
                if (leave) { OnShopLeave?.Invoke(); return; }
                if (idx >= 0 && idx < shop.offers.Count) { Sfx.Play("select", -10f); OnShopBuy?.Invoke(idx); }
            }
        }
    }
}
