using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// Godot 版 Cfg の移植と座標変換。
    /// ゲーム内の座標は Godot と同じ「横 640px、左上が原点、下が +y」で持ち、表示のときだけ Unity の世界座標へ変える。
    /// 1 Unity 単位 = 1px。カメラは (W/2, H/2) を中心に置く。
    /// </summary>
    public static class Gd
    {
        public const float W = 640f;
        public const float HBase = 960f;
        /// <summary>画面の高さ（縦長端末では横幅を基準に伸びる）。Game が更新する。</summary>
        public static float H = 960f;
        public const float Margin = 20f;
        public const float TAU = Mathf.PI * 2f;

        public static bool NoGlow = false;
        public static bool AA = true;

        // Z 順（Renderer.sortingOrder）
        public const int ZStars = -20, ZPickup = 3, ZPBullet = 6, ZEBullet = 7, ZEnemy = 9, ZPlayer = 12, ZFx = 40, ZHud = 100;

        // 配色
        public static readonly Color C_PLAYER = new Color(0.82f, 0.62f, 1f);
        public static readonly Color C_PLAYER_DARK = new Color(0.30f, 0.16f, 0.48f);
        public static readonly Color C_ENEMY = new Color(1f, 0.36f, 0.50f);
        public static readonly Color C_ENEMY2 = new Color(1f, 0.68f, 0.26f);
        public static readonly Color C_ENEMY3 = new Color(0.72f, 0.45f, 1f);
        public static readonly Color C_BOSS = new Color(1f, 0.25f, 0.35f);
        public static readonly Color C_PBULLET = new Color(0.85f, 0.75f, 1f);
        public static readonly Color C_EBULLET = new Color(1f, 0.45f, 0.85f);
        public static readonly Color C_XP = new Color(0.55f, 0.9f, 1f);
        public static readonly Color C_HP = new Color(0.45f, 1f, 0.55f);
        public static readonly Color C_SHIELD = new Color(0.55f, 0.75f, 1f);
        public static readonly Color C_CRIT = new Color(1f, 0.9f, 0.35f);
        public static readonly Color C_BG = new Color(0.035f, 0.025f, 0.07f);
        public static readonly Color C_GOLD = new Color(1f, 0.84f, 0.45f);
        public static readonly Color C_PAPER = new Color(0.96f, 0.92f, 0.84f);
        public static readonly Color C_INK = new Color(0.10f, 0.07f, 0.12f);
        public static readonly Color[] STAGE_TINT = { new Color(0.45f, 0.30f, 0.80f), new Color(0.75f, 0.30f, 0.45f), new Color(0.25f, 0.20f, 0.55f) };
        public const int StageLen = 8;
        public const int StageCount = 3;
        public static readonly string[] STAGE_NAME = { "参道", "拝殿", "奥宮" };
        public static readonly string[] STAGE_KANJI = { "一", "二", "三" };

        public static Color WithA(Color c, float a) => new Color(c.r, c.g, c.b, a);
        public static Color Lerp(Color a, Color b, float t) => Color.Lerp(a, b, Mathf.Clamp01(t));
        /// <summary>Godot の Color.lightened</summary>
        public static Color Lightened(Color c, float k) => new Color(c.r + (1f - c.r) * k, c.g + (1f - c.g) * k, c.b + (1f - c.b) * k, c.a);
        /// <summary>Godot の Color.darkened</summary>
        public static Color Darkened(Color c, float k) => new Color(c.r * (1f - k), c.g * (1f - k), c.b * (1f - k), c.a);

        /// <summary>Godot 座標（px、下が +y）→ Unity 世界座標</summary>
        public static Vector3 ToWorld(Vector2 p) => new Vector3(p.x - W * 0.5f, H * 0.5f - p.y, 0f);
        public static Vector2 FromWorld(Vector3 w) => new Vector2(w.x + W * 0.5f, H * 0.5f - w.y);

        public static bool OffScreen(Vector2 p, float pad = 80f) => p.x < -pad || p.x > W + pad || p.y < -pad || p.y > H + pad;

        public static Vector2 Dir(float a) => new Vector2(Mathf.Cos(a), Mathf.Sin(a));
        public static Vector2 Orth(Vector2 v) => new Vector2(-v.y, v.x);   // Godot の orthogonal()
        public static float Rand(float lo, float hi) => Random.Range(lo, hi);
        public static float Angle(Vector2 v) => Mathf.Atan2(v.y, v.x);
    }
}
