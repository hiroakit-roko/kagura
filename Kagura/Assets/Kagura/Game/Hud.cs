using UnityEngine;
using UnityEngine.UI;

namespace Kagura.Game
{
    /// <summary>仮の HUD（uGUI の Text）。TextMeshPro と本番のデザインに置き換えるまでのつなぎ。</summary>
    public class Hud : MonoBehaviour
    {
        public Text top;
        public Text banner;
        public Text center;
        private float _bannerT;

        public static Hud Create(Transform parent)
        {
            var canvasGo = new GameObject("HUD", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvasGo.transform.SetParent(parent, false);
            var canvas = canvasGo.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGo.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(640, 960);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0f;   // 横幅基準
            var hud = canvasGo.AddComponent<Hud>();
            hud.top = MakeText(canvasGo.transform, "top", new Vector2(0.5f, 1f), new Vector2(0, -24), 22, TextAnchor.UpperCenter);
            hud.banner = MakeText(canvasGo.transform, "banner", new Vector2(0.5f, 0.75f), Vector2.zero, 40, TextAnchor.MiddleCenter);
            hud.center = MakeText(canvasGo.transform, "center", new Vector2(0.5f, 0.5f), Vector2.zero, 30, TextAnchor.MiddleCenter);
            return hud;
        }

        private static Font _jp;
        /// <summary>日本語フォント（Godot 版と同じ明朝のサブセット）。無ければ Unity 標準。</summary>
        public static Font JpFont()
        {
            if (_jp != null) return _jp;
            _jp = Resources.Load<Font>("Fonts/mincho") ?? Resources.Load<Font>("Fonts/gothic") ?? Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            return _jp;
        }

        private static Text MakeText(Transform parent, string name, Vector2 anchor, Vector2 offset, int size, TextAnchor align)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = rt.anchorMax = anchor;
            rt.pivot = anchor;
            rt.anchoredPosition = offset;
            rt.sizeDelta = new Vector2(620, 200);
            var t = go.AddComponent<Text>();
            t.font = JpFont();
            t.fontSize = size;
            t.alignment = align;
            t.color = new Color(1f, 0.95f, 0.85f);
            t.horizontalOverflow = HorizontalWrapMode.Overflow;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            t.raycastTarget = false;
            return t;
        }

        public void Refresh(GameManager g)
        {
            var p = g.player;
            top.text = $"命 {Mathf.CeilToInt(Mathf.Max(0, p != null ? p.hp : 0))} / {(p != null ? (int)p.maxHp : 0)}     第 {g.Wave} 波     功徳 {g.Score}";
            if (_bannerT > 0f)
            {
                _bannerT -= Time.deltaTime;
                var c = banner.color; c.a = Mathf.Clamp01(_bannerT * 1.5f); banner.color = c;
                if (_bannerT <= 0f) banner.text = "";
            }
        }

        public void Banner(string text)
        {
            banner.text = text;
            _bannerT = 2.2f;
        }

        public void ShowTitle(bool on)
        {
            center.text = on ? "神楽 -KAGURA ASCENT-\n\nタップ / Enter で はじめる" : "";
            top.text = "";
        }

        public void ShowOver(bool cleared, GameManager g)
        {
            center.text = (cleared ? "踏破" : "討たれた") + $"\n第 {g.Wave} 波　功徳 {g.Score}\n\nタップ / Enter で もう一度";
        }
    }
}
