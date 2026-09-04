using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 画面に固定された UI の描画層。図形（下）→ 絵 → 図形（上）→ 文字 の順に重なる。
    /// Godot の CanvasLayer + _draw に相当。座標は Godot px。
    /// </summary>
    public class UiLayer : MonoBehaviour
    {
        public Vec back;      // 絵の下に敷く板・地
        public ImageLayer img;
        public Vec front;     // 絵の上の枠・ゲージ・記号
        public WorldText text;
        public int order;

        public static UiLayer Create(Transform parent, string name, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            var l = go.AddComponent<UiLayer>();
            l.order = order;
            l.back = Vec.Create(go.transform, "back", order, false, true);
            l.img = ImageLayer.Create(go.transform, order + 1);
            l.front = Vec.Create(go.transform, "front", order + 2, false, true);
            l.text = WorldText.Create(go.transform, order + 3);
            return l;
        }

        public void Begin() { back.Begin(); img.Begin(); front.Begin(); text.Begin(); }
        public void End() { back.End(); img.End(); front.End(); text.End(); }

        public void SetVisible(bool v)
        {
            if (gameObject.activeSelf != v) gameObject.SetActive(v);
        }

        /// <summary>何も描かずに空にする。</summary>
        public void Clear() { Begin(); End(); }
    }
}
