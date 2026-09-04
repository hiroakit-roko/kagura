using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 絵（テクスチャ）を Godot px の矩形に敷く層。毎フレーム Begin → Draw → End で四角メッシュを使い回す。
    /// draw_texture_rect / draw_texture_rect_region / draw_cover に相当。
    /// </summary>
    public class ImageLayer : MonoBehaviour
    {
        private class Quad { public GameObject go; public MeshFilter mf; public MeshRenderer mr; public Mesh mesh; }
        private readonly List<Quad> _pool = new List<Quad>();
        private int _used;
        private int _order;
        private static readonly Dictionary<Texture, Material> _mats = new Dictionary<Texture, Material>();
        private static Shader _shader;

        public static ImageLayer Create(Transform parent, int sortingOrder)
        {
            var go = new GameObject("images");
            go.transform.SetParent(parent, false);
            var l = go.AddComponent<ImageLayer>();
            l._order = sortingOrder;
            return l;
        }

        private static Material MatFor(Texture tex)
        {
            if (_mats.TryGetValue(tex, out var m)) return m;
            if (_shader == null) { var bm = Resources.Load<Material>("Materials/Vec"); _shader = bm != null ? bm.shader : Shader.Find("Kagura/Vec"); }
            m = new Material(_shader) { mainTexture = tex };
            m.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
            m.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            _mats[tex] = m;
            return m;
        }

        public void Begin() { _used = 0; }
        public void End() { for (int i = _used; i < _pool.Count; i++) if (_pool[i].go.activeSelf) _pool[i].go.SetActive(false); }

        /// <summary>dst は Godot px 矩形、src はテクスチャの px 矩形（Godot と同じく左上原点）。</summary>
        public void Draw(Texture2D tex, Rect dst, Rect src, Color col)
        {
            if (tex == null) return;
            Quad q;
            if (_used < _pool.Count) q = _pool[_used];
            else
            {
                q = new Quad { go = new GameObject("img") };
                q.go.transform.SetParent(transform, false);
                q.mf = q.go.AddComponent<MeshFilter>();
                q.mr = q.go.AddComponent<MeshRenderer>();
                q.mesh = new Mesh();
                q.mesh.MarkDynamic();
                q.mf.sharedMesh = q.mesh;
                q.mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                q.mr.receiveShadows = false;
                _pool.Add(q);
            }
            _used++;
            if (!q.go.activeSelf) q.go.SetActive(true);
            q.mr.sharedMaterial = MatFor(tex);
            q.mr.sortingOrder = _order;
            float tw = tex.width, th = tex.height;
            // Godot の src は上が 0、Unity の UV は下が 0
            float u0 = src.xMin / tw, u1 = src.xMax / tw;
            float v0 = 1f - src.yMax / th, v1 = 1f - src.yMin / th;
            var a = Gd.ToWorld(new Vector2(dst.xMin, dst.yMin));
            var b = Gd.ToWorld(new Vector2(dst.xMax, dst.yMin));
            var c = Gd.ToWorld(new Vector2(dst.xMax, dst.yMax));
            var d = Gd.ToWorld(new Vector2(dst.xMin, dst.yMax));
            q.mesh.Clear();
            q.mesh.SetVertices(new List<Vector3> { a, b, c, d });
            q.mesh.SetUVs(0, new List<Vector2> { new Vector2(u0, v1), new Vector2(u1, v1), new Vector2(u1, v0), new Vector2(u0, v0) });
            q.mesh.SetColors(new List<Color> { col, col, col, col });
            q.mesh.SetTriangles(new[] { 0, 2, 1, 0, 3, 2 }, 0, false);
            q.mesh.RecalculateBounds();
        }

        public void Draw(Texture2D tex, Rect dst, Color col) { if (tex != null) Draw(tex, dst, new Rect(0, 0, tex.width, tex.height), col); }

        /// <summary>絵を枠いっぱいに敷く（cover。中心寄せ、上寄せ率 focusY）。Godot 版 Ui.draw_cover。</summary>
        public void DrawCover(Texture2D tex, Rect r, float a = 1f, float focusY = 0.35f)
        {
            if (tex == null) return;
            float tw = tex.width, th = tex.height;
            float scale = Mathf.Max(r.width / tw, r.height / th);
            float sw = r.width / scale, sh = r.height / scale;
            Draw(tex, r, new Rect((tw - sw) * 0.5f, (th - sh) * focusY, sw, sh), new Color(1, 1, 1, a));
        }
    }
}
