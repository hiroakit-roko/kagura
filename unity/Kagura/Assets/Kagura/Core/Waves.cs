using System;
using System.Collections.Generic;
using System.Linq;

namespace Kagura.Core
{
    /// <summary>乱数の差し替え口。Unity では UnityEngine.Random、テストでは System.Random を包む。</summary>
    public interface IRng
    {
        /// <summary>[0, 1)</summary>
        float Next01();
        /// <summary>lo 以上 hi 以下の整数</summary>
        int Range(int lo, int hi);
    }

    public sealed class SystemRng : IRng
    {
        private readonly Random _r;
        public SystemRng(int seed) { _r = new Random(seed); }
        public float Next01() => (float)_r.NextDouble();
        public int Range(int lo, int hi) => _r.Next(lo, hi + 1);
    }

    /// <summary>段（ステージ）と波の進行。Godot 版 Cfg の移植。</summary>
    public static class Stages
    {
        public const int StageLen = 8;
        public const int StageCount = 3;
        public static readonly string[] Names = { "参道", "拝殿", "奥宮" };
        public static readonly string[] Kanji = { "一", "二", "三" };

        /// <summary>踏破後（エンドレス）は 3 段を巡回する。</summary>
        public static int StageOf(int wave) => (Math.Max(wave, 1) - 1) / StageLen % StageCount + 1;
        public static bool IsBossWave(int wave) => wave % StageLen == 0;
        public static bool IsFinalWave(int wave) => wave == StageLen * StageCount;
    }

    /// <summary>敵の種類・コスト・解禁・成長。Godot 版 game.gd / enemy.gd の移植。</summary>
    public static class Enemies
    {
        public const float PlayW = 640f;

        public static readonly Dictionary<string, string> Names = new Dictionary<string, string>
        {
            { "grunt", "鬼火" }, { "weaver", "傘の怪" }, { "charger", "突撃鬼" }, { "turret", "百目" },
            { "splitter", "分かれ玉" }, { "mini", "小玉" }, { "spirit", "人魂" }, { "lantern", "提灯お化け" },
            { "kite", "凧" }, { "oni", "小鬼" }, { "caster", "陰陽師" }, { "bomber", "火の玉" }, { "boss", "大妖" },
        };

        /// <summary>波の総量に対する 1 体のコスト。</summary>
        public static readonly Dictionary<string, float> Cost = new Dictionary<string, float>
        {
            { "grunt", 1.0f }, { "weaver", 1.4f }, { "charger", 1.8f }, { "turret", 2.4f }, { "splitter", 2.6f },
            { "spirit", 0.5f }, { "lantern", 2.0f }, { "kite", 1.2f }, { "oni", 3.6f }, { "caster", 3.0f }, { "bomber", 1.5f },
        };

        /// <summary>解禁される波。</summary>
        public static readonly Dictionary<string, int> Unlock = new Dictionary<string, int>
        {
            { "grunt", 1 }, { "spirit", 2 }, { "weaver", 2 }, { "charger", 3 }, { "lantern", 4 }, { "kite", 5 },
            { "turret", 6 }, { "oni", 7 }, { "splitter", 8 }, { "caster", 9 }, { "bomber", 11 },
        };

        /// <summary>HP の倍率。後半は神器も強くなるので二乗で伸ばす。</summary>
        public static float HpScale(int wave) => 1.2f + wave * 0.30f + wave * wave * 0.017f;

        /// <summary>速さの倍率。</summary>
        public static float SpeedScale(int wave) => 1.08f + wave * 0.03f;

        /// <summary>同時に存在できる敵弾・雑魚の上限（処理落ち対策）。</summary>
        public const int EnemyBulletCap = 150;
        public const int EnemyCap = 34;

        /// <summary>ボスの最大 HP。tier は 1〜3、最終ボスは 4.2 倍。</summary>
        public static float BossMaxHp(int tier, bool isFinal) =>
            1300f * (1f + (tier - 1) * 1f) * (isFinal ? 4.2f : 1f);
    }

    /// <summary>1 つの波に出す敵の予定表を作る。Godot 版 Game._build_wave の移植。</summary>
    public static class WaveBuilder
    {
        public static List<SpawnEntry> Build(int w, IRng rng)
        {
            // 解禁済みの敵から毎回 3〜4 種を選び、順番に混ぜて単調にならないようにする
            var avail = Enemies.Unlock.Where(kv => w >= kv.Value).Select(kv => kv.Key).ToList();
            Shuffle(avail, rng);
            var kinds = avail.Take(Math.Min(avail.Count, 3 + (w >= 6 ? 1 : 0))).ToList();
            if (w >= 3 && !kinds.Contains("grunt") && rng.Next01() < 0.5f)
                kinds.Add("grunt");
            int ki = 0;

            // 敵の総量。踏破後は頭打ちにして、個々の強さで難度を出す
            int wb = Math.Min(w, 26);
            float budget = (8f + wb * 2.2f + wb * wb * 0.06f) * 0.9f;
            var outList = new List<SpawnEntry>();
            float tt = 0.7f;
            float pace = Math.Clamp(1f - w * 0.02f, 0.55f, 1f);   // 後半は間隔が詰まる
            int guard = 0;
            float W = Enemies.PlayW;
            while (budget > 0f && guard < 80)
            {
                guard++;
                string k = kinds[ki % kinds.Count];
                ki++;
                int n = rng.Range(3, 5);
                switch (k)
                {
                    case "turret": case "splitter": case "oni": n = rng.Range(1, 2); break;
                    case "charger": case "lantern": case "caster": n = rng.Range(2, 3); break;
                    case "spirit": n = rng.Range(5, 7); break;
                    case "kite": case "bomber": n = rng.Range(3, 4); break;
                }
                int pattern = rng.Range(0, 3);
                float side = rng.Next01() < 0.5f ? 1f : -1f;
                for (int i = 0; i < n; i++)
                {
                    float x = 0f, y = -46f;
                    if (k == "kite")
                    {
                        // 凧は横から入ってくる
                        x = side > 0f ? -40f : W + 40f;
                        y = 40f + rng.Next01() * 180f;
                        outList.Add(new SpawnEntry { Kind = k, X = x, Y = y, T = tt });
                        tt += 0.25f * pace;
                        budget -= Enemies.Cost[k];
                        continue;
                    }
                    switch (pattern)
                    {
                        case 0: // 横一列
                            x = W * ((i + 1) / (float)(n + 1));
                            break;
                        case 1: // V 字
                            x = W * 0.5f + (i - (n - 1) * 0.5f) * 66f;
                            y -= Math.Abs(i - (n - 1) * 0.5f) * 42f;
                            break;
                        case 2: // 縦の列（片側から）
                            x = W * 0.5f + side * 180f;
                            y -= i * 46f;
                            break;
                        default: // ばらまき
                            x = 60f + rng.Next01() * (W - 120f);
                            break;
                    }
                    outList.Add(new SpawnEntry { Kind = k, X = Math.Clamp(x, 44f, W - 44f), Y = y, T = tt });
                    tt += 0.2f * pace;
                    budget -= Enemies.Cost[k];
                }
                tt += (0.6f + rng.Next01() * 0.5f) * pace;
            }
            return outList.OrderBy(e => e.T).ToList();
        }

        private static void Shuffle<T>(IList<T> list, IRng rng)
        {
            for (int i = list.Count - 1; i > 0; i--)
            {
                int j = rng.Range(0, i);
                (list[i], list[j]) = (list[j], list[i]);
            }
        }
    }
}
