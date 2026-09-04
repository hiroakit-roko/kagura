using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Kagura.Core
{
    /// <summary>
    /// 能力の数式。Godot 版 scripts/kami.gd の value / fmt_value / describe / kami_power の移植。
    /// 正しさは export/data/abilities_by_level.json（Godot の出力）との照合テストで保証する。
    /// </summary>
    public static class Boons
    {
        /// <summary>神格 1 段ごとの神器の伸び。近距離の神は見返りとして大きい。</summary>
        public static readonly Dictionary<string, float> Growth = new Dictionary<string, float>
        {
            { "tsuki", 0.18f }, { "uzume", 0.18f }, { "susa", 0.15f },
        };

        public const float DefaultGrowth = 0.12f;

        public static float GrowthOf(string kamiId) =>
            Growth.TryGetValue(kamiId, out var g) ? g : DefaultGrowth;

        /// <summary>神格レベルによる神器の倍率。</summary>
        public static float KamiPower(int lv, float growth = DefaultGrowth) => 1.0f + growth * (lv - 1);

        /// <summary>神格レベルアップに必要な神徳（その段階で必要な量）。</summary>
        public static float KamiXpNeed(int lv) => 480.0f * (float)Math.Pow(lv, 1.6);

        /// <summary>
        /// 能力の現在値。神の能力（tier 付き）は格が設計上の強さを表すので倍率をかけず、
        /// 重ねた回数（lv）で伸びる。伝説・双神も倍率なし。
        /// </summary>
        public static double Value(BoonDef b, int rar, int lv)
        {
            double baseV = b.@base;
            string fmt = b.fmt;
            double mult = RarityTable.Mult[rar];
            if (b.tier.HasValue || rar == (int)Rarity.Legendary || rar == (int)Rarity.Duo)
                mult = 1.0;
            if (fmt == "num" && baseV <= 2.0)
                // 「+1 本」のような本数系は、格に関係なく重ねた回数ぶん増える
                return baseV * Math.Max(lv, 1);
            int idx = Math.Clamp(lv - 1, 0, RarityTable.LvBonus.Length - 1);
            mult += RarityTable.LvBonus[idx];
            if (fmt == "sec_down")
                return Math.Max(baseV * 0.3, baseV / mult);
            return baseV * mult;
        }

        /// <summary>値を表示用の文字列に。Godot の "%.1f%%" / "%d%%" / "%.1f秒" と同じ丸め。</summary>
        public static string FormatValue(BoonDef b, double v)
        {
            switch (b.fmt)
            {
                case "pct":
                    return v < 10.0 ? F1(v) + "%" : RoundInt(v) + "%";
                case "num":
                    return RoundInt(v).ToString(CultureInfo.InvariantCulture);
                case "sec":
                case "sec_down":
                    return F1(v) + "秒";
                default:
                    return F1(v);
            }
        }

        /// <summary>説明文に現在値を埋め込む。</summary>
        public static string Describe(BoonDef b, int rar, int lv) =>
            b.desc.Replace("{v}", FormatValue(b, Value(b, rar, lv)));

        public static IEnumerable<BoonDef> UpgradesOf(IEnumerable<BoonDef> all, string kamiId) =>
            all.Where(b => b.kami == kamiId && b.IsGodUpgrade);

        public static BoonDef LegendaryOf(IEnumerable<BoonDef> all, string kamiId) =>
            all.FirstOrDefault(b => b.kami == kamiId && b.IsLegendary);

        // Godot（C の printf）は小数を「四捨五入（偶数丸めではない）」で表示するので合わせる
        private static string F1(double v) =>
            Math.Round(v, 1, MidpointRounding.AwayFromZero).ToString("0.0", CultureInfo.InvariantCulture);

        private static long RoundInt(double v) => (long)Math.Round(v, MidpointRounding.AwayFromZero);
    }
}
