using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Kagura.Game
{
    /// <summary>題目・討たれた・踏破の画面（Godot 版 OverlayView の移植）。</summary>
    public class Overlay : MonoBehaviour
    {
        public int mode;   // 0 題目 1 討たれた 2 踏破
        public bool visible;
        public List<(string, string)> statsLines = new List<(string, string)>();
        public string tip = "";
        private float _t;
        private UiLayer _layer;
        private Texture2D _title;
        private class Petal { public Vector2 pos, vel; public float rot, spin, size; }
        private readonly List<Petal> _petals = new List<Petal>();
        public string versionLabel = "";

        public static Overlay Create(Transform parent)
        {
            var go = new GameObject("overlay");
            go.transform.SetParent(parent, false);
            var o = go.AddComponent<Overlay>();
            o._layer = UiLayer.Create(go.transform, "overlay_layer", Gd.ZHud + 20);
            o._title = Resources.Load<Texture2D>("Art/title");
            for (int i = 0; i < 40; i++)
                o._petals.Add(new Petal { pos = new Vector2(Random.value * Gd.W, Random.value * Gd.H), vel = new Vector2(Gd.Rand(-20, 20), Gd.Rand(40, 110)), rot = Random.value * Gd.TAU, spin = Gd.Rand(-3, 3), size = Gd.Rand(2.5f, 5f) });
            var ver = Resources.Load<TextAsset>("version");
            if (ver != null) { var lines = ver.text.Split('\n'); o.versionLabel = lines[0].Trim() + (lines.Length > 1 ? " (" + lines[1].Trim() + ")" : ""); }
            else o.versionLabel = "vdev (local)";
            return o;
        }

        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            _t += dt;
            foreach (var p in _petals)
            {
                p.pos += p.vel * dt;
                p.pos.x += Mathf.Sin(_t + p.rot) * 20f * dt;
                p.rot += p.spin * dt;
                if (p.pos.y > Gd.H + 10f) p.pos = new Vector2(Random.value * Gd.W, -10f);
            }
            if (!visible) { _layer.Clear(); return; }
            _layer.Begin();
            if (mode == 0) DrawTitle();
            else if (mode == 2) DrawClear();
            else DrawOver();
            _layer.End();
        }

        // ---------- 題目 ----------

        public Rect MenuRect(int i)
        {
            float w = Gd.W - 140f;
            float h = i == 0 ? 58f : 48f;
            float y = Gd.H - 62f - 48f - 48f - 58f - 12f * 2f;
            for (int j = 0; j < i; j++) y += (j == 0 ? 58f : 48f) + 12f;
            return new Rect(70f, y, w, h);
        }

        public int MenuAt(Vector2 px)
        {
            for (int i = 0; i < 3; i++) if (MenuRect(i).Contains(px)) return i;
            return -1;
        }

        private void DrawTitle()
        {
            var l = _layer; var v = l.front;
            if (_title != null)
            {
                float tw = _title.width, th = _title.height;
                float scale = Gd.H / th;
                float srcW = Gd.W / scale;
                float srcX = Mathf.Clamp(1100f - srcW * 0.5f, 0f, tw - srcW);
                l.img.Draw(_title, new Rect(0, 0, Gd.W, Gd.H), new Rect(srcX, 0, srcW, th), new Color(0.92f, 0.88f, 1f));
            }
            else l.back.DrawRect(new Rect(0, 0, Gd.W, Gd.H), Gd.C_BG);
            for (int i = 0; i < 14; i++)
            {
                float k = i / 14f;
                v.DrawRect(new Rect(0, k * 330f, Gd.W, 330f / 14f + 1f), new Color(0.05f, 0.02f, 0.10f, 0.85f * (1f - k)));
                v.DrawRect(new Rect(0, Gd.H - 330f + k * 330f, Gd.W, 330f / 14f + 1f), new Color(0.05f, 0.02f, 0.10f, 0.88f * k));
            }
            foreach (var p in _petals)
            {
                Vector2 d = Gd.Dir(p.rot), n = Gd.Orth(d);
                float s = p.size;
                v.DrawColoredPolygon(new[] { p.pos + d * s * 1.5f, p.pos + n * s * 0.7f, p.pos - d * s * 1.5f, p.pos - n * s * 0.7f }, new Color(0.9f, 0.7f, 1f, 0.5f));
            }
            float bob = Mathf.Sin(_t * 1.6f) * 3f;
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 178 + bob), "神楽", 122, new Color(0.98f, 0.94f, 1f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 214 + bob), "K A G U R A   A S C E N T", 17, new Color(0.85f, 0.6f, 1f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 252 + bob), "八百万の加護を纏いて、穢れを祓え", 17, new Color(1, 0.9f, 0.75f, 0.95f), TextAnchor.MiddleCenter, Gd.W);

            bool touch = GameManager.I != null && GameManager.I.IsTouch;
            var rows = Records.Entries;
            int cnt3 = Mathf.Min(rows.Count, 3);
            float rh = 26f + 20f * Mathf.Max(cnt3, 1);
            float ry = MenuRect(0).yMin - rh - 34f;
            DrawRecords(ry, 3, -1, 0.95f);
            if (Records.Best.clears > 0)
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, ry - 8f), $"踏破 {Records.Best.clears} 回　最高功徳 {Records.Best.score}", 11, Gd.WithA(Gd.C_GOLD, 0.9f), TextAnchor.MiddleCenter, Gd.W);
            string[] labels = { "はじめる", "記録を見る", Records.PlayerName.Trim() == "" ? "名を刻む" : $"名を変える（{Records.DisplayName()}）" };
            string[] keys = { "Enter", "R", "N" };
            float blink = 0.75f + 0.25f * Mathf.Sin(_t * 4f);
            for (int i = 0; i < 3; i++)
            {
                var r = MenuRect(i);
                bool main = i == 0;
                Color col = main ? Gd.C_GOLD : new Color(0.8f, 0.8f, 0.95f);
                v.DrawRect(UiKit.Grow(r, 3f), new Color(0, 0, 0, 0.45f));
                v.DrawRect(r, main ? new Color(0.16f, 0.11f, 0.08f, 0.95f) : new Color(0.09f, 0.06f, 0.14f, 0.92f));
                v.DrawRect(r, Gd.WithA(col, main ? blink : 0.55f), false, main ? 2f : 1.2f);
                foreach (float cx in new[] { r.xMin + 6f, r.xMax - 6f }) v.DrawCircle(new Vector2(cx, r.center.y), 2f, Gd.WithA(col, 0.9f));
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(r.xMin, r.center.y + 9f), labels[i], main ? 24 : 19, main ? Color.white : Gd.WithA(col, 0.95f), TextAnchor.MiddleCenter, r.width);
                if (!touch) UiKit.Txt(l, WorldText.Face.Body, new Vector2(r.xMax - 60f, r.center.y + 5f), keys[i], 11, new Color(1, 1, 1, 0.45f), TextAnchor.MiddleRight, 48f);
            }
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H - 12), versionLabel, 10, new Color(1, 1, 1, 0.45f), TextAnchor.MiddleRight, Gd.W - 12f);
        }

        /// <summary>記録表（上位 n 件）。</summary>
        private float DrawRecords(float y0, int n, int highlightRun, float a = 1f)
        {
            var l = _layer; var v = l.front;
            var rows = Records.Entries;
            int cnt = Mathf.Min(rows.Count, n);
            float x0 = 36f, w = Gd.W - 72f;
            float h = 26f + 20f * Mathf.Max(cnt, 1);
            UiKit.Panel(v, new Rect(x0, y0, w, h), Gd.C_GOLD, a, 0.78f);
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(x0 + 12, y0 + 17), "この端末の記録", 12, Gd.WithA(Gd.C_GOLD, a));
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0 + 110, y0 + 16), $"巫女 {Records.DisplayName()}", 10, new Color(1, 1, 1, 0.75f * a));
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "功徳", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 250f);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "到達", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 130f);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "神々", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 12f);
            if (cnt == 0) UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 40), "まだ記録がない。参道を登り、名を刻め", 11, new Color(1, 1, 1, 0.55f * a), TextAnchor.MiddleCenter, w);
            float y = y0 + 40f;
            for (int i = 0; i < cnt; i++)
            {
                var e = rows[i];
                bool mine = e.run == highlightRun && highlightRun >= 0;
                Color col = mine ? Gd.C_GOLD : new Color(0.92f, 0.92f, 1f);
                if (mine) v.DrawRect(new Rect(x0 + 4, y - 14, w - 8, 19), Gd.WithA(Gd.C_GOLD, 0.14f * a));
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(x0 + 12, y), (i + 1).ToString(), 11, Gd.WithA(col, a * (i < 3 ? 1f : 0.7f)));
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0 + 34, y), e.name, 11, Gd.WithA(col, a));
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(x0, y), e.score.ToString(), 11, Gd.WithA(col, a), TextAnchor.MiddleRight, w - 250f);
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y), Records.ReachText(e), 10, Gd.WithA(col, a * 0.9f), TextAnchor.MiddleRight, w - 130f);
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y), Records.GodsText(e), 10, Gd.WithA(col, a * 0.8f), TextAnchor.MiddleRight, w - 12f);
                y += 20f;
            }
            return y0 + h;
        }

        // ---------- 結果 ----------

        private void DrawClear()
        {
            var l = _layer; var v = l.front; var b = l.back;
            b.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.03f, 0.02f, 0.06f, 0.82f));
            var tex = UiKit.Art("scene/clear");
            if (tex != null)
            {
                l.img.DrawCover(tex, new Rect(0, 0, Gd.W, Gd.H), 0.55f, 0.3f);
                for (int gi = 0; gi < 10; gi++) { float kk = gi / 10f; v.DrawRect(new Rect(0, 260f + kk * (Gd.H - 260f), Gd.W, (Gd.H - 260f) / 10f + 1f), new Color(0.03f, 0.02f, 0.06f, 0.85f * Mathf.Min(1f, kk * 2f))); }
            }
            UiKit.Pattern(v, new Rect(0, 0, Gd.W, Gd.H), Gd.WithA(Gd.C_GOLD, 0.06f), 52f, _t);
            var win = UiKit.Art("cutin/clear");
            if (win != null)
            {
                var wr = new Rect(0, 40, Gd.W, 170);
                l.img.DrawCover(win, wr, 0.95f, 0.3f);
                for (int gi = 0; gi < 6; gi++) { float kk = gi / 6f; v.DrawRect(new Rect(0, wr.yMax - 60f + kk * 60f, Gd.W, 60f / 6f + 1f), new Color(0.03f, 0.02f, 0.06f, 0.9f * kk)); }
                v.DrawRect(new Rect(0, wr.yMin, Gd.W, 2), Gd.WithA(Gd.C_GOLD, 0.9f));
                var sm = UiKit.Art("portrait/smile");
                if (sm != null) { float sh = 250f, sw = sh * sm.width / (float)sm.height; l.img.Draw(sm, new Rect(Gd.W - sw + 30f, 10f, sw, sh), new Color(1, 1, 1, 0.95f)); }
            }
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 250), "踏破", 66, Gd.C_GOLD, TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 284), "奥宮の穢れは祓われ、参道に朝日が差した", 13, new Color(1, 0.95f, 0.85f, 0.9f), TextAnchor.MiddleCenter, Gd.W);
            float y = DrawStats(340f, new Color(0.85f, 0.8f, 0.65f));
            y = DrawRank(y);
            var g = GameManager.I;
            if (g != null && g.player != null) g.hud.DrawBuild(l, g.player, y + 16f);
            float blink = 0.55f + 0.45f * Mathf.Sin(_t * 4f);
            bool touch = g != null && g.IsTouch;
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H - 96f), touch ? "タップで更に登る（祟りの参道）" : "タップ / ENTER で更に登る（祟りの参道）", 20, new Color(1, 1, 1, blink), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H - 66f), touch ? "右上の「休」から題目へ戻れる" : "R で最初から　　ESC で題目へ", 13, new Color(0.9f, 0.9f, 1f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
        }

        private void DrawOver()
        {
            var l = _layer; var v = l.front; var b = l.back;
            b.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.01f, 0.05f, 0.8f));
            var tex = UiKit.Art("scene/gameover");
            if (tex != null)
            {
                l.img.DrawCover(tex, new Rect(0, 0, Gd.W, Gd.H), 0.5f, 0.3f);
                for (int gi = 0; gi < 10; gi++) { float kk = gi / 10f; v.DrawRect(new Rect(0, 240f + kk * (Gd.H - 240f), Gd.W, (Gd.H - 240f) / 10f + 1f), new Color(0.02f, 0.01f, 0.05f, 0.88f * Mathf.Min(1f, kk * 2f))); }
            }
            UiKit.Pattern(v, new Rect(0, 0, Gd.W, Gd.H), new Color(1, 0.3f, 0.4f, 0.04f), 52f, _t);
            var pain = UiKit.Art("portrait/pain");
            if (pain != null) { float ph = 300f, pw = ph * pain.width / (float)pain.height; l.img.Draw(pain, new Rect(Gd.W - pw + 40f, 20f, pw, ph), new Color(1, 1, 1, 0.9f)); }
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 200), "討たれた", 58, new Color(1, 0.3f, 0.4f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 234), "神楽は途切れ、参道は闇に沈んだ", 13, new Color(0.9f, 0.8f, 0.85f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
            float y = DrawStats(290f, new Color(0.65f, 0.75f, 0.9f));
            if (tip != "")
            {
                UiKit.Panel(v, new Rect(50, y + 4, Gd.W - 100, 48), Gd.C_GOLD, 1f, 0.8f);
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(62, y + 22), "次の一手", 11, Gd.C_GOLD);
                UiKit.Para(l, WorldText.Face.Body, new Vector2(62, y + 40), tip, Gd.W - 124, 11, 2, new Color(0.95f, 0.95f, 1f, 0.95f));
                y += 60f;
            }
            y = DrawRank(y);
            var g = GameManager.I;
            if (g != null && g.player != null) g.hud.DrawBuild(l, g.player, y + 16f);
            float blink = 0.55f + 0.45f * Mathf.Sin(_t * 4f);
            bool touch = g != null && g.IsTouch;
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H - 96f), touch ? "タップで題目へ" : "タップ / ENTER で題目へ", 20, new Color(1, 1, 1, blink), TextAnchor.MiddleCenter, Gd.W);
        }

        private float DrawStats(float y, Color labelCol)
        {
            foreach (var row in statsLines)
            {
                UiKit.Txt(_layer, WorldText.Face.Body, new Vector2(0, y), row.Item1, 15, labelCol, TextAnchor.MiddleRight, Gd.W * 0.5f - 14f);
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(Gd.W * 0.5f + 14f, y), row.Item2, 18, Color.white);
                y += 30f;
            }
            return y;
        }

        public int rank, globalRank;
        private float DrawRank(float y)
        {
            if (globalRank != 0)
            {
                string gtxt = globalRank > 0 ? $"世界の記録　第 {globalRank} 位" : globalRank == -2 ? "世界の記録　送れなかった" : "世界の記録　送信中…";
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(0, y + 2), gtxt, 17, globalRank > 0 ? new Color(0.75f, 0.9f, 1f) : new Color(0.8f, 0.8f, 0.9f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
                y += 22f;
            }
            if (rank > 0)
            {
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(0, y + 18), $"この端末の記録　第 {rank} 位に刻まれた", 17, Gd.C_GOLD, TextAnchor.MiddleCenter, Gd.W);
                y += 40f;
            }
            // 名を刻む（結果画面）：順位の下の札
            string label = Records.PlayerName.Trim() == "" ? "名を刻む" : $"名を変える（{Records.DisplayName()}）";
            float bw = Mathf.Max(150f, label.Length * 13f + 40f);
            nameBtn = new Rect(Gd.W * 0.5f - bw * 0.5f, y + 2f, bw, 32f);
            nameBtnShown = true;
            UiKit.Panel(_layer.back, nameBtn, Gd.C_GOLD, 1f, 0.8f);
            UiKit.Txt(_layer, WorldText.Face.Bold, new Vector2(nameBtn.x, nameBtn.y + 21f), label, 12, Gd.C_GOLD, TextAnchor.MiddleCenter, nameBtn.width);
            return y + 40f;
        }
        public Rect nameBtn; public bool nameBtnShown;
    }
}
