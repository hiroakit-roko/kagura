using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using Kagura.Core;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>
    /// 右上の歯車から開く小休止のメニュー：再開／神々（迎えた神と能力）／神宝（持っている神宝）／音（音量）／あきらめる。
    /// 縦の位置は画面の高さに合わせて中央に寄せる。描画は自前の UiLayer、入力は GameManager が Pause 状態のときだけ渡す。
    /// </summary>
    public class PauseMenu
    {
        public static readonly Vector2 GearPos = new Vector2(Gd.W - 26f, 112f);
        public const float GearR = 20f;
        public static bool GearHit(Vector2 px) => Vector2.Distance(px, GearPos) <= GearR * 1.5f;

        private enum Page { Main, Audio, Gods, Relics, GiveUp }
        private Page _page = Page.Main;
        private readonly UiLayer L;
        private float _t, _anim;
        private int _hover = -1;
        private int _drag = -1;          // つまみを掴んでいるスライダー（0 曲 / 1 効果音）
        private int _god = 0;            // 神々の画面で選んでいる神
        private const float BW = 300f, BH = 56f;
        public const int BACK = 90;

        public PauseMenu(Transform parent) { L = UiLayer.Create(parent, "pause_menu", Gd.ZHud + 12); L.Clear(); }

        public void Open() { _page = Page.Main; _anim = 0f; _hover = -1; _drag = -1; _god = 0; }
        public void Close() { _drag = -1; Audio.Save(); L.Clear(); }

        // ---------- 配置（縦は中央寄せ） ----------

        private static float Y0 => Mathf.Max(120f, Gd.H * 0.5f - 250f);      // 見出しの位置
        private static Rect Btn(int i) => new Rect(Gd.W * 0.5f - BW * 0.5f, Y0 + 70f + i * 66f, BW, BH);
        private static Rect Track(int i) => new Rect(Gd.W * 0.5f - 110f, Y0 + 116f + i * 84f, 260f, 10f);
        private static Rect Half(int i) => new Rect(Gd.W * 0.5f + (i == 0 ? -BW * 0.5f : 12f), Y0 + 140f, BW * 0.5f - 12f, BH);
        private static Rect BackRect => new Rect(Gd.W * 0.5f - 110f, Mathf.Min(Gd.H - 80f, Y0 + 640f), 220f, 48f);
        private static Rect AudioBack => new Rect(Gd.W * 0.5f - 110f, Y0 + 300f, 220f, 48f);
        // 神々：三角の配置
        private static Rect GodR(int i) => i == 0 ? new Rect(Gd.W * 0.5f - 60f, Y0 + 60f, 120f, 140f)
                                          : i == 1 ? new Rect(Gd.W * 0.5f - 210f, Y0 + 200f, 120f, 140f)
                                                   : new Rect(Gd.W * 0.5f + 90f, Y0 + 200f, 120f, 140f);
        private static Rect DetailR => new Rect(40f, Y0 + 356f, Gd.W - 80f, 250f);
        // 神宝：3 列の格子
        private static Rect RelicR(int i) => new Rect(36f + (i % 3) * 192f, Y0 + 60f + (i / 3) * 150f, 180f, 138f);

        private int ButtonAt(Vector2 p)
        {
            switch (_page)
            {
                case Page.Main: for (int i = 0; i < 5; i++) if (Btn(i).Contains(p)) return i; break;
                case Page.Audio: if (AudioBack.Contains(p)) return BACK; break;
                case Page.Gods:
                    for (int i = 0; i < 3; i++) if (GodR(i).Contains(p)) return i;
                    if (BackRect.Contains(p)) return BACK; break;
                case Page.Relics: if (BackRect.Contains(p)) return BACK; break;
                case Page.GiveUp: for (int i = 0; i < 2; i++) if (Half(i).Contains(p)) return i; break;
            }
            return -1;
        }

        private static int SliderAt(Vector2 p)
        {
            for (int i = 0; i < 2; i++) if (UiKit.Grow(Track(i), 22f).Contains(p)) return i;
            return -1;
        }

        // ---------- 入力 ----------

        /// <summary>tap：この瞬間に押した。held：押しっぱなし（つまみを引く）。kb：キー（P / Esc で戻る・再開）。</summary>
        public void HandleInput(bool tap, Vector2 tapPx, bool held, Vector2 heldPx, Keyboard kb)
        {
            var g = GameManager.I;
            bool back = kb != null && (kb.pKey.wasPressedThisFrame || kb.escapeKey.wasPressedThisFrame);
            if (back)
            {
                if (_page == Page.Main) { Resume(); return; }
                Sfx.Play("clap", -14f); _page = Page.Main; _anim = 0f; return;
            }

            if (_page == Page.Audio)
            {
                if (tap) { int s = SliderAt(tapPx); if (s >= 0) _drag = s; }
                if (_drag >= 0)
                {
                    if (!held) { if (_drag == 1) Sfx.Play("select", -8f); _drag = -1; Audio.Save(); }
                    else
                    {
                        var tr = Track(_drag);
                        float v = Mathf.Clamp01((heldPx.x - tr.xMin) / tr.width);
                        v = Mathf.Round(v * 20f) / 20f;   // 5% 刻み
                        if (_drag == 0) Audio.Bgm = v; else Audio.Sfx = v;
                    }
                }
            }

            if (!tap) return;
            int b = ButtonAt(tapPx);
            if (b < 0) return;
            switch (_page)
            {
                case Page.Main:
                    if (b == 0) Resume();
                    else if (b == 1) { Sfx.Play("select", -10f); _page = Page.Gods; _god = 0; _anim = 0f; }
                    else if (b == 2) { Sfx.Play("select", -10f); _page = Page.Relics; _anim = 0f; }
                    else if (b == 3) { Sfx.Play("select", -10f); _page = Page.Audio; _anim = 0f; }
                    else { Sfx.Play("clap", -12f); _page = Page.GiveUp; _anim = 0f; }
                    break;
                case Page.Audio:
                    if (b == BACK) { Sfx.Play("clap", -14f); Audio.Save(); _page = Page.Main; _anim = 0f; }
                    break;
                case Page.Gods:
                    if (b == BACK) { Sfx.Play("clap", -14f); _page = Page.Main; _anim = 0f; }
                    else if (g != null && g.player != null && b < g.player.gods.Count) { Sfx.Play("select", -12f); _god = b; }
                    break;
                case Page.Relics:
                    if (b == BACK) { Sfx.Play("clap", -14f); _page = Page.Main; _anim = 0f; }
                    break;
                case Page.GiveUp:
                    if (b == 0) { Sfx.Play("clap", -6f); g.GiveUp(); }
                    else { Sfx.Play("clap", -14f); _page = Page.Main; _anim = 0f; }
                    break;
            }
        }

        private void Resume() { Sfx.Play("select", -8f); GameManager.I.TogglePause(); }

        // ---------- 描画 ----------

        public void Tick(float dt, Vector2? mousePx)
        {
            _t += dt;
            _anim = Mathf.Min(1f, _anim + dt * 5f);
            _hover = mousePx.HasValue ? ButtonAt(mousePx.Value) : -1;
            var g = GameManager.I;
            L.Begin();
            var v = L.front;
            v.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.03f, 0.06f, 0.70f));
            float a = _anim;
            switch (_page)
            {
                case Page.Main:
                    Title("小休止", a);
                    Button(Btn(0), "再開", 0, a, Gd.C_GOLD);
                    Button(Btn(1), "神々", 1, a, new Color(0.85f, 0.9f, 1f));
                    Button(Btn(2), "神宝", 2, a, new Color(0.85f, 0.9f, 1f));
                    Button(Btn(3), "音", 3, a, new Color(0.85f, 0.9f, 1f));
                    Button(Btn(4), "あきらめる", 4, a, new Color(1f, 0.55f, 0.6f));
                    break;
                case Page.Audio:
                    Title("音", a);
                    Slider(0, "曲", Audio.Bgm, a);
                    Slider(1, "効果音", Audio.Sfx, a);
                    Button(AudioBack, "戻る", BACK, a, Gd.C_GOLD);
                    break;
                case Page.Gods:
                    Title("神々", a);
                    DrawGods(g, a);
                    Button(BackRect, "戻る", BACK, a, Gd.C_GOLD);
                    break;
                case Page.Relics:
                    Title("神宝", a);
                    DrawRelics(g, a);
                    Button(BackRect, "戻る", BACK, a, Gd.C_GOLD);
                    break;
                case Page.GiveUp:
                    Title("あきらめる？", a, 44);
                    UiKit.Txt(L, Face.Body, new Vector2(0, Y0 + 48f), "この参拝の記録は残らない", 14, new Color(0.85f, 0.9f, 1f, 0.8f * a), TextAnchor.MiddleCenter, Gd.W);
                    Button(Half(0), "はい", 0, a, new Color(1f, 0.55f, 0.6f));
                    Button(Half(1), "いいえ", 1, a, Gd.C_GOLD);
                    break;
            }
            L.End();
        }

        private void Title(string s, float a, int size = 52) => UiKit.Txt(L, Face.Display, new Vector2(0, Y0 + size * 0.36f), s, size, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, Gd.W);

        private void Button(Rect r, string label, int idx, float a, Color col)
        {
            var v = L.front;
            bool hot = _hover == idx;
            float k = Mathf.Clamp01(a);
            r.y += (1f - k) * 16f;
            v.DrawRect(UiKit.Grow(r, 4f), new Color(0, 0, 0, 0.35f * k));
            v.DrawRect(r, new Color(0.08f, 0.06f, 0.12f, 0.96f * k));
            v.DrawRect(r, Gd.WithA(col, (hot ? 1f : 0.6f) * k), false, hot ? 2f : 1.2f);
            if (hot) v.DrawRect(r, Gd.WithA(col, 0.10f * k));
            v.DrawRect(new Rect(r.x, r.y, r.width, 3f), Gd.WithA(col, k));
            UiKit.Txt(L, Face.Display, new Vector2(r.x, r.center.y + 2f), label, r.height >= 56f ? 24 : 20, Gd.WithA(Color.white, k), TextAnchor.MiddleCenter, r.width);
        }

        private void Slider(int i, string label, float val, float a)
        {
            var v = L.front;
            var tr = Track(i);
            bool hot = _drag == i;
            Color col = hot ? Gd.C_GOLD : new Color(0.85f, 0.9f, 1f);
            UiKit.Txt(L, Face.Display, new Vector2(tr.xMin, tr.yMin - 22f), label, 20, Gd.WithA(Color.white, a));
            UiKit.Txt(L, Face.Bold, new Vector2(tr.xMin, tr.yMin - 22f), Mathf.RoundToInt(val * 100f) + "%", 16, Gd.WithA(col, a), TextAnchor.MiddleRight, tr.width);
            v.DrawRect(tr, new Color(0.05f, 0.03f, 0.09f, 0.9f * a));
            v.DrawRect(tr, new Color(1, 1, 1, 0.18f * a), false, 1f);
            v.DrawRect(new Rect(tr.xMin, tr.yMin, tr.width * val, tr.height), Gd.WithA(col, 0.9f * a));
            for (int k = 1; k < 4; k++) v.DrawLine(new Vector2(tr.xMin + tr.width * k / 4f, tr.yMin + 2f), new Vector2(tr.xMin + tr.width * k / 4f, tr.yMax - 2f), new Color(0, 0, 0, 0.35f * a), 1f);
            var kc = new Vector2(tr.xMin + tr.width * val, tr.center.y);
            v.DrawCircle(kc, hot ? 15f : 12f, new Color(0.08f, 0.06f, 0.12f, a));
            v.DrawArc(kc, hot ? 15f : 12f, 0, Gd.TAU, 28, Gd.WithA(col, a), 2f);
            v.DrawCircle(kc, 4f, Gd.WithA(col, a));
            if (val <= 0f) UiKit.Txt(L, Face.Body, new Vector2(tr.xMin, tr.yMax + 16f), "消音", 12, new Color(1, 0.6f, 0.65f, 0.8f * a));
        }

        /// <summary>神々：三角に並べ、選んだ神の能力を下に列挙する。</summary>
        private void DrawGods(GameManager g, float a)
        {
            var p = g != null ? g.player : null;
            if (p == null) return;
            var v = L.front;
            Vector2[] cs = { GodR(0).center, GodR(1).center, GodR(2).center };
            for (int i = 0; i < 3; i++)
                for (int j = i + 1; j < 3; j++)
                {
                    bool on = i < p.gods.Count && j < p.gods.Count;
                    L.back.DrawLine(cs[i], cs[j], on ? Gd.WithA(Gd.C_GOLD, 0.3f * a) : new Color(1, 1, 1, 0.07f * a), on ? 1.5f : 1f);
                }
            for (int i = 0; i < 3; i++)
            {
                var r = GodR(i);
                if (i < p.gods.Count)
                {
                    string id = p.gods[i];
                    var k = Data.KamiOf(id);
                    var kc = Data.ColorOf(k.color);
                    bool sel = i == _god;
                    L.back.DrawRect(UiKit.Grow(r, sel ? 3f : 0f), new Color(0.06f, 0.04f, 0.10f, 0.9f * a));
                    v.DrawRect(UiKit.Grow(r, sel ? 3f : 0f), Gd.WithA(kc, (sel ? 1f : 0.45f) * a), false, sel ? 2f : 1f);
                    KamiIcon.Draw(L, id, r.center + new Vector2(0, -22f), 40f, _t, a);
                    UiKit.Txt(L, Face.Display, new Vector2(r.x, r.yMax - 30f), k.name, 12, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, r.width);
                    UiKit.Txt(L, Face.Body, new Vector2(r.x, r.yMax - 12f), (i == 0 ? "主神" : "副神") + "　神格 " + p.KamiLv(id), 10, Gd.WithA(kc, 0.9f * a), TextAnchor.MiddleCenter, r.width);
                }
                else
                {
                    L.back.DrawRect(r, new Color(0.05f, 0.03f, 0.09f, 0.5f * a));
                    v.DrawRect(r, new Color(1, 1, 1, 0.15f * a), false, 1f);
                    UiKit.Txt(L, Face.Body, new Vector2(r.x, r.center.y + 4f), "位 " + BoonsLogic.RECRUIT_LEVELS[i] + " で", 11, new Color(1, 1, 1, 0.45f * a), TextAnchor.MiddleCenter, r.width);
                }
            }
            // 選んだ神の能力
            if (_god >= p.gods.Count) _god = 0;
            if (p.gods.Count == 0) return;
            string gid = p.gods[_god];
            var gk = Data.KamiOf(gid);
            var gc = Data.ColorOf(gk.color);
            var d = DetailR;
            UiKit.Panel(L.back, d, gc, a, 0.85f);
            UiKit.Txt(L, Face.Display, new Vector2(d.x + 14f, d.y + 24f), gk.name + "の能力", 15, Gd.WithA(gc, a));
            UiKit.Txt(L, Face.Body, new Vector2(d.x + 14f, d.y + 24f), gk.weapon + "  威力 ×" + p.KamiPower(gid).ToString("0.00"), 11, new Color(1, 1, 1, 0.8f * a), TextAnchor.MiddleRight, d.width - 28f);
            float y = d.y + 48f;
            int n = 0;
            foreach (var kv in p.boons)
            {
                var def = Data.Boon(kv.Key);
                if (def == null || (def.kami != gid && def.kami2 != gid)) continue;
                if (def.kami2 != null && def.kami2 != "" && def.kami != gid && _god != 0) continue;
                bool special = string.IsNullOrEmpty(def.kami2) ? kv.Value.rar >= (int)Rarity.Legendary : true;
                var rc = Data.ColorOf(RarityTable.Colors[Mathf.Clamp(kv.Value.rar, 0, RarityTable.Colors.Length - 1)]);
                L.back.DrawRect(new Rect(d.x + 10f, y - 2f, d.width - 20f, 40f), new Color(0, 0, 0, 0.25f * a));
                UiKit.Txt(L, Face.Display, new Vector2(d.x + 16f, y + 14f), RarityTable.Names[Mathf.Clamp(kv.Value.rar, 0, 5)], 13, Gd.WithA(rc, a));
                UiKit.Txt(L, Face.Display, new Vector2(d.x + 36f, y + 14f), def.name + (special ? "" : "  Lv." + kv.Value.lv), 13, new Color(1, 1, 1, a));
                UiKit.Txt(L, Face.Body, new Vector2(d.x + 36f, y + 31f), Boons.Describe(def, kv.Value.rar, kv.Value.lv), 10, new Color(0.9f, 0.92f, 1f, 0.9f * a), TextAnchor.MiddleLeft, d.width - 60f);
                y += 44f; n++;
                if (y > d.yMax - 20f) break;
            }
            if (n == 0) UiKit.Txt(L, Face.Body, new Vector2(d.x, d.y + 100f), "まだ能力は無い", 13, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleCenter, d.width);
        }

        /// <summary>神宝：持っているものを格子に並べる。</summary>
        private void DrawRelics(GameManager g, float a)
        {
            var p = g != null ? g.player : null;
            if (p == null) return;
            var v = L.front;
            if (p.relics.Count == 0) { UiKit.Txt(L, Face.Body, new Vector2(0, Y0 + 160f), "まだ神宝は無い", 14, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleCenter, Gd.W); return; }
            for (int i = 0; i < p.relics.Count && i < 12; i++)
            {
                var def = Data.Relic(p.relics[i]);
                if (def == null) continue;
                var r = RelicR(i);
                Color col = def.shop ? ShopView.RarColor(def.rar) : Gd.C_GOLD;
                L.back.DrawRect(r, new Color(0.06f, 0.04f, 0.10f, 0.92f * a));
                v.DrawRect(r, Gd.WithA(col, 0.6f * a), false, 1f);
                var tex = UiKit.Art("relic/" + def.id);
                var pr = new Rect(r.x + 4f, r.y + 4f, r.width - 8f, 76f);
                if (tex != null) L.img.DrawCover(tex, pr, a, 0.5f);
                UiKit.Txt(L, Face.Display, new Vector2(r.x, r.y + 98f), def.name, 13, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, r.width);
                UiKit.Txt(L, Face.Body, new Vector2(r.x + 6f, r.y + 116f), def.desc, 9, new Color(0.9f, 0.92f, 1f, 0.9f * a), TextAnchor.MiddleCenter, r.width - 12f);
                if (def.shop) UiKit.Txt(L, Face.Bold, new Vector2(r.x + 6f, r.y + 16f), ShopView.RarName(def.rar), 10, Gd.WithA(col, a));
            }
        }

        /// <summary>右上の歯車（HUD が Play / Pause 中に描く）。</summary>
        public static void DrawGear(Vec v, float t, bool open)
        {
            Vector2 c = GearPos; float r = GearR;
            Color col = open ? Gd.C_GOLD : new Color(0.9f, 0.9f, 1f);
            v.DrawCircle(c, r, new Color(0.05f, 0.03f, 0.09f, 0.6f));
            v.DrawArc(c, r, 0, Gd.TAU, 40, Gd.WithA(col, 0.35f), 1.5f);
            float rot = open ? t * 1.2f : 0f;
            for (int i = 0; i < 8; i++)
            {
                float ang = rot + Gd.TAU * i / 8f;
                v.DrawLine(c + Gd.Dir(ang) * (r * 0.42f), c + Gd.Dir(ang) * (r * 0.66f), Gd.WithA(col, 0.95f), 4.5f);
            }
            v.DrawArc(c, r * 0.42f, 0, Gd.TAU, 24, Gd.WithA(col, 0.95f), 3.5f);
            v.DrawCircle(c, r * 0.16f, Gd.WithA(col, 0.6f));
        }
    }
}
