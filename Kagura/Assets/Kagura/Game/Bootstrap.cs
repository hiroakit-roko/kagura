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
            cam.backgroundColor = Gd.C_BG;
            cam.clearFlags = CameraClearFlags.SolidColor;

            gameObject.AddComponent<GameManager>();
        }
    }
}
