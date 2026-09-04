using UnityEngine;

namespace Kagura.Game
{
    /// <summary>音量の設定（曲・効果音）。0〜1 を PlayerPrefs に保存し、Music / Sfx が再生時に掛ける。</summary>
    public static class Audio
    {
        private static bool _loaded;
        private static float _bgm = 0.8f, _sfx = 0.8f;

        public static float Bgm { get { Load(); return _bgm; } set { Load(); _bgm = Mathf.Clamp01(value); } }
        public static float Sfx { get { Load(); return _sfx; } set { Load(); _sfx = Mathf.Clamp01(value); } }

        /// <summary>つまみの位置（線形）を耳に自然な増幅率へ。半分の位置でおよそ半分の大きさに聞こえる。</summary>
        public static float Gain(float v) => v <= 0f ? 0f : Mathf.Pow(v, 1.7f);
        public static float BgmGain => Gain(Bgm);
        public static float SfxGain => Gain(Sfx);

        private static void Load()
        {
            if (_loaded) return;
            _loaded = true;
            try
            {
                _bgm = Mathf.Clamp01(PlayerPrefs.GetFloat("kagura.vol_bgm", 0.8f));
                _sfx = Mathf.Clamp01(PlayerPrefs.GetFloat("kagura.vol_sfx", 0.8f));
            }
            catch { }
        }

        public static void Save()
        {
            try
            {
                PlayerPrefs.SetFloat("kagura.vol_bgm", _bgm);
                PlayerPrefs.SetFloat("kagura.vol_sfx", _sfx);
                PlayerPrefs.Save();
            }
            catch { }
        }
    }
}
