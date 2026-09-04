namespace Kagura.Core
{
    /// <summary>格。Godot 版 Cfg.Rar と同じ順序。</summary>
    public enum Rarity
    {
        Common = 0,
        Rare = 1,
        Epic = 2,
        Heroic = 3,
        Legendary = 4,
        Duo = 5,
    }

    public static class RarityTable
    {
        public static readonly string[] Names = { "凡", "稀", "秀", "英", "伝", "双" };
        public static readonly string[] LongNames = { "COMMON", "RARE", "EPIC", "HEROIC", "LEGENDARY", "DUO" };

        /// <summary>格ごとの効果倍率（神の能力・伝説・双神には掛けない）。</summary>
        public static readonly float[] Mult = { 1.0f, 1.35f, 1.8f, 2.3f, 1.0f, 1.0f };

        /// <summary>重ねた回数（Lv）による逓減ボーナス。</summary>
        public static readonly float[] LvBonus = { 0.0f, 0.28f, 0.48f, 0.62f, 0.72f, 0.79f, 0.84f, 0.88f };

        /// <summary>格の色（r, g, b）。</summary>
        public static readonly float[][] Colors =
        {
            new[] { 0.86f, 0.88f, 0.92f },  // 凡 白
            new[] { 0.40f, 0.72f, 1.00f },  // 稀 青
            new[] { 0.80f, 0.50f, 1.00f },  // 秀 紫
            new[] { 1.00f, 0.42f, 0.42f },  // 英 赤
            new[] { 1.00f, 0.72f, 0.25f },  // 伝 橙
            new[] { 0.45f, 1.00f, 0.62f },  // 双 緑
        };
    }
}
