using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// UI の部品（Godot 版 Ui の static 関数と Emblem の移植）。漆塗りの板に金の縁、装飾つきのゲージ、神々の紋章。
    /// </summary>
    public static class UiKit
    {
        public static readonly Color LACQUER = new Color(0.07f, 0.045f, 0.10f, 0.92f);
        public static readonly Color GOLD = new Color(0.95f, 0.80f, 0.45f);

        private static readonly Dictionary<string, Texture2D> _art = new Dictionary<string, Texture2D>();

        /// <summary>絵（Resources/Art/&lt;name&gt;）。無ければ null。</summary>
        public static Texture2D Art(string name)
        {
            if (_art.TryGetValue(name, out var t)) return t;
            t = Resources.Load<Texture2D>("Art/" + name);
            _art[name] = t;
            return t;
        }

        /// <summary>小さい文字は少し大きく描く（本文は 1.12 倍、最小 11。大見出しはそのまま）。</summary>
        public static float Fsize(float size) => size >= 26f ? size : Mathf.Max(11f, Mathf.Round(size * 1.12f));

        /// <summary>Godot 版 Ui.txt。pos はベースライン左端（左寄せ）。width を指定すると中央/右寄せの基準幅になる。</summary>
        public static void Txt(UiLayer l, WorldText.Face f, Vector2 pos, string s, float size, Color col, TextAnchor align = TextAnchor.MiddleLeft, float width = -1f, bool shadow = true)
        {
            if (string.IsNullOrEmpty(s)) return;
            float sz = Fsize(size);
            // Godot の draw_string はベースライン基準。文字の中心は約 0.35 文字ぶん上
            Vector2 p = pos + new Vector2(0, -sz * 0.36f);
            TextAnchor a = TextAnchor.MiddleLeft;
            if (align == TextAnchor.MiddleCenter || align == TextAnchor.UpperCenter || align == TextAnchor.LowerCenter) { a = TextAnchor.MiddleCenter; p.x += (width > 0f ? width : 0f) * 0.5f; }
            else if (align == TextAnchor.MiddleRight || align == TextAnchor.UpperRight || align == TextAnchor.LowerRight) { a = TextAnchor.MiddleRight; p.x += width > 0f ? width : 0f; }
            l.text.Draw(p, s, sz, col, f, a, shadow);
        }

        /// <summary>縦書き（1 文字ずつ下へ）。</summary>
        public static void Vtxt(UiLayer l, WorldText.Face f, Vector2 pos, string s, float size, Color col)
        {
            float y = pos.y;
            foreach (var ch in s)
            {
                l.text.Draw(new Vector2(pos.x, y - size * 0.36f), ch.ToString(), size, col, f, TextAnchor.MiddleCenter, true);
                y += size * 1.08f;
            }
        }

        /// <summary>複数行（幅で折り返す）。pos は 1 行目のベースライン左端。</summary>
        public static void Para(UiLayer l, WorldText.Face f, Vector2 pos, string s, float width, float size, int lines, Color col, TextAnchor align = TextAnchor.MiddleLeft)
        {
            float sz = Fsize(size);
            var ls = Wrap(s, width, sz);
            for (int i = 0; i < ls.Count && i < lines; i++)
                Txt(l, f, pos + new Vector2(0, i * sz * 1.35f), ls[i], size, col, align, width);
        }

        /// <summary>文字数ベースの簡易折り返し（日本語は 1 文字 ≒ size px、英数は 0.55）。</summary>
        public static List<string> Wrap(string s, float width, float sz)
        {
            var out_ = new List<string>();
            foreach (var para in s.Split('\n'))
            {
                var line = new System.Text.StringBuilder();
                float w = 0f;
                foreach (var ch in para)
                {
                    float cw = ch < 0x2E80 ? sz * 0.55f : sz * 1.02f;
                    if (w + cw > width && line.Length > 0) { out_.Add(line.ToString()); line.Clear(); w = 0f; }
                    line.Append(ch); w += cw;
                }
                out_.Add(line.ToString());
            }
            return out_;
        }

        /// <summary>麻の葉風の背景模様。</summary>
        public static void Pattern(Vec v, Rect rect, Color col, float step = 46f, float t = 0f)
        {
            float off = Mathf.Repeat(t * 6f, step);
            float y = rect.yMin - step + off;
            int row = 0;
            while (y < rect.yMax + step)
            {
                float x = rect.xMin - step + (row % 2 == 1 ? step * 0.5f : 0f);
                while (x < rect.xMax + step)
                {
                    Vector2 c = new Vector2(x, y);
                    for (int i = 0; i < 6; i++)
                    {
                        float a0 = Gd.TAU * i / 6f, a1 = Gd.TAU * (i + 1) / 6f;
                        Vector2 p0 = c + Gd.Dir(a0) * step * 0.5f, p1 = c + Gd.Dir(a1) * step * 0.5f;
                        v.DrawLine(p0, p1, col, 1f);
                        v.DrawLine(c, p0, col, 1f);
                    }
                    x += step;
                }
                y += step * 0.87f;
                row++;
            }
        }

        public static Rect Grow(Rect r, float g) => new Rect(r.xMin - g, r.yMin - g, r.width + g * 2f, r.height + g * 2f);

        /// <summary>漆の板：暗い地に金の細縁と角飾り。</summary>
        public static void Panel(Vec v, Rect r, Color col, float a = 1f, float fillA = 0.85f)
        {
            v.DrawRect(Grow(r, 2f), new Color(0, 0, 0, 0.35f * a));
            v.DrawRect(r, new Color(LACQUER.r, LACQUER.g, LACQUER.b, fillA * a));
            v.DrawRect(r, Gd.WithA(col, 0.55f * a), false, 1.2f);
            v.DrawRect(Grow(r, -3f), Gd.WithA(col, 0.18f * a), false, 1f);
            foreach (float cx in new[] { r.xMin + 5f, r.xMax - 5f })
                foreach (float cy in new[] { r.yMin + 5f, r.yMax - 5f })
                    v.DrawCircle(new Vector2(cx, cy), 1.6f, Gd.WithA(col, 0.9f * a));
        }
        public static void Panel(Vec v, Rect r) => Panel(v, r, GOLD);

        /// <summary>装飾つきの横ゲージ：内側の光、上端のハイライト、目盛り、流れる光沢。</summary>
        public static void Bar(Vec v, Rect r, float k, Color col, float t, int ticks = 4, Color? frame = null)
        {
            Color fr = frame ?? GOLD;
            v.DrawRect(Grow(r, 3f), new Color(0, 0, 0, 0.5f));
            v.DrawRect(Grow(r, 1f), Gd.WithA(fr, 0.55f), false, 1f);
            v.DrawRect(r, new Color(0.06f, 0.04f, 0.09f, 0.95f));
            k = Mathf.Clamp01(k);
            if (k > 0f)
            {
                var f = new Rect(r.xMin, r.yMin, r.width * k, r.height);
                v.DrawRect(f, Gd.Darkened(col, 0.35f));
                v.DrawRect(new Rect(f.xMin, f.yMin, f.width, f.height * 0.55f), col);
                v.DrawRect(new Rect(f.xMin, f.yMin, f.width, 2f), new Color(1, 1, 1, 0.35f));
                float sx = Mathf.Repeat(t * 120f, r.width + 60f) - 30f;
                float gx = Mathf.Clamp(sx, 0f, f.width);
                if (sx > 0f && sx < f.width) v.DrawRect(new Rect(f.xMin + gx - 8f, f.yMin, 16f, f.height), new Color(1, 1, 1, 0.16f));
                v.DrawCircle(new Vector2(f.xMax, f.yMin + f.height * 0.5f), f.height * 0.55f, Gd.WithA(Gd.Lightened(col, 0.4f), 0.55f));
            }
            for (int i = 1; i < ticks; i++)
            {
                float x = r.xMin + r.width * i / ticks;
                v.DrawLine(new Vector2(x, r.yMin), new Vector2(x, r.yMax), new Color(0, 0, 0, 0.45f), 1f);
            }
            v.DrawRect(r, new Color(1, 1, 1, 0.12f), false, 1f);
        }

        /// <summary>神格の輪：紋章の周りに神徳の溜まりを弧で示す。</summary>
        public static void KamiRing(UiLayer l, Player p, string id, Vector2 c, float r, float t, float a = 1f, bool showLv = true)
        {
            var k = Data.KamiOf(id);
            if (k == null) return;
            Color col = Data.ColorOf(k.color);
            int lv = p.KamiLv(id);
            float need = Kagura.Core.Boons.KamiXpNeed(lv);
            float frac = lv < 10 ? Mathf.Clamp01(p.KamiXp(id) / Mathf.Max(1f, need)) : 1f;
            var v = l.front;
            v.DrawCircle(c, r + 6f, new Color(0.05f, 0.03f, 0.08f, 0.7f * a));
            v.DrawArc(c, r + 5f, 0, Gd.TAU, 40, Gd.WithA(col, 0.25f * a), 3f);
            v.DrawArc(c, r + 5f, -Mathf.PI * 0.5f, -Mathf.PI * 0.5f + Gd.TAU * frac, 40, Gd.WithA(col, 0.95f * a), 3f);
            Emblem(v, k.emblem, c, r, col, Data.ColorOf(k.color2), t, a);
            if (showLv)
            {
                Vector2 bp = c + new Vector2(r * 0.75f, r * 0.75f);
                v.DrawCircle(bp, 8.5f, new Color(0.05f, 0.03f, 0.08f, 0.95f * a));
                v.DrawArc(bp, 8.5f, 0, Gd.TAU, 16, Gd.WithA(col, 0.9f * a), 1.2f);
                Txt(l, WorldText.Face.Bold, bp + new Vector2(-8.5f, 4f), lv.ToString(), 10, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, 17f, false);
            }
        }

        /// <summary>神々の紋章（Godot 版 Emblem.draw）。</summary>
        public static void Emblem(Vec ci, string kind, Vector2 c, float r, Color col, Color col2, float t, float alpha = 1f)
        {
            Color a = Gd.WithA(col, alpha), a2 = Gd.WithA(col2, alpha), wt = new Color(1, 1, 1, alpha * 0.9f), ink = Gd.WithA(Gd.C_INK, alpha);
            ci.DrawCircle(c, r * 1.15f, Gd.WithA(col, 0.10f * alpha));
            ci.DrawArc(c, r * 1.15f, 0, Gd.TAU, 48, Gd.WithA(col, 0.35f * alpha), 1.5f);
            switch (kind)
            {
                case "sun":
                    for (int i = 0; i < 12; i++)
                    {
                        float ang = t * 0.3f + Gd.TAU * i / 12f;
                        float len = r * (i % 2 == 0 ? 1f : 0.82f);
                        ci.DrawLine(c + Gd.Dir(ang) * r * 0.62f, c + Gd.Dir(ang) * len, a2, r * 0.07f);
                    }
                    ci.DrawCircle(c, r * 0.55f, a);
                    ci.DrawCircle(c, r * 0.40f, Gd.WithA(new Color(1, 0.97f, 0.85f), alpha));
                    ci.DrawArc(c, r * 0.5f, 0, Gd.TAU, 32, wt, 1.5f);
                    break;
                case "storm":
                    for (int i = 0; i < 3; i++)
                    {
                        float y = c.y - r * 0.35f + i * r * 0.32f;
                        var pts = new Vector2[13];
                        for (int j = 0; j < 13; j++) { float k = j / 12f; pts[j] = new Vector2(c.x - r * 0.85f + k * r * 1.7f, y + Mathf.Sin(k * Gd.TAU * 1.5f + t * 2f + i) * r * 0.12f); }
                        ci.DrawPolyline(pts, Gd.WithA(col, alpha * (1f - i * 0.25f)), r * 0.09f);
                    }
                    ci.DrawLine(c + new Vector2(r * 0.45f, r * 0.6f), c + new Vector2(-r * 0.3f, -r * 0.75f), wt, r * 0.08f);
                    ci.DrawLine(c + new Vector2(-r * 0.05f, -r * 0.35f), c + new Vector2(-r * 0.4f, -r * 0.05f), a2, r * 0.09f);
                    break;
                case "thunder":
                    {
                        var pts2 = new[] { c + new Vector2(r * 0.15f, -r * 0.95f), c + new Vector2(-r * 0.35f, r * 0.05f), c + new Vector2(r * 0.02f, r * 0.05f), c + new Vector2(-r * 0.2f, r * 0.95f), c + new Vector2(r * 0.45f, -r * 0.15f), c + new Vector2(r * 0.08f, -r * 0.15f) };
                        ci.DrawColoredPolygon(pts2, a);
                        ci.DrawPolyline(new[] { pts2[0], pts2[1], pts2[2], pts2[3], pts2[4], pts2[5], pts2[0] }, wt, 1.5f);
                        for (int i = 0; i < 4; i++) ci.DrawCircle(c + Gd.Dir(t * 1.5f + Gd.TAU * i / 4f) * r * 0.95f, 2f, a2);
                        break;
                    }
                case "moon":
                    ci.DrawCircle(c, r * 0.75f, a);
                    ci.DrawCircle(c + new Vector2(r * 0.3f, -r * 0.15f), r * 0.62f, Gd.WithA(Color.Lerp(Gd.C_BG, col2, 0.25f), alpha));
                    ci.DrawCircle(c + new Vector2(-r * 0.55f, r * 0.4f), r * 0.06f, wt);
                    ci.DrawCircle(c + new Vector2(r * 0.7f, r * 0.6f), r * 0.05f, wt);
                    ci.DrawCircle(c + new Vector2(r * 0.5f, -r * 0.8f), r * 0.04f, wt);
                    break;
                case "fan":
                    {
                        float a0 = Mathf.PI * 1.15f, a1 = Mathf.PI * 1.85f;
                        Vector2 piv = c + new Vector2(0, r * 0.5f);
                        ci.DrawArc(piv, r, a0, a1, 24, a, r * 0.16f);
                        ci.DrawArc(piv, r * 0.86f, a0, a1, 24, a2, r * 0.06f);
                        for (int i = 0; i < 7; i++) ci.DrawLine(piv, piv + Gd.Dir(Mathf.Lerp(a0, a1, i / 6f)) * r * 0.9f, ink, 1.2f);
                        ci.DrawCircle(piv, r * 0.08f, wt);
                        ci.DrawCircle(c + new Vector2(0, -r * 0.35f), r * 0.16f, Gd.WithA(new Color(0.85f, 0.2f, 0.3f), alpha));
                        break;
                    }
                case "fox":
                    {
                        var face = new[] { c + new Vector2(0, r * 0.95f), c + new Vector2(r * 0.7f, r * 0.1f), c + new Vector2(r * 0.55f, -r * 0.9f), c + new Vector2(r * 0.2f, -r * 0.35f), c + new Vector2(-r * 0.2f, -r * 0.35f), c + new Vector2(-r * 0.55f, -r * 0.9f), c + new Vector2(-r * 0.7f, r * 0.1f) };
                        ci.DrawColoredPolygon(face, Gd.WithA(Gd.C_PAPER, alpha));
                        var outline = new List<Vector2>(face) { face[0] };
                        ci.DrawPolyline(outline, a, 2f);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(r * 0.55f, -r * 0.9f), c + new Vector2(r * 0.2f, -r * 0.35f), c + new Vector2(r * 0.45f, -r * 0.3f) }, a2);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(-r * 0.55f, -r * 0.9f), c + new Vector2(-r * 0.2f, -r * 0.35f), c + new Vector2(-r * 0.45f, -r * 0.3f) }, a2);
                        var red = Gd.WithA(new Color(0.85f, 0.2f, 0.3f), alpha);
                        ci.DrawLine(c + new Vector2(-r * 0.45f, -r * 0.05f), c + new Vector2(-r * 0.2f, r * 0.1f), red, r * 0.08f);
                        ci.DrawLine(c + new Vector2(r * 0.45f, -r * 0.05f), c + new Vector2(r * 0.2f, r * 0.1f), red, r * 0.08f);
                        ci.DrawCircle(c + new Vector2(0, r * 0.45f), r * 0.06f, ink);
                        break;
                    }
                case "gourd":
                    ci.DrawCircle(c + new Vector2(0, r * 0.35f), r * 0.55f, a);
                    ci.DrawCircle(c + new Vector2(0, -r * 0.35f), r * 0.38f, a);
                    ci.DrawRect(new Rect(c.x - r * 0.12f, c.y - r * 0.95f, r * 0.24f, r * 0.25f), a2);
                    ci.DrawArc(c + new Vector2(0, r * 0.35f), r * 0.55f, 0, Gd.TAU, 32, wt, 1.5f);
                    ci.DrawArc(c + new Vector2(0, -r * 0.35f), r * 0.38f, 0, Gd.TAU, 24, wt, 1.5f);
                    ci.DrawLine(c + new Vector2(-r * 0.3f, -r * 0.05f), c + new Vector2(r * 0.3f, -r * 0.05f), a2, r * 0.06f);
                    ci.DrawCircle(c + new Vector2(r * 0.18f, r * 0.2f), r * 0.08f, new Color(1, 1, 1, alpha * 0.6f));
                    break;
                case "gate":
                    {
                        var rock = new[] { c + new Vector2(-r * 0.8f, r * 0.8f), c + new Vector2(-r * 0.9f, -r * 0.2f), c + new Vector2(-r * 0.5f, -r * 0.85f), c + new Vector2(r * 0.3f, -r * 0.9f), c + new Vector2(r * 0.85f, -r * 0.3f), c + new Vector2(r * 0.75f, r * 0.8f) };
                        ci.DrawColoredPolygon(rock, Gd.WithA(Gd.Darkened(col2, 0.4f), alpha));
                        var outline = new List<Vector2>(rock) { rock[0] };
                        ci.DrawPolyline(outline, a, 2f);
                        ci.DrawPolyline(new[] { c + new Vector2(r * 0.05f, -r * 0.9f), c + new Vector2(-r * 0.1f, -r * 0.3f), c + new Vector2(r * 0.15f, r * 0.1f), c + new Vector2(0, r * 0.8f) }, a, r * 0.07f);
                        for (int i = 0; i < 3; i++)
                        {
                            float y = c.y + r * 0.7f - Mathf.Repeat(t * 0.6f + i * 0.5f, 1.5f) * r;
                            ci.DrawCircle(new Vector2(c.x + Mathf.Sin(t * 2f + i) * r * 0.15f, y), r * 0.06f, wt);
                        }
                        break;
                    }
                case "road":
                    ci.DrawLine(c + new Vector2(-r * 0.95f, r * 0.05f), c + new Vector2(r * 0.95f, -r * 0.05f), a, r * 0.16f);
                    ci.DrawLine(c + new Vector2(-r * 0.7f, r * 0.32f), c + new Vector2(r * 0.7f, r * 0.32f), a, r * 0.1f);
                    ci.DrawLine(c + new Vector2(-r * 0.5f, 0), c + new Vector2(-r * 0.5f, r * 0.95f), a, r * 0.11f);
                    ci.DrawLine(c + new Vector2(r * 0.5f, 0), c + new Vector2(r * 0.5f, r * 0.95f), a, r * 0.11f);
                    ci.DrawLine(c + new Vector2(0, r * 0.05f), c + new Vector2(0, r * 0.32f), a2, r * 0.08f);
                    for (int i = 0; i < 3; i++)
                    {
                        float k = Mathf.Repeat(t * 0.5f + i / 3f, 1f);
                        ci.DrawCircle(c + new Vector2(0, r * 0.95f - k * r * 0.6f), r * (0.05f + 0.03f * (1f - k)), new Color(1, 1, 1, alpha * (1f - k)));
                    }
                    break;
                default:
                    ci.DrawCircle(c, r * 0.6f, a);
                    break;
            }
        }

        /// <summary>アイテムの形（Godot 版 Pickup.draw_shape）。原点中心。kind: 0=勾玉 1=団子 3=札</summary>
        public static void PickupShape(Vec ci, int kind, Color c, float t, float pulse = 1f)
        {
            switch (kind)
            {
                case 0:
                    {
                        float r = 6.5f * pulse;
                        var pts = new List<Vector2>();
                        for (int i = 0; i < 14; i++) { float a = Mathf.PI * 0.25f + Gd.TAU * 0.75f * i / 13f; pts.Add(Gd.Dir(a) * r); }
                        pts.Add(new Vector2(r * 1.7f, r * 1.1f));
                        pts.Add(new Vector2(r * 1.15f, r * 0.2f));
                        ci.DrawColoredPolygon(pts, c);
                        var outline = new List<Vector2>(pts) { pts[0] };
                        ci.DrawPolyline(outline, new Color(1, 1, 1, 0.9f), 1.5f);
                        ci.DrawCircle(new Vector2(-r * 0.2f, -r * 0.2f), r * 0.3f, new Color(1, 1, 1, 0.95f));
                        break;
                    }
                case 3:
                    {
                        float fl = Mathf.Sin(t * 4f) * 0.12f;
                        ci.SetTransform(Vector2.zero, fl, Vector2.one);
                        ci.DrawRect(new Rect(-7, -13, 14, 26), Gd.WithA(c, 0.35f));
                        ci.DrawRect(new Rect(-6, -12, 12, 24), Gd.C_PAPER);
                        ci.DrawRect(new Rect(-6, -12, 12, 24), Gd.WithA(c, 0.95f), false, 1.5f);
                        ci.DrawRect(new Rect(-4, -9, 8, 3), Gd.WithA(c, 0.9f));
                        ci.DrawLine(new Vector2(0, -4), new Vector2(0, 6), Gd.C_INK, 2f);
                        ci.DrawLine(new Vector2(-3, 0), new Vector2(3, 0), Gd.C_INK, 1.5f);
                        ci.DrawCircle(new Vector2(0, 9), 2.2f, new Color(0.85f, 0.2f, 0.25f, 0.95f));
                        ci.SetTransform(Vector2.zero, 0f, Vector2.one);
                        break;
                    }
                case 1:
                    ci.DrawLine(new Vector2(0, 12), new Vector2(0, -12), new Color(0.55f, 0.38f, 0.2f), 2.5f);
                    ci.DrawCircle(new Vector2(0, -7), 5.2f * pulse, new Color(1f, 0.62f, 0.72f));
                    ci.DrawCircle(new Vector2(0, 0), 5.2f * pulse, new Color(0.98f, 0.96f, 0.9f));
                    ci.DrawCircle(new Vector2(0, 7), 5.2f * pulse, new Color(0.6f, 0.85f, 0.5f));
                    foreach (float yy in new[] { -7f, 0f, 7f }) ci.DrawCircle(new Vector2(-1.6f, yy - 1.6f), 1.4f, new Color(1, 1, 1, 0.8f));
                    break;
                default:
                    ci.DrawCircle(new Vector2(0, 6), 9f, Gd.C_PAPER);
                    ci.DrawCircle(new Vector2(0, -6), 6.5f, Gd.C_PAPER);
                    ci.DrawRect(new Rect(-2.5f, -15, 5, 5), Gd.WithA(c, 0.95f));
                    ci.DrawArc(new Vector2(0, 6), 9f, 0, Gd.TAU, 20, Gd.WithA(c, 0.9f), 1.5f);
                    ci.DrawArc(new Vector2(0, -6), 6.5f, 0, Gd.TAU, 16, Gd.WithA(c, 0.9f), 1.5f);
                    ci.DrawRect(new Rect(-4, 2, 8, 8), new Color(0.85f, 0.2f, 0.25f, 0.85f));
                    break;
            }
        }
    }
}
