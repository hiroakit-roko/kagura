using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using Kagura.Core;
using Xunit;

namespace Kagura.Core.Tests
{
    /// <summary>Godot 版の出力（export/data）と C# 移植の結果が一致することを確かめる。</summary>
    public class ParityTests
    {
        private static readonly JsonSerializerOptions Opt = new JsonSerializerOptions
        {
            IncludeFields = true,
            PropertyNameCaseInsensitive = true,
            NumberHandling = JsonNumberHandling.AllowReadingFromString,
        };

        private static string DataPath(string name) => Path.Combine(AppContext.BaseDirectory, "data", name);

        private static T Load<T>(string name) => JsonSerializer.Deserialize<T>(File.ReadAllText(DataPath(name)), Opt);

        private class LevelRow { public int lv; public double value; public string text; }
        private class AbilityRow { public string id; public int rar; public List<LevelRow> levels; }

        [Fact]
        public void 能力の値と説明文がGodot版と一致する()
        {
            var boons = Load<List<BoonDef>>("boons.json");
            var expected = Load<List<AbilityRow>>("abilities_by_level.json");
            Assert.True(expected.Count >= 100, "正解データが少なすぎる");
            var byId = boons.ToDictionary(b => b.id);
            var mismatches = new List<string>();
            foreach (var row in expected)
            {
                var b = byId[row.id];
                foreach (var lv in row.levels)
                {
                    double v = Boons.Value(b, row.rar, lv.lv);
                    if (Math.Abs(v - lv.value) > 1e-4)
                        mismatches.Add($"{row.id} Lv{lv.lv}: value {v} != {lv.value}");
                    string t = Boons.Describe(b, row.rar, lv.lv);
                    if (t != lv.text)
                        mismatches.Add($"{row.id} Lv{lv.lv}: text '{t}' != '{lv.text}'");
                }
            }
            Assert.True(mismatches.Count == 0, string.Join("\n", mismatches.Take(20)));
        }

        [Fact]
        public void 神は9柱で各神の能力は凡4稀3秀2()
        {
            var kami = Load<List<KamiDef>>("kami.json");
            var boons = Load<List<BoonDef>>("boons.json");
            Assert.Equal(9, kami.Count);
            foreach (var k in kami)
            {
                var ups = Boons.UpgradesOf(boons, k.id).ToList();
                Assert.Equal(9, ups.Count);
                Assert.Equal(4, ups.Count(b => b.tier == (int)Rarity.Common));
                Assert.Equal(3, ups.Count(b => b.tier == (int)Rarity.Rare));
                Assert.Equal(2, ups.Count(b => b.tier == (int)Rarity.Epic));
                Assert.NotNull(Boons.LegendaryOf(boons, k.id));
            }
        }

        [Fact]
        public void 神宝は18種()
        {
            var relics = Load<List<RelicDef>>("relics.json");
            Assert.Equal(18, relics.Count);
            Assert.All(relics, r => Assert.False(string.IsNullOrEmpty(r.desc)));
        }

        [Fact]
        public void 神格の伸びはGodot版と同じ()
        {
            Assert.Equal(0.18f, Boons.GrowthOf("tsuki"));
            Assert.Equal(0.12f, Boons.GrowthOf("ama"));
            Assert.Equal(1.0f, Boons.KamiPower(1, 0.18f), 5);
            Assert.Equal(1.0f + 0.18f * 7, Boons.KamiPower(8, 0.18f), 5);
            Assert.Equal(480.0f, Boons.KamiXpNeed(1), 3);
        }

        [Fact]
        public void 段と波の判定()
        {
            Assert.Equal(1, Stages.StageOf(1));
            Assert.Equal(1, Stages.StageOf(8));
            Assert.Equal(2, Stages.StageOf(9));
            Assert.Equal(3, Stages.StageOf(24));
            Assert.Equal(1, Stages.StageOf(25));   // 踏破後は巡回
            Assert.True(Stages.IsBossWave(8));
            Assert.True(Stages.IsFinalWave(24));
            Assert.False(Stages.IsFinalWave(48));
        }

        [Fact]
        public void 波の予定表は時刻順で解禁済みの敵だけ()
        {
            for (int w = 1; w <= 30; w++)
            {
                var plan = WaveBuilder.Build(w, new SystemRng(w * 7919));
                Assert.NotEmpty(plan);
                for (int i = 1; i < plan.Count; i++)
                    Assert.True(plan[i - 1].T <= plan[i].T);
                Assert.All(plan, e => Assert.True(Enemies.Unlock[e.Kind] <= w, $"{e.Kind} は第{w}波では未解禁"));
                Assert.All(plan, e => Assert.InRange(e.X, -40f, Enemies.PlayW + 40f));
            }
            // 総量は第 26 波で頭打ち
            int c26 = Enumerable.Range(0, 20).Sum(s => WaveBuilder.Build(26, new SystemRng(s)).Count);
            int c40 = Enumerable.Range(0, 20).Sum(s => WaveBuilder.Build(40, new SystemRng(s)).Count);
            Assert.InRange(c40, c26 * 0.8, c26 * 1.2);
        }
    }
}
