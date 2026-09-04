using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// Godot の CanvasItem 相当のベクター描画。座標は親ノードのローカル px（下が +y）。
    /// 描き手は Begin() → Draw* → End() で 1 枚のメッシュを組む。通常合成と加算合成を選べる。
    /// サブメッシュ 0 = 図形（白テクスチャ）、1 = 発光（丸い光のテクスチャ）。
    /// </summary>
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
    public class Vec : MonoBehaviour
    {
        private static Material _matShape, _matGlow, _matShapeAdd, _matGlowAdd;
        private static Texture2D _white, _glowTex;

        private Mesh _mesh;
        private MeshRenderer _mr;
        private readonly List<Vector3> _v = new List<Vector3>(512);
        private readonly List<Color32> _c = new List<Color32>(512);
        private readonly List<Vector2> _uv = new List<Vector2>(512);
        private readonly List<int> _tri = new List<int>(1024);
        private readonly List<int> _triGlow = new List<int>(256);
        private bool _additive;
        /// <summary>true なら Godot 座標の原点（画面左上）を基準に描く（背景・UI・Fx）。false なら親ノード中心。</summary>
        public bool screenSpace;

        // draw_set_transform 相当
        private Vector2 _tOff;
        private float _tRot;
        private Vector2 _tScale = Vector2.one;
        private bool _tOn;

        public int SortingOrder { get => _mr.sortingOrder; set => _mr.sortingOrder = value; }

        public static Vec Create(Transform parent, string name, int sortingOrder, bool additive = false, bool screenSpace = false)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            // ローカルの y 下向き（Godot）を世界の y 上向きへ
            go.transform.localScale = new Vector3(1f, -1f, 1f);
            var v = go.AddComponent<Vec>();
            v._additive = additive;
            v.screenSpace = screenSpace;
            if (screenSpace) go.transform.position = Gd.ToWorld(Vector2.zero);
            v.Init();
            v._mr.sortingOrder = sortingOrder;
            return v;
        }

        private void Init()
        {
            EnsureMaterials();
            _mesh = new Mesh { name = "vec" };
            _mesh.MarkDynamic();
            GetComponent<MeshFilter>().sharedMesh = _mesh;
            _mr = GetComponent<MeshRenderer>();
            _mr.sharedMaterials = _additive ? new[] { _matShapeAdd, _matGlowAdd } : new[] { _matShape, _matGlow };
            _mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            _mr.receiveShadows = false;
            _mr.lightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off;
        }

        private static void EnsureMaterials()
        {
            if (_matShape != null) return;
            _white = new Texture2D(4, 4, TextureFormat.RGBA32, false);
            var px = new Color32[16];
            for (int i = 0; i < 16; i++) px[i] = new Color32(255, 255, 255, 255);
            _white.SetPixels32(px); _white.Apply();
            // 中心が白く外へ溶ける光（Godot 版 Fx._ensure_glow と同じ式）
            int n = 96;
            _glowTex = new Texture2D(n, n, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            var g = new Color32[n * n];
            for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float d = new Vector2(x + 0.5f - n * 0.5f, y + 0.5f - n * 0.5f).magnitude / (n * 0.5f);
                    float a = Mathf.Clamp01(1f - d);
                    a = a * a * (1f + 0.6f * a);
                    g[y * n + x] = new Color32(255, 255, 255, (byte)(Mathf.Min(a, 1f) * 255f));
                }
            _glowTex.SetPixels32(g); _glowTex.Apply();

            var baseMat = Resources.Load<Material>("Materials/Vec");
            var sh = baseMat != null ? baseMat.shader : Shader.Find("Kagura/Vec");
            if (sh == null) { Debug.LogError("[Kagura] Vec shader missing"); sh = Shader.Find("Sprites/Default"); }
            Material Make(Texture2D t, bool add)
            {
                var m = new Material(sh) { mainTexture = t };
                m.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
                m.SetFloat("_DstBlend", add ? (float)UnityEngine.Rendering.BlendMode.One : (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                return m;
            }
            _matShape = Make(_white, false);
            _matGlow = Make(_glowTex, false);
            _matShapeAdd = Make(_white, true);
            _matGlowAdd = Make(_glowTex, true);
        }

        // ---------- フレームの組み立て ----------

        public void Begin()
        {
            if (screenSpace) transform.position = Gd.ToWorld(Vector2.zero);
            _v.Clear(); _c.Clear(); _uv.Clear(); _tri.Clear(); _triGlow.Clear();
            _tOn = false;
        }

        public void End()
        {
            _mesh.Clear();
            if (_v.Count == 0) { _mr.enabled = false; return; }
            _mr.enabled = true;
            _mesh.SetVertices(_v);
            _mesh.SetColors(_c);
            _mesh.SetUVs(0, _uv);
            _mesh.subMeshCount = 2;
            _mesh.SetTriangles(_tri, 0, false);
            _mesh.SetTriangles(_triGlow, 1, false);
            _mesh.RecalculateBounds();
        }

        /// <summary>Godot の draw_set_transform。Reset は SetTransform(Vector2.zero, 0, Vector2.one)。</summary>
        public void SetTransform(Vector2 offset, float rot, Vector2 scale)
        {
            _tOff = offset; _tRot = rot; _tScale = scale;
            _tOn = offset != Vector2.zero || rot != 0f || scale != Vector2.one;
        }

        private Vector2 X(Vector2 p)
        {
            if (!_tOn) return p;
            p = new Vector2(p.x * _tScale.x, p.y * _tScale.y);
            if (_tRot != 0f)
            {
                float c = Mathf.Cos(_tRot), s = Mathf.Sin(_tRot);
                p = new Vector2(p.x * c - p.y * s, p.x * s + p.y * c);
            }
            return p + _tOff;
        }

        private int Add(Vector2 p, Color32 col, Vector2 uv)
        {
            _v.Add(X(p)); _c.Add(col); _uv.Add(uv);
            return _v.Count - 1;
        }

        private void Quad(Vector2 a, Vector2 b, Vector2 c, Vector2 d, Color32 col)
        {
            int i = Add(a, col, Vector2.zero); Add(b, col, Vector2.zero); Add(c, col, Vector2.zero); Add(d, col, Vector2.zero);
            _tri.Add(i); _tri.Add(i + 1); _tri.Add(i + 2);
            _tri.Add(i); _tri.Add(i + 2); _tri.Add(i + 3);
        }

        // ---------- 描画命令（Godot と同じ名前・引数順） ----------

        public void DrawLine(Vector2 a, Vector2 b, Color col, float width = 1f, bool aa = false)
        {
            Vector2 d = b - a;
            if (d.sqrMagnitude < 1e-8f) return;
            Vector2 n = Gd.Orth(d.normalized) * (Mathf.Max(width, 0.5f) * 0.5f);
            Quad(a + n, b + n, b - n, a - n, col);
        }

        public void DrawPolyline(IList<Vector2> pts, Color col, float width = 1f, bool aa = false)
        {
            for (int i = 0; i + 1 < pts.Count; i++) DrawLine(pts[i], pts[i + 1], col, width, aa);
            // 継ぎ目を丸める（太い線のとき）
            if (width >= 3f) for (int i = 1; i + 1 < pts.Count; i++) DrawCircle(pts[i], width * 0.5f, col);
        }

        public void DrawMultiline(IList<Vector2> pts, Color col, float width = 1f)
        {
            for (int i = 0; i + 1 < pts.Count; i += 2) DrawLine(pts[i], pts[i + 1], col, width);
        }

        public void DrawCircle(Vector2 c, float r, Color col)
        {
            int seg = Mathf.Clamp(Mathf.CeilToInt(r * 0.9f) + 8, 10, 56);
            Color32 cc = col;
            int center = Add(c, cc, Vector2.zero);
            int first = _v.Count;
            for (int i = 0; i < seg; i++)
            {
                float a = Gd.TAU * i / seg;
                Add(c + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r, cc, Vector2.zero);
            }
            for (int i = 0; i < seg; i++)
            {
                _tri.Add(center); _tri.Add(first + i); _tri.Add(first + (i + 1) % seg);
            }
        }

        public void DrawArc(Vector2 c, float r, float a0, float a1, int segments, Color col, float width = 1f, bool aa = false)
        {
            segments = Mathf.Max(2, segments);
            float hw = Mathf.Max(width, 0.5f) * 0.5f;
            Color32 cc = col;
            int start = _v.Count;
            for (int i = 0; i <= segments; i++)
            {
                float a = Mathf.Lerp(a0, a1, (float)i / segments);
                Vector2 d = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                Add(c + d * (r + hw), cc, Vector2.zero);
                Add(c + d * (r - hw), cc, Vector2.zero);
            }
            for (int i = 0; i < segments; i++)
            {
                int k = start + i * 2;
                _tri.Add(k); _tri.Add(k + 2); _tri.Add(k + 1);
                _tri.Add(k + 1); _tri.Add(k + 2); _tri.Add(k + 3);
            }
        }

        public void DrawRect(Rect rc, Color col, bool filled = true, float width = 1f)
        {
            if (filled)
            {
                Quad(new Vector2(rc.xMin, rc.yMin), new Vector2(rc.xMax, rc.yMin), new Vector2(rc.xMax, rc.yMax), new Vector2(rc.xMin, rc.yMax), col);
                return;
            }
            DrawLine(new Vector2(rc.xMin, rc.yMin), new Vector2(rc.xMax, rc.yMin), col, width);
            DrawLine(new Vector2(rc.xMax, rc.yMin), new Vector2(rc.xMax, rc.yMax), col, width);
            DrawLine(new Vector2(rc.xMax, rc.yMax), new Vector2(rc.xMin, rc.yMax), col, width);
            DrawLine(new Vector2(rc.xMin, rc.yMax), new Vector2(rc.xMin, rc.yMin), col, width);
        }

        /// <summary>draw_colored_polygon。凹多角形も耳切りで三角形化する。</summary>
        public void DrawColoredPolygon(IList<Vector2> pts, Color col)
        {
            int n = pts.Count;
            if (n < 3) return;
            Color32 cc = col;
            int start = _v.Count;
            for (int i = 0; i < n; i++) Add(pts[i], cc, Vector2.zero);
            if (n == 3) { _tri.Add(start); _tri.Add(start + 1); _tri.Add(start + 2); return; }
            if (n == 4 || IsConvex(pts))
            {
                for (int i = 1; i + 1 < n; i++) { _tri.Add(start); _tri.Add(start + i); _tri.Add(start + i + 1); }
                return;
            }
            EarClip(pts, start);
        }

        private static bool IsConvex(IList<Vector2> p)
        {
            int n = p.Count; int sign = 0;
            for (int i = 0; i < n; i++)
            {
                Vector2 a = p[i], b = p[(i + 1) % n], c = p[(i + 2) % n];
                float cr = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
                int s = cr > 1e-6f ? 1 : (cr < -1e-6f ? -1 : 0);
                if (s == 0) continue;
                if (sign == 0) sign = s; else if (s != sign) return false;
            }
            return true;
        }

        private static readonly List<int> _idx = new List<int>();
        private void EarClip(IList<Vector2> p, int start)
        {
            int n = p.Count;
            _idx.Clear();
            // 面積の符号で向きを揃える
            float area = 0f;
            for (int i = 0; i < n; i++) { var a = p[i]; var b = p[(i + 1) % n]; area += a.x * b.y - b.x * a.y; }
            if (area >= 0) for (int i = 0; i < n; i++) _idx.Add(i); else for (int i = n - 1; i >= 0; i--) _idx.Add(i);
            int guard = 0;
            while (_idx.Count > 3 && guard++ < 1000)
            {
                bool cut = false;
                for (int i = 0; i < _idx.Count; i++)
                {
                    int i0 = _idx[(i + _idx.Count - 1) % _idx.Count], i1 = _idx[i], i2 = _idx[(i + 1) % _idx.Count];
                    Vector2 a = p[i0], b = p[i1], c = p[i2];
                    if ((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) <= 0f) continue;   // 反射角
                    bool inside = false;
                    for (int j = 0; j < _idx.Count; j++)
                    {
                        int k = _idx[j];
                        if (k == i0 || k == i1 || k == i2) continue;
                        if (PointInTri(p[k], a, b, c)) { inside = true; break; }
                    }
                    if (inside) continue;
                    _tri.Add(start + i0); _tri.Add(start + i1); _tri.Add(start + i2);
                    _idx.RemoveAt(i);
                    cut = true;
                    break;
                }
                if (!cut) break;
            }
            if (_idx.Count == 3) { _tri.Add(start + _idx[0]); _tri.Add(start + _idx[1]); _tri.Add(start + _idx[2]); }
        }

        private static bool PointInTri(Vector2 p, Vector2 a, Vector2 b, Vector2 c)
        {
            float d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y);
            float d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y);
            float d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y);
            bool neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
            return !(neg && pos);
        }

        /// <summary>やわらかい光を 1 枚（Godot 版 Fx.glow）。</summary>
        public void Glow(Vector2 pos, float r, Color col)
        {
            if (Gd.NoGlow) return;
            Color32 cc = col;
            int i = Add(pos + new Vector2(-r, -r), cc, new Vector2(0, 0));
            Add(pos + new Vector2(r, -r), cc, new Vector2(1, 0));
            Add(pos + new Vector2(r, r), cc, new Vector2(1, 1));
            Add(pos + new Vector2(-r, r), cc, new Vector2(0, 1));
            _triGlow.Add(i); _triGlow.Add(i + 1); _triGlow.Add(i + 2);
            _triGlow.Add(i); _triGlow.Add(i + 2); _triGlow.Add(i + 3);
        }

        /// <summary>楕円（Godot 版 Starfield._ellipse）。</summary>
        public void DrawEllipse(Vector2 c, float rw, float rh, Color col, int seg = 18)
        {
            var pts = new Vector2[seg];
            for (int i = 0; i < seg; i++) { float a = Gd.TAU * i / seg; pts[i] = c + new Vector2(Mathf.Cos(a) * rw, Mathf.Sin(a) * rh); }
            DrawColoredPolygon(pts, col);
        }
    }
}
