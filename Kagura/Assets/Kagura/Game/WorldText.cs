using System.Collections.Generic;
using TMPro;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 世界座標（Godot px）に文字を描く。毎フレーム Begin → Draw → End で使い回す。
    /// フォントは Godot 版と同じ（本文 = Zen Kaku Gothic、見出し = Shippori Mincho）。TMP の動的アトラスで日本語を出す。
    /// </summary>
    public class WorldText : MonoBehaviour
    {
        public enum Face { Body, Bold, Display }

        private static TMP_FontAsset _body, _display;
        private readonly List<TextMeshPro> _pool = new List<TextMeshPro>();
        private int _used;
        private int _order;

        public static WorldText Create(Transform parent, int sortingOrder)
        {
            var go = new GameObject("text");
            go.transform.SetParent(parent, false);
            var wt = go.AddComponent<WorldText>();
            wt._order = sortingOrder;
            return wt;
        }

        public static TMP_FontAsset FontFor(Face f)
        {
            if (_body == null)
            {
                var bodyFont = Resources.Load<Font>("Fonts/gothic");
                var dispFont = Resources.Load<Font>("Fonts/mincho");
                _body = bodyFont != null ? TMP_FontAsset.CreateFontAsset(bodyFont, 48, 6, UnityEngine.TextCore.LowLevel.GlyphRenderMode.SDFAA, 1024, 1024, AtlasPopulationMode.Dynamic, true) : TMP_Settings.defaultFontAsset;
                _display = dispFont != null ? TMP_FontAsset.CreateFontAsset(dispFont, 48, 6, UnityEngine.TextCore.LowLevel.GlyphRenderMode.SDFAA, 1024, 1024, AtlasPopulationMode.Dynamic, true) : _body;
                if (_body != null && _display != null && _body != _display)
                {
                    // 片方に無い字はもう片方から
                    _body.fallbackFontAssetTable = new List<TMP_FontAsset> { _display };
                    _display.fallbackFontAssetTable = new List<TMP_FontAsset> { _body };
                }
            }
            return f == Face.Display ? _display : _body;
        }

        public void Begin() { _used = 0; }

        public void End()
        {
            for (int i = _used; i < _pool.Count; i++) if (_pool[i].gameObject.activeSelf) _pool[i].gameObject.SetActive(false);
        }

        /// <summary>pos は Godot px。size は px 単位の文字の高さ。</summary>
        public void Draw(Vector2 pos, string text, float size, Color color, Face face = Face.Body, TextAnchor anchor = TextAnchor.MiddleCenter, bool shadow = false, float width = 0f)
        {
            if (shadow) DrawOne(pos + new Vector2(1.5f, 1.5f), text, size, new Color(0, 0, 0, color.a * 0.65f), face, anchor, width, _order);
            DrawOne(pos, text, size, color, face, anchor, width, _order + 1);
        }

        private void DrawOne(Vector2 pos, string text, float size, Color color, Face face, TextAnchor anchor, float width, int order)
        {
            TextMeshPro t;
            if (_used < _pool.Count) t = _pool[_used];
            else
            {
                var go = new GameObject("t");
                go.transform.SetParent(transform, false);
                t = go.AddComponent<TextMeshPro>();
                t.textWrappingMode = TextWrappingModes.NoWrap;
                t.overflowMode = TextOverflowModes.Overflow;
                t.richText = false;
                t.raycastTarget = false;
                _pool.Add(t);
            }
            _used++;
            if (!t.gameObject.activeSelf) t.gameObject.SetActive(true);
            t.font = FontFor(face);
            t.fontStyle = face == Face.Bold ? FontStyles.Bold : FontStyles.Normal;
            t.text = text;
            // TMP の 3D テキストは 10pt = 1 単位。1px = 1 単位に合わせる
            t.fontSize = size * 10f;
            t.color = color;
            t.alignment = ToAlign(anchor);
            var rt = t.rectTransform;
            rt.sizeDelta = new Vector2(width > 0f ? width : 2000f, size * 1.4f);
            rt.pivot = Pivot(anchor);
            rt.position = Gd.ToWorld(pos);
            t.renderer.sortingOrder = order;
            t.textWrappingMode = width > 0f ? TextWrappingModes.Normal : TextWrappingModes.NoWrap;
        }

        private static TextAlignmentOptions ToAlign(TextAnchor a)
        {
            switch (a)
            {
                case TextAnchor.UpperLeft: return TextAlignmentOptions.TopLeft;
                case TextAnchor.UpperCenter: return TextAlignmentOptions.Top;
                case TextAnchor.UpperRight: return TextAlignmentOptions.TopRight;
                case TextAnchor.MiddleLeft: return TextAlignmentOptions.Left;
                case TextAnchor.MiddleRight: return TextAlignmentOptions.Right;
                case TextAnchor.LowerLeft: return TextAlignmentOptions.BottomLeft;
                case TextAnchor.LowerCenter: return TextAlignmentOptions.Bottom;
                case TextAnchor.LowerRight: return TextAlignmentOptions.BottomRight;
                default: return TextAlignmentOptions.Center;
            }
        }

        private static Vector2 Pivot(TextAnchor a)
        {
            float x = 0.5f, y = 0.5f;
            switch (a)
            {
                case TextAnchor.UpperLeft: case TextAnchor.MiddleLeft: case TextAnchor.LowerLeft: x = 0f; break;
                case TextAnchor.UpperRight: case TextAnchor.MiddleRight: case TextAnchor.LowerRight: x = 1f; break;
            }
            switch (a)
            {
                case TextAnchor.UpperLeft: case TextAnchor.UpperCenter: case TextAnchor.UpperRight: y = 1f; break;
                case TextAnchor.LowerLeft: case TextAnchor.LowerCenter: case TextAnchor.LowerRight: y = 0f; break;
            }
            return new Vector2(x, y);
        }
    }
}
