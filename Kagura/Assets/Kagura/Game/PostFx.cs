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
            bloom.threshold.Override(0.85f);
            bloom.intensity.Override(0.9f);
            bloom.scatter.Override(0.72f);
            bloom.tint.Override(new Color(0.9f, 0.85f, 1f));
            var vig = profile.Add<Vignette>(true);
            vig.intensity.Override(0.22f);
            vig.smoothness.Override(0.5f);
            vig.color.Override(new Color(0.03f, 0.02f, 0.06f));
            vol.profile = profile;
        }
    }
}
