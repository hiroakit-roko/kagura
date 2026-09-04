using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Kagura.Game
{
    /// <summary>Unity 側の強みを足す：URP のブルームで発光を本物の光に近づける（Godot 版は手描きの光輪のみだった）。</summary>
    public static class PostFx
    {
        public static void Setup(Camera cam)
        {
            if (cam == null) return;
            var add = cam.GetComponent<UniversalAdditionalCameraData>();
            if (add == null) add = cam.gameObject.AddComponent<UniversalAdditionalCameraData>();
            add.renderPostProcessing = true;
            add.antialiasing = AntialiasingMode.None;
            var go = new GameObject("postfx", typeof(Volume));
            var vol = go.GetComponent<Volume>();
            vol.isGlobal = true;
            var profile = ScriptableObject.CreateInstance<VolumeProfile>();
            var bloom = profile.Add<Bloom>(true);
            // 発光（加算合成で 1.0 を超えた部分）だけを滲ませる。しきい値が低く散らばりが広いと画面全体に靄がかかり、
            // 黒が浮いてコントラストが落ちるので控えめにする
            bloom.threshold.Override(1.0f);
            bloom.intensity.Override(0.5f);
            bloom.scatter.Override(0.55f);
            bloom.tint.Override(new Color(0.92f, 0.88f, 1f));
            var vig = profile.Add<Vignette>(true);
            vig.intensity.Override(0.22f);
            vig.smoothness.Override(0.5f);
            vig.color.Override(new Color(0.03f, 0.02f, 0.06f));
            vol.profile = profile;
        }
    }
}
