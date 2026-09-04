using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 仮の絵を実行時に作る（円・菱形・輪・柔らかい発光）。Midjourney の絵に置き換えるまでのつなぎ。
    /// 1 単位 = Godot 版の 100px。PPU=100 で Godot と同じ数値が使える。
    /// </summary>
    public static class SpriteFactory
    {
        public const float Ppu = 100f;
        private static readonly Dictionary<string, Sprite> Cache = new Dictionary<string, Sprite>();

        public static Sprite Circle(int size = 64) => Get("circle" + size, size, (u, v) =>
        {
            float d = Mathf.Sqrt(u * u + v * v);
            return Mathf.Clamp01((1f - d) * size * 0.5f);
        });

        /// <summary>中心が濃く縁で消える光。加算合成用。</summary>
        public static Sprite Glow(int size = 128) => Get("glow" + size, size, (u, v) =>
        {
            float d = Mathf.Sqrt(u * u + v * v);
            float k = Mathf.Clamp01(1f - d);
            return k * k;
        });

        public static Sprite Diamond(int size = 64) => Get("diamond" + size, size, (u, v) =>
        {
            float d = Mathf.Abs(u) + Mathf.Abs(v);
            return Mathf.Clamp01((1f - d) * size * 0.5f);
        });

        public static Sprite Ring(int size = 96, float thickness = 0.12f) => Get("ring" + size, size, (u, v) =>
        {
            float d = Mathf.Sqrt(u * u + v * v);
            float e = Mathf.Abs(d - (1f - thickness)) / thickness;
            return Mathf.Clamp01((1f - e) * 2f);
        });

        /// <summary>縦長のカプセル（自機の弾）。</summary>
        public static Sprite Capsule(int size = 32) => Get("capsule" + size, size, (u, v) =>
        {
            float x = Mathf.Abs(u) * 2.2f;
            float y = Mathf.Max(0f, Mathf.Abs(v) - 0.5f) * 2f;
            float d = Mathf.Sqrt(x * x + y * y);
            return Mathf.Clamp01((1f - d) * size * 0.35f);
        });

        private static Sprite Get(string key, int size, System.Func<float, float, float> alphaAt)
        {
            if (Cache.TryGetValue(key, out var s)) return s;
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[size * size];
            for (int y = 0; y < size; y++)
            {
                float v = (y + 0.5f) / size * 2f - 1f;
                for (int x = 0; x < size; x++)
                {
                    float u = (x + 0.5f) / size * 2f - 1f;
                    byte a = (byte)Mathf.RoundToInt(255f * alphaAt(u, v));
                    px[y * size + x] = new Color32(255, 255, 255, a);
                }
            }
            tex.SetPixels32(px);
            tex.Apply();
            s = Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), Ppu);
            Cache[key] = s;
            return s;
        }

        private static Material _additive;
        /// <summary>加算合成のマテリアル（発光用）。</summary>
        public static Material Additive()
        {
            if (_additive != null) return _additive;
            var sh = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default") ?? Shader.Find("Sprites/Default");
            _additive = new Material(sh);
            // URP の Sprite-Unlit は Blend プロパティを持たないので、Sprites/Default 系の場合だけ加算に
            if (_additive.HasProperty("_SrcBlend")) { _additive.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One); _additive.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One); }
            return _additive;
        }
    }
}
