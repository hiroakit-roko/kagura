using UnityEngine;

namespace Kagura.Game
{
    /// <summary>シーンに 1 つ置くだけで、カメラ・HUD・ゲーム進行を組み立てる。</summary>
    public class Bootstrap : MonoBehaviour
    {
        private void Awake()
        {
            var cam = Camera.main;
            if (cam == null)
            {
                var cg = new GameObject("Main Camera", typeof(Camera));
                cg.tag = "MainCamera";
                cam = cg.GetComponent<Camera>();
            }
            cam.orthographic = true;
            cam.backgroundColor = new Color(0.035f, 0.024f, 0.10f);
            cam.clearFlags = CameraClearFlags.SolidColor;

            var gm = gameObject.AddComponent<GameManager>();
            gm.hud = Hud.Create(transform);
        }
    }
}
