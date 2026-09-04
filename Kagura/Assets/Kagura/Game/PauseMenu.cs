using UnityEngine;
using UnityEngine.InputSystem;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>
    /// 右上の歯車から開く小休止のメニュー：再開／音（曲・効果音の音量）／あきらめる。
    /// 描画は自前の UiLayer、入力は GameManager が Pause 状態のときだけ渡す（タップと押しっぱなしの位置）。
    /// </summary>
    public class PauseMenu
    {
        public static readonly Vector2 GearPos = new Vector2(Gd.W - 26f, 112f);
        public const float GearR = 20f;
        public static bool GearHit(Vector2 px) => Vector2.Distance(px, GearPos) <= GearR * 1.5f;

        private enum Page { Main, Audio, GiveUp }
        private Page _page = Page.Main;
        private readonly UiLayer L;
        private float _t, _anim;
        private int _hover = -1;
        private int _drag = -1;          // つまみを掴んでいるスライダー（0 曲 / 1 効果音）
        private float _sfxPreviewT;
        private const float BW = 300f, BH = 56f;

        public PauseMenu(Transform parent) { L = UiLayer.Create(parent, "pause_menu", Gd.ZHud + 12); L.Clear(); }

        public void Open() { _page = Page.Main; _anim = 0f; _hover = -1; _drag = -1; }
        public void Close() { _drag = -1; Audio.Save(); L.Clear(); }

        // ---------- 配置 ----------

        private static Rect Btn(int i) => new Rect(Gd.W * 0.5f - BW * 0.5f, 330f + i * 70f, BW, BH);
        private static Rect Track(int i) => new Rect(Gd.W * 0.5f - 110f, 372f + i * 84f, 260f, 10f);
        private static Rect Half(int i) => new Rect(Gd.W * 0.5f + (i == 0 ? -BW * 0.5f : 12f), 400f, BW * 0.5f - 12f, BH);
        private static Rect Back() => Btn(3);

        private int ButtonAt(Vector2 p)
        {
            switch (_page)
            {
                case Page.Main: for (int i = 0; i < 3; i++) if (Btn(i).Contains(p)) return i; break;
                case Page.Audio: if (Back().Contains(p)) return 0; break;
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
                    else if (b == 1) { Sfx.Play("select", -10f); _page = Page.Audio; _anim = 0f; }
                    else { Sfx.Play("clap", -12f); _page = Page.GiveUp; _anim = 0f; }
                    break;
                case Page.Audio:
                    Sfx.Play("clap", -14f); Audio.Save(); _page = Page.Main; _anim = 0f;
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
            _sfxPreviewT = Mathf.Max(0f, _sfxPreviewT - dt);
            _hover = mousePx.HasValue ? ButtonAt(mousePx.Value) : -1;
            var g = GameManager.I;
            L.Begin();
            var v = L.front;
            v.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.03f, 0.06f, 0.66f));
            float a = _anim;
            switch (_page)
            {
                case Page.Main:
                    UiKit.Txt(L, Face.Display, new Vector2(0, 262), "小休止", 52, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, Gd.W);
                    Button(Btn(0), "再開", 0, a, Gd.C_GOLD);
                    Button(Btn(1), "音", 1, a, new Color(0.85f, 0.9f, 1f));
                    Button(Btn(2), "あきらめる", 2, a, new Color(1f, 0.55f, 0.6f));
                    if (g != null && g.player != null) g.hud.DrawBuild(L, g.player, 560f);
                    break;
                case Page.Audio:
                    UiKit.Txt(L, Face.Display, new Vector2(0, 262), "音", 52, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, Gd.W);
                    Slider(0, "曲", Audio.Bgm, a);
                    Slider(1, "効果音", Audio.Sfx, a);
                    Button(Back(), "戻る", 0, a, Gd.C_GOLD);
                    break;
                case Page.GiveUp:
                    UiKit.Txt(L, Face.Display, new Vector2(0, 262), "あきらめる？", 44, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, Gd.W);
                    UiKit.Txt(L, Face.Body, new Vector2(0, 310), "この参拝の記録は残らない", 14, new Color(0.85f, 0.9f, 1f, 0.8f * a), TextAnchor.MiddleCenter, Gd.W);
                    Button(Half(0), "はい", 0, a, new Color(1f, 0.55f, 0.6f));
                    Button(Half(1), "いいえ", 1, a, Gd.C_GOLD);
                    break;
            }
            L.End();
        }

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
            UiKit.Txt(L, Face.Display, new Vector2(r.x, r.center.y + 2f), label, 24, Gd.WithA(Color.white, k), TextAnchor.MiddleCenter, r.width);
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
