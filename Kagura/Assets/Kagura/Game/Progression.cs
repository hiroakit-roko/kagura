namespace Kagura.Game
{
    /// <summary>神を迎える位（Godot 版 Boons.next_recruit_level）。主神は位 2、副神は位 4 と 6。</summary>
    public static class Progression
    {
        public static readonly int[] RecruitLevels = { 2, 4, 6 };
        public const int MaxGods = 3;
        public const int MaxPerKami = 3;

        public static int NextRecruitLevel(Player p)
        {
            int n = p.gods.Count;
            return n < RecruitLevels.Length ? RecruitLevels[n] : 0;
        }

        /// <summary>この位に達したとき神を迎えるか。</summary>
        public static bool IsRecruitLevel(Player p, int level)
        {
            int n = p.gods.Count;
            return n < RecruitLevels.Length && level >= RecruitLevels[n];
        }
    }
}
