using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>夜空の背景。星・月・流れる雲・舞い散る花弁・段ごとの景物（Godot 版 starfield.gd の移植）。</summary>
    public class Starfield : MonoBehaviour
    {
        private class Star { public Vector2 pos; public int layer; public float tw; }
        private class Cloud { public Vector2 pos; public float w, h, drift; public bool far; }
        private class Petal { public Vector2 pos, vel; public float rot, spin, size, phase; }

        private readonly List<Star> _stars = new List<Star>();
        private readonly List<Cloud> _clouds = new List<Cloud>();
        private readonly List<Petal> _petals = new List<Petal>();
        public float speed = 1f;
        public Color tint = new Color(0.45f, 0.30f, 0.80f);
        private Color _tintCur = new Color(0.45f, 0.30f, 0.80f);
        public int stage = 1;
        public bool scenery = true;
        private float _t, _pathY, _sceneryY;
        private Vec _vec;
        private readonly List<Vector2> _far0 = new List<Vector2>(), _far1 = new List<Vector2>();

        public static Starfield Create(Transform parent)
        {
            var go = new GameObject("stars");
            go.transform.SetParent(parent, false);
            var s = go.AddComponent<Starfield>();
            s._vec = Vec.Create(go.transform, "stars_vec", Gd.ZStars, false, true);
            return s;
        }

        private void Awake()
        {
            int[] counts = { 80, 45, 20 };
            for (int layer = 0; layer < 3; layer++)
                for (int i = 0; i < counts[layer]; i++)
                    _stars.Add(new Star { pos = new Vector2(Random.value * Gd.W, Random.value * Gd.H), layer = layer, tw = Random.value * Gd.TAU });
            for (int i = 0; i < 9; i++) _clouds.Add(NewCloud(true));
            for (int i = 0; i < 26; i++) _petals.Add(NewPetal(true));
        }

        private Cloud NewCloud(bool anywhere)
        {
            bool far = Random.value < 0.5f;
            return new Cloud
            {
                pos = new Vector2(Gd.Rand(-100f, Gd.W + 100f), anywhere ? Gd.Rand(-200f, Gd.H) : Gd.Rand(-260f, -140f)),
                w = Gd.Rand(160f, 320f) * (far ? 0.7f : 1f), h = Gd.Rand(28f, 52f) * (far ? 0.7f : 1f), far = far, drift = Gd.Rand(-8f, 8f),
            };
        }

        private Petal NewPetal(bool anywhere) => new Petal
        {
            pos = new Vector2(Random.value * Gd.W, anywhere ? Random.value * Gd.H : -10f),
            vel = new Vector2(Gd.Rand(-30f, 30f), Gd.Rand(70f, 150f)), rot = Random.value * Gd.TAU, spin = Gd.Rand(-4f, 4f), size = Gd.Rand(2.5f, 5f), phase = Random.value * Gd.TAU,
        };

        private void Update()
        {
            float delta = Time.deltaTime;
            _t += delta;
            _tintCur = Color.Lerp(_tintCur, tint, Mathf.Clamp01(delta * 1.5f));
            float[] baseSpd = { 22f, 55f, 120f };
            foreach (var s in _stars)
            {
                s.pos.y += baseSpd[s.layer] * speed * delta;
                if (s.pos.y > Gd.H + 4f) { s.pos.y = -4f; s.pos.x = Random.value * Gd.W; }
            }
            for (int i = 0; i < _clouds.Count; i++)
            {
                var c = _clouds[i];
                c.pos.y += (c.far ? 36f : 78f) * speed * delta;
                c.pos.x += c.drift * delta;
                if (c.pos.y > Gd.H + 120f) _clouds[i] = NewCloud(false);
            }
            for (int i = 0; i < _petals.Count; i++)
            {
                var p = _petals[i];
                p.pos += p.vel * speed * delta;
                p.pos.x += Mathf.Sin(_t * 1.3f + p.phase) * 22f * delta;
                p.rot += p.spin * delta;
                if (p.pos.y > Gd.H + 10f || p.pos.x < -20f || p.pos.x > Gd.W + 20f) _petals[i] = NewPetal(false);
            }
            _pathY = Mathf.Repeat(_pathY + 90f * speed * delta, 120f);
            _sceneryY = Mathf.Repeat(_sceneryY + 90f * speed * delta, 420f);
            Draw();
        }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            Color stint = Gd.STAGE_TINT[Mathf.Clamp(stage - 1, 0, 2)];
            Color mix = Color.Lerp(_tintCur, stint, 0.5f);
            Color top = Color.Lerp(Gd.C_BG, mix, 0.18f + 0.06f * (stage - 1));
            Color bottom = Gd.Darkened(Color.Lerp(Gd.C_BG, mix, 0.05f), 0.3f);
            int steps = 12;
            for (int i = 0; i < steps; i++)
            {
                float k0 = (float)i / steps, k1 = (float)(i + 1) / steps;
                float y0 = -80f + (Gd.H + 160f) * k0, y1 = -80f + (Gd.H + 160f) * k1;
                v.DrawRect(new Rect(-80, y0, Gd.W + 160, y1 - y0 + 1f), Color.Lerp(top, bottom, k0));
            }

            // 月
            Vector2 mp = new Vector2(Gd.W - 96f, 190f);
            Color[] moonCols = { new Color(0.93f, 0.90f, 0.80f, 0.42f), new Color(1f, 0.72f, 0.55f, 0.45f), new Color(0.85f, 0.75f, 1f, 0.5f) };
            Color moonCol = moonCols[Mathf.Clamp(stage - 1, 0, 2)];
            float mr = 34f + 8f * (stage - 1);
            v.DrawCircle(mp, mr * 2.2f, Gd.WithA(moonCol, 0.06f));
            v.DrawCircle(mp, mr, moonCol);
            v.DrawArc(mp, mr, 0f, Gd.TAU, 40, Gd.WithA(Gd.Lightened(moonCol, 0.3f), 0.5f), 1f);

            // 星
            Color[] cols = { new Color(0.65f, 0.62f, 0.90f, 0.5f), new Color(0.85f, 0.82f, 1f, 0.7f), new Color(1f, 0.96f, 0.85f, 0.95f) };
            _far0.Clear(); _far1.Clear();
            foreach (var s in _stars)
            {
                if (s.layer == 0) { _far0.Add(s.pos + new Vector2(-0.6f, 0)); _far0.Add(s.pos + new Vector2(0.6f, 0)); }
                else if (s.layer == 1) { _far1.Add(s.pos + new Vector2(-0.9f, 0)); _far1.Add(s.pos + new Vector2(0.9f, 0)); }
            }
            float twAll = 0.75f + 0.25f * Mathf.Sin(_t * 1.7f);
            v.DrawMultiline(_far0, Gd.WithA(cols[0], cols[0].a * twAll), 1.6f);
            v.DrawMultiline(_far1, Gd.WithA(cols[1], cols[1].a * twAll), 2.4f);
            foreach (var s in _stars)
            {
                if (s.layer != 2) continue;
                float tw = 0.7f + 0.3f * Mathf.Sin(_t * 3f + s.tw);
                Color c = cols[2]; c.a *= tw;
                v.DrawCircle(s.pos, 2.4f, c);
                if (tw > 0.95f)
                {
                    v.DrawLine(s.pos + new Vector2(-5, 0), s.pos + new Vector2(5, 0), Gd.WithA(c, 0.5f), 1f);
                    v.DrawLine(s.pos + new Vector2(0, -5), s.pos + new Vector2(0, 5), Gd.WithA(c, 0.5f), 1f);
                }
            }

            // 参道
            Color pc = Gd.WithA(Gd.Lightened(_tintCur, 0.3f), 0.045f);
            for (int i = -1; i < 10; i++)
            {
                float y = i * 120f + _pathY;
                v.DrawLine(new Vector2(Gd.W * 0.5f - 150f, y), new Vector2(Gd.W * 0.5f + 150f, y), pc, 2f);
            }
            v.DrawLine(new Vector2(Gd.W * 0.5f - 150f, -80), new Vector2(Gd.W * 0.5f - 150f, Gd.H + 80), pc, 2f);
            v.DrawLine(new Vector2(Gd.W * 0.5f + 150f, -80), new Vector2(Gd.W * 0.5f + 150f, Gd.H + 80), pc, 2f);

            if (scenery) DrawScenery(v, mix);

            // 雲
            foreach (var c2 in _clouds)
            {
                float a = c2.far ? 0.05f : 0.09f;
                Color cc = Gd.WithA(Gd.Lightened(_tintCur, 0.55f), a);
                for (int j = 0; j < 3; j++)
                {
                    Vector2 off = new Vector2((j - 1f) * c2.w * 0.26f, Mathf.Sin(j * 1.9f) * c2.h * 0.25f);
                    float rw = c2.w * (0.30f + 0.12f * Mathf.Abs(Mathf.Sin(j * 2.3f)));
                    float rh = c2.h * (0.7f + 0.3f * Mathf.Cos(j * 1.3f));
                    v.DrawEllipse(c2.pos + off, rw, rh, cc);
                }
            }

            // 花弁
            Color petalC = Gd.WithA(Gd.Lightened(_tintCur, 0.5f), 0.55f);
            foreach (var p in _petals)
            {
                Vector2 d = Gd.Dir(p.rot), n = Gd.Orth(d);
                float s2 = p.size;
                v.DrawColoredPolygon(new[] { p.pos + d * s2 * 1.5f, p.pos + n * s2 * 0.7f, p.pos - d * s2 * 1.5f, p.pos - n * s2 * 0.7f }, petalC);
            }
            v.End();
        }

        private void DrawScenery(Vec v, Color mix)
        {
            Color sil = Gd.WithA(new Color(0.02f, 0.01f, 0.04f), 0.75f);
            Color lit = Gd.WithA(Gd.Lightened(mix, 0.6f), 0.5f);
            switch (stage)
            {
                case 1:
                    for (int i = -1; i < 4; i++)
                    {
                        float y = i * 420f + _sceneryY;
                        foreach (float x in new[] { 40f, Gd.W - 40f })
                        {
                            v.DrawRect(new Rect(x - 4, y + 30, 8, 60), sil);
                            v.DrawRect(new Rect(x - 12, y + 14, 24, 18), sil);
                            v.DrawRect(new Rect(x - 16, y + 8, 32, 6), sil);
                            v.DrawCircle(new Vector2(x, y + 23), 4f + Mathf.Sin(_t * 6f + i) * 0.8f, new Color(1f, 0.8f, 0.5f, 0.55f));
                        }
                        float ty = y + 240f;
                        v.DrawRect(new Rect(-10, ty, Gd.W + 20, 14), sil);
                        v.DrawRect(new Rect(-10, ty + 26, Gd.W + 20, 8), sil);
                        v.DrawRect(new Rect(60, ty + 8, 14, 170), sil);
                        v.DrawRect(new Rect(Gd.W - 74, ty + 8, 14, 170), sil);
                    }
                    break;
                case 2:
                    for (int i = -1; i < 4; i++)
                    {
                        float y = i * 420f + _sceneryY;
                        foreach (float x in new[] { 28f, Gd.W - 28f })
                        {
                            v.DrawRect(new Rect(x - 9, y, 18, 420), Gd.WithA(new Color(0.05f, 0.02f, 0.05f), 0.7f));
                            v.DrawRect(new Rect(x - 12, y + 200, 24, 10), sil);
                        }
                        foreach (float x in new[] { 70f, Gd.W - 70f })
                        {
                            float ly = y + 120f;
                            v.DrawLine(new Vector2(x, ly - 30), new Vector2(x, ly), sil, 2f);
                            v.DrawCircle(new Vector2(x, ly + 14), 13f, new Color(1f, 0.45f, 0.35f, 0.55f));
                            v.DrawRect(new Rect(x - 6, ly - 2, 12, 4), sil);
                            v.DrawRect(new Rect(x - 6, ly + 26, 12, 4), sil);
                        }
                        v.DrawRect(new Rect(-10, y + 300, Gd.W + 20, 6), Gd.WithA(new Color(0.05f, 0.02f, 0.05f), 0.5f));
                    }
                    break;
                default:
                    for (int i = -1; i < 4; i++)
                    {
                        float y = i * 420f + _sceneryY;
                        foreach (float sgn in new[] { -1f, 1f })
                        {
                            float x0 = Gd.W * 0.5f + sgn * (Gd.W * 0.5f);
                            var pts = new List<Vector2> { new Vector2(x0, y), new Vector2(x0, y + 420) };
                            for (int j = 0; j < 6; j++)
                            {
                                float yy = y + 420f * (6 - j) / 6f;
                                pts.Add(new Vector2(x0 - sgn * (30f + 25f * Mathf.Abs(Mathf.Sin((i * 7 + j) * 1.7f))), yy));
                            }
                            v.DrawColoredPolygon(pts, Gd.WithA(new Color(0.04f, 0.02f, 0.06f), 0.85f));
                        }
                        float fy = y + 200f + Mathf.Sin(_t * 0.5f + i) * 10f;
                        v.DrawEllipse(new Vector2(Gd.W * 0.5f + Mathf.Sin(_t * 0.3f + i) * 40f, fy), Gd.W * 0.7f, 26f, Gd.WithA(new Color(0.7f, 0.6f, 0.9f), 0.06f));
                        v.DrawLine(new Vector2(Gd.W * 0.5f - 6, y + 40), new Vector2(Gd.W * 0.5f + 6, y + 140), lit, 1.5f);
                    }
                    break;
            }
        }
    }
}
