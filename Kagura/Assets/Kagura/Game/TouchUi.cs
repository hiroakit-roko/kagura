using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Kagura.Game
{
    /// <summary>
    /// スマホ向けのタッチ操作（Godot 版 touch.gd の移植）。画面下の丸ボタンで詠唱／神招き。右上の歯車（小休止）は HUD と GameManager が受け持つ。
    /// 短くなぞってすぐ離すと疾走。ボタンの上の指は自機の移動に使わない。
    /// </summary>
    public class TouchUi : MonoBehaviour
    {
        public const float BTN_R = 50f, SWIPE_TIME = 0.30f, SWIPE_DIST = 22f;
        public bool active;
        private float _t;
        private UiLayer _layer;
        private readonly Dictionary<string, Vector2> _pos = new Dictionary<string, Vector2>();
        private readonly Dictionary<string, float> _r = new Dictionary<string, float>();
        private readonly Dictionary<string, bool> _just = new Dictionary<string, bool>();
        private readonly Dictionary<string, bool> _held = new Dictionary<string, bool>();
        private Vector2 _flick;
        private float _flickCd;
        private float _touchStartT;
        private Vector2 _touchStartPos;
        private bool _tracking;

        public static TouchUi Create(Transform parent)
        {
            var go = new GameObject("touch");
            go.transform.SetParent(parent, false);
            var t = go.AddComponent<TouchUi>();
            t._layer = UiLayer.Create(go.transform, "touch_layer", Gd.ZHud + 10);
            foreach (var n in new[] { "call", "cast", "pause" }) { t._just[n] = false; t._held[n] = false; t._r[n] = n == "pause" ? 20f : BTN_R; }
            t.active = Application.isMobilePlatform || Net.HasTouch();   // ブラウザは navigator.maxTouchPoints で判定（PC の Chrome は Touchscreen デバイスを持つことがある）
            return t;
        }

        private void Layout()
        {
            _pos["call"] = new Vector2(84f, Gd.H - 128f);
            _pos["cast"] = new Vector2(Gd.W - 84f, Gd.H - 128f);
            _pos["pause"] = new Vector2(Gd.W - 26f, 112f);
        }

        /// <summary>画面座標（Unity、左下原点）→ Godot px</summary>
        public static Vector2 ToPx(Vector2 screen)
        {
            float s = Gd.W / Mathf.Max(1, Screen.width);
            return new Vector2(screen.x * s, Gd.H - screen.y * s);
        }

        public bool IsButtonTouch(Vector2 screen)
        {
            if (!active) return false;
            Vector2 p = ToPx(screen);
            foreach (var kv in _pos) if (Vector2.Distance(p, kv.Value) <= _r[kv.Key] * 1.25f) return true;
            return false;
        }

        public bool Take(string name) { if (_just[name]) { _just[name] = false; return true; } return false; }
        public Vector2 TakeFlick() { var f = _flick; _flick = Vector2.zero; return f; }

        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            _t += dt;
            _flickCd = Mathf.Max(0f, _flickCd - dt);
            Layout();
            var g = GameManager.I;
            if (Keyboard.current != null && Keyboard.current.anyKey.wasPressedThisFrame) active = false;
            var ts = Touchscreen.current;
            bool pressed = false, down = false, up = false; Vector2 sp = Vector2.zero;
            if (ts != null)
            {
                var pt = ts.primaryTouch;
                pressed = pt.press.isPressed; down = pt.press.wasPressedThisFrame; up = pt.press.wasReleasedThisFrame; sp = pt.position.ReadValue();
                if (down) active = true;
            }
            if (g != null)
            {
                if (down)
                {
                    // 小休止中の操作は GameManager → PauseMenu が受ける（ここで再開してしまうと二重に切り替わる）
                    if (g.State == GameState.Play)
                    {
                        Vector2 p = ToPx(sp);
                        bool onBtn = false;
                        foreach (var kv in _pos)
                        {
                            if (Vector2.Distance(p, kv.Value) <= _r[kv.Key] * 1.25f) { _just[kv.Key] = true; _held[kv.Key] = true; onBtn = true; break; }
                        }
                        if (!onBtn) { _tracking = true; _touchStartT = Time.unscaledTime; _touchStartPos = sp; }
                    }
                }
                if (up)
                {
                    foreach (var k in new List<string>(_held.Keys)) _held[k] = false;
                    if (_tracking)
                    {
                        float dtS = Time.unscaledTime - _touchStartT;
                        Vector2 dp = sp - _touchStartPos;
                        float s = Gd.W / Mathf.Max(1, Screen.width);
                        if (_flickCd <= 0f && dtS < SWIPE_TIME && dp.magnitude * s >= SWIPE_DIST && g.State == GameState.Play)
                        {
                            _flick = new Vector2(dp.x, -dp.y).normalized;
                            _flickCd = 0.5f;
                        }
                        _tracking = false;
                    }
                }
            }
            Draw();
        }

        private void Draw()
        {
            var l = _layer;
            l.Begin();
            var g = GameManager.I;
            if (active && g != null && (g.State == GameState.Play || g.State == GameState.Pause) && g.player != null)
            {
                var p = g.player;
                var v = l.front;
                string main = p.MainGod();
                foreach (var kv in _pos)
                {
                    string name = kv.Key; Vector2 c = kv.Value; float r = _r[name];
                    if (name == "pause") continue;   // 右上の歯車は HUD が描く（PauseMenu.DrawGear）
                    bool pressed = _held[name];
                    Color col = Color.white; bool enabled = true; float fill = 0f; string sub = "";
                    switch (name)
                    {
                        case "cast":
                            col = main != "" ? p.KamiColor(main) : Gd.C_PBULLET; fill = p.castCharges > 0 ? 1f : 0f; enabled = p.castCharges > 0 && main != ""; sub = $"×{p.castCharges}"; break;
                        case "call":
                            col = main != "" ? p.KamiColor(main) : new Color(0.5f, 0.5f, 0.6f); fill = p.callGauge; enabled = main != "" && p.callGauge >= 0.999f; if (main == "") sub = "未"; break;
                        default:
                            col = new Color(0.9f, 0.9f, 1f); break;
                    }
                    float a = enabled ? 0.9f : 0.45f;
                    if (name == "call" && enabled) UiKit.FlamesRing(v, c, r, _t);   // 満ちた：紫の炎がめらめら
                    v.DrawCircle(c, r, new Color(0.05f, 0.03f, 0.09f, 0.55f));
                    v.DrawArc(c, r, 0, Gd.TAU, 40, Gd.WithA(col, 0.35f * a), 2f);
                    if (fill > 0f && name != "pause") v.DrawArc(c, r - 5f, -Mathf.PI * 0.5f, -Mathf.PI * 0.5f + Gd.TAU * Mathf.Clamp01(fill), 40, Gd.WithA(col, a), 5f);
                    if (enabled && name != "pause") v.DrawCircle(c, r - 8f, Gd.WithA(col, 0.10f + 0.06f * Mathf.Sin(_t * 4f)));
                    if (pressed) v.DrawCircle(c, r - 4f, Gd.WithA(col, 0.35f));
                    string label = name == "call" ? "神招き" : name == "cast" ? "詠唱" : "休";
                    UiKit.Txt(l, name != "pause" ? WorldText.Face.Display : WorldText.Face.Bold, new Vector2(c.x - r, c.y + (sub == "" ? 6f : 0f)), label, name != "pause" ? 16 : 14, Gd.WithA(Color.white, a), TextAnchor.MiddleCenter, r * 2f);
                    if (sub != "") UiKit.Txt(l, WorldText.Face.Body, new Vector2(c.x - r, c.y + 20f), sub, 12, Gd.WithA(col, a), TextAnchor.MiddleCenter, r * 2f);
                }
                float dk = 1f - p.dashCool / Mathf.Max(0.01f, p.DashCdTime());
                Vector2 dc = new Vector2(Gd.W * 0.5f, Gd.H - 110f);
                Color dcol = main != "" ? p.KamiColor(main) : new Color(0.9f, 0.9f, 1f);
                v.DrawRect(new Rect(dc.x - 46, dc.y - 14, 92, 28), new Color(0.05f, 0.03f, 0.09f, 0.55f));
                v.DrawRect(new Rect(dc.x - 46, dc.y - 14, 92, 28), Gd.WithA(dcol, 0.35f), false, 1f);
                v.DrawRect(new Rect(dc.x - 42, dc.y + 6, 84f * dk, 4), Gd.WithA(dk >= 1f ? dcol : new Color(0.8f, 0.85f, 1f), 0.9f));
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(dc.x - 46, dc.y + 2), dk >= 1f ? "疾走" : $"疾走 {p.dashCool:F1}", 12, new Color(1, 1, 1, dk >= 1f ? 0.9f : 0.6f), TextAnchor.MiddleCenter, 92);
                if (g.Wave <= 1 && _t < 12f)
                {
                    float a2 = Mathf.Clamp01(12f - _t) * 0.8f;
                    UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H * 0.56f), "画面をなぞって移動", 15, new Color(1, 1, 1, a2), TextAnchor.MiddleCenter, Gd.W);
                    UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H * 0.56f + 22f), "指をすばやく弾くと疾走", 13, new Color(1, 1, 1, a2 * 0.85f), TextAnchor.MiddleCenter, Gd.W);
                }
            }
            l.End();
        }
    }
}
