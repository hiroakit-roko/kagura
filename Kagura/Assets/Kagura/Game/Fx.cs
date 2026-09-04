using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// パーティクル・ダメージ表示・画面シェイク・稲妻・斬撃・光の膨らみをまとめて描く層（Godot 版 fx.gd の移植）。
    /// すべて配列で管理し、1 つの加算合成メッシュで一括描画する。座標は Godot px。
    /// </summary>
    public class Fx : MonoBehaviour
    {
        public static Fx I;

        private class Part { public Vector2 pos, vel; public float drag, grav, life, maxlife, size; public Color color; public int shape; }
        private class Txt { public Vector2 pos, vel; public float life, maxlife, size; public string text; public Color color; public bool big; }
        private class Bolt { public Vector2[] pts; public Color color; public float life, maxlife; }
        private class Ring { public Vector2 pos; public Color color; public float r0, r1, life, maxlife, width; }
        private class Slash { public Vector2 pos; public float angle, r, sweep, life, maxlife, width; public Color color; }
        private class Zone { public Vector2 pos; public float r, life, maxlife; public Color color; }
        private class Ray { public Vector2 pos; public Color color; public int n; public float r0, len, rot, life, maxlife; }
        private class PuffFx { public Vector2 pos; public float r0, r1, life, maxlife; public Color color; }

        private readonly List<Part> _parts = new List<Part>();
        private readonly List<Txt> _texts = new List<Txt>();
        private readonly List<Bolt> _bolts = new List<Bolt>();
        private readonly List<Ring> _rings = new List<Ring>();
        private readonly List<Slash> _slashes = new List<Slash>();
        private readonly List<Zone> _zones = new List<Zone>();
        private readonly List<Ray> _rays = new List<Ray>();
        private readonly List<PuffFx> _puffs = new List<PuffFx>();

        public float shake;
        public Color flashCol = new Color(1, 1, 1, 0);
        public float flashT;
        private Vec _vec;
        private Vec _vecTop;   // 画面フラッシュなど通常合成で上に載せるもの
        public WorldText text;

        public static Fx Create(Transform parent)
        {
            var go = new GameObject("fx");
            go.transform.SetParent(parent, false);
            var fx = go.AddComponent<Fx>();
            fx._vec = Vec.Create(go.transform, "fx_add", Gd.ZFx, true, true);
            fx._vecTop = Vec.Create(go.transform, "fx_top", Gd.ZFx + 1, false, true);
            fx.text = WorldText.Create(go.transform, Gd.ZFx + 2);
            I = fx;
            return fx;
        }

        public int PartCount => _parts.Count;

        private void Update()
        {
            float delta = Time.deltaTime;
            shake = Mathf.Max(0f, shake - delta * 34f);
            flashT = Mathf.Max(0f, flashT - delta);
            if (_parts.Count > 420) _parts.RemoveRange(0, _parts.Count - 420);
            for (int i = _parts.Count - 1; i >= 0; i--)
            {
                var p = _parts[i];
                p.life -= delta;
                if (p.life <= 0f) { _parts.RemoveAt(i); continue; }
                p.pos += p.vel * delta;
                p.vel = Vector2.Lerp(p.vel, Vector2.zero, Mathf.Clamp01(p.drag * delta));
                p.vel.y += p.grav * delta;
            }
            for (int i = _texts.Count - 1; i >= 0; i--)
            {
                var t = _texts[i];
                t.life -= delta;
                if (t.life <= 0f) { _texts.RemoveAt(i); continue; }
                t.pos += t.vel * delta;
                t.vel.y += 130f * delta;
            }
            AgeBolts(_bolts, delta); AgeRings(_rings, delta); AgeSlashes(_slashes, delta); AgeZones(_zones, delta); AgeRays(_rays, delta); AgePuffs(_puffs, delta);
            Draw();
        }

        private static void AgeBolts(List<Bolt> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }
        private static void AgeRings(List<Ring> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }
        private static void AgeSlashes(List<Slash> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }
        private static void AgeZones(List<Zone> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }
        private static void AgeRays(List<Ray> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }
        private static void AgePuffs(List<PuffFx> l, float d) { for (int i = l.Count - 1; i >= 0; i--) { l[i].life -= d; if (l[i].life <= 0f) l.RemoveAt(i); } }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            foreach (var pf in _puffs)
            {
                float kp = 1f - pf.life / pf.maxlife;
                float rr = Mathf.Lerp(pf.r0, pf.r1, 1f - (1f - kp) * (1f - kp));
                Color cp = pf.color; cp.a *= (1f - kp) * 0.9f;
                v.Glow(pf.pos, rr, cp);
                v.Glow(pf.pos, rr * 0.45f, new Color(1, 1, 1, cp.a * 0.7f));
            }
            foreach (var z in _zones)
            {
                float k = 1f - z.life / z.maxlife;
                float a = Mathf.Min(1f, z.life * 3f) * 0.22f;
                v.DrawCircle(z.pos, z.r, Gd.WithA(z.color, a));
                v.DrawArc(z.pos, z.r, 0f, Gd.TAU, 48, Gd.WithA(z.color, a * 3f), 2f);
                float rot = k * 3f;
                for (int i = 0; i < 6; i++)
                {
                    float ang = rot + Gd.TAU * i / 6f;
                    v.DrawLine(z.pos + Gd.Dir(ang) * z.r * 0.55f, z.pos + Gd.Dir(ang) * z.r * 0.92f, Gd.WithA(z.color, a * 2f), 1.5f);
                }
            }
            foreach (var r in _rings)
            {
                float k2 = 1f - r.life / r.maxlife;
                Color col2 = r.color; col2.a = (1f - k2) * 0.85f;
                v.DrawArc(r.pos, Mathf.Lerp(r.r0, r.r1, k2), 0f, Gd.TAU, 48, col2, Mathf.Lerp(r.width, 1f, k2));
            }
            foreach (var s in _slashes)
            {
                float k3 = 1f - s.life / s.maxlife;
                float a3 = 1f - k3;
                float a0 = s.angle - s.sweep * 0.5f;
                float rr = s.r * (1f + k3 * 0.25f);
                float end = a0 + s.sweep * Mathf.Min(1f, k3 * 3f + 0.3f);
                v.DrawArc(s.pos, rr, a0, end, 28, Gd.WithA(s.color, a3 * 0.9f), s.width * (1f - k3 * 0.6f));
                v.DrawArc(s.pos, rr, a0, end, 28, new Color(1, 1, 1, a3 * 0.7f), s.width * 0.35f * (1f - k3));
            }
            foreach (var b in _bolts)
            {
                float a4 = b.life / b.maxlife;
                for (int i = 0; i + 1 < b.pts.Length; i++) v.DrawLine(b.pts[i], b.pts[i + 1], Gd.WithA(b.color, a4 * 0.45f), 6f * a4 + 1f);
                for (int i = 0; i + 1 < b.pts.Length; i++) v.DrawLine(b.pts[i], b.pts[i + 1], new Color(1, 1, 1, a4), 2f * a4 + 0.5f);
            }
            foreach (var ry in _rays)
            {
                float a5 = ry.life / ry.maxlife;
                for (int i = 0; i < ry.n; i++)
                {
                    float ang = ry.rot + Gd.TAU * i / ry.n;
                    float len = ry.len * (0.6f + 0.4f * Mathf.Sin(i * 1.7f + a5 * 6f));
                    v.DrawLine(ry.pos + Gd.Dir(ang) * ry.r0, ry.pos + Gd.Dir(ang) * (ry.r0 + len), Gd.WithA(ry.color, a5 * 0.7f), 3f);
                }
            }
            foreach (var p in _parts)
            {
                float k5 = p.life / p.maxlife;
                Color col6 = p.color; col6.a *= k5;
                float s2 = p.size * (k5 * 0.7f + 0.3f);
                if (p.shape == 0) v.Glow(p.pos, s2 * 3f, Gd.WithA(col6, col6.a * 0.35f));
                switch (p.shape)
                {
                    case 0: v.DrawRect(new Rect(p.pos.x - s2 * 0.5f, p.pos.y - s2 * 0.5f, s2, s2), col6); break;
                    case 1: v.DrawCircle(p.pos, s2, col6); break;
                    case 2:
                        {
                            Vector2 d = p.vel.magnitude > 1f ? p.vel.normalized : Vector2.down;
                            Vector2 n = Gd.Orth(d);
                            v.DrawColoredPolygon(new[] { p.pos + d * s2 * 1.4f, p.pos + n * s2 * 0.6f, p.pos - d * s2 * 1.4f, p.pos - n * s2 * 0.6f }, col6);
                            break;
                        }
                    default: v.DrawLine(p.pos, p.pos - p.vel * 0.03f, col6, Mathf.Max(1f, s2 * 0.5f)); break;
                }
            }
            v.End();

            _vecTop.Begin();
            if (flashT > 0f)
            {
                // ブルームの後処理があるので Godot 版より弱める（全面が閾値を超えると HUD まで白く滲む）
                float fa = flashCol.a * 0.55f * Mathf.Min(1f, flashT * 6f);
                _vecTop.DrawRect(new Rect(-100, -100, Gd.W + 200, Gd.H + 200), Gd.WithA(flashCol, fa));
            }
            _vecTop.End();

            text.Begin();
            foreach (var t in _texts)
            {
                float a6 = Mathf.Clamp01(t.life / t.maxlife * 1.6f);
                Color col7 = t.color; col7.a = a6;
                float pop = 1f + 0.5f * Mathf.Clamp01((t.life - t.maxlife + 0.12f) / 0.12f);
                text.Draw(t.pos, t.text, t.size * pop, col7, t.big ? WorldText.Face.Display : WorldText.Face.Bold, TextAnchor.MiddleCenter, true);
            }
            text.End();
        }

        // ---------- 静的ヘルパ（Godot 版と同じ名前） ----------

        public static void Burst(Vector2 pos, Color color, int count = 12, float spd = 240f, float size = 4f, float life = 0.5f, bool roundShape = false)
        {
            if (I == null) return;
            for (int i = 0; i < count; i++)
            {
                float a = Random.value * Gd.TAU;
                I._parts.Add(new Part { pos = pos, vel = Gd.Dir(a) * spd * Gd.Rand(0.25f, 1f), drag = 3f, grav = 0f,
                    life = life * Gd.Rand(0.6f, 1.2f), maxlife = life, size = size * Gd.Rand(0.6f, 1.3f), color = color, shape = roundShape ? 1 : 0 });
            }
        }

        public static void Cone(Vector2 pos, Vector2 dir, Color color, int count = 6, float spd = 200f, float spread = 0.6f, float size = 3f, float life = 0.3f)
        {
            if (I == null) return;
            for (int i = 0; i < count; i++)
            {
                float a = Gd.Angle(dir) + Gd.Rand(-spread, spread);
                I._parts.Add(new Part { pos = pos, vel = Gd.Dir(a) * spd * Gd.Rand(0.4f, 1f), drag = 5f, grav = 0f,
                    life = life * Gd.Rand(0.6f, 1.2f), maxlife = life, size = size * Gd.Rand(0.7f, 1.2f), color = color, shape = 1 });
            }
        }

        public static void Sparks(Vector2 pos, Vector2 dir, Color color, int count = 6, float spd = 420f)
        {
            if (I == null) return;
            for (int i = 0; i < count; i++)
            {
                float a = Gd.Angle(dir) + Gd.Rand(-1.1f, 1.1f);
                I._parts.Add(new Part { pos = pos, vel = Gd.Dir(a) * spd * Gd.Rand(0.5f, 1f), drag = 7f, grav = 300f,
                    life = Gd.Rand(0.12f, 0.28f), maxlife = 0.28f, size = Gd.Rand(2f, 4f), color = color, shape = 3 });
            }
        }

        public static void Petals(Vector2 pos, Color color, int count = 8, float spd = 120f)
        {
            if (I == null) return;
            for (int i = 0; i < count; i++)
            {
                float a = Random.value * Gd.TAU;
                I._parts.Add(new Part { pos = pos, vel = Gd.Dir(a) * spd * Gd.Rand(0.3f, 1f), drag = 1.5f, grav = 60f,
                    life = Gd.Rand(0.5f, 0.9f), maxlife = 0.9f, size = Gd.Rand(2.5f, 4.5f), color = color, shape = 2 });
            }
        }

        public static void RingFx(Vector2 pos, Color color, float r0 = 4f, float r1 = 70f, float life = 0.35f, float width = 4f)
        {
            if (I == null) return;
            I._rings.Add(new Ring { pos = pos, color = color, r0 = r0, r1 = r1, life = life, maxlife = life, width = width });
        }

        public static void SlashFx(Vector2 pos, float angle, float r = 40f, Color? color = null, float sweep = 2.2f, float life = 0.18f, float width = 9f)
        {
            if (I == null) return;
            I._slashes.Add(new Slash { pos = pos, angle = angle, r = r, color = color ?? Color.white, sweep = sweep, life = life, maxlife = life, width = width });
        }

        public static void ZoneFx(Vector2 pos, float r, Color color, float life = 1f)
        {
            if (I == null) return;
            I._zones.Add(new Zone { pos = pos, r = r, color = color, life = life, maxlife = life });
        }

        public static void Rays(Vector2 pos, Color color, int n = 12, float r0 = 20f, float len = 120f, float life = 0.35f)
        {
            if (I == null) return;
            I._rays.Add(new Ray { pos = pos, color = color, n = n, r0 = r0, len = len, rot = Random.value * Gd.TAU, life = life, maxlife = life });
        }

        public static void BoltFx(Vector2 from, Vector2 to, Color color, float life = 0.18f)
        {
            if (I == null) return;
            int seg = 8;
            var pts = new Vector2[seg + 1];
            Vector2 n = Gd.Orth((to - from).normalized);
            float amp = Mathf.Clamp(Vector2.Distance(from, to) * 0.10f, 6f, 22f);
            for (int i = 0; i <= seg; i++)
            {
                float k = (float)i / seg;
                float jitter = (i == 0 || i == seg) ? 0f : Gd.Rand(-amp, amp);
                pts[i] = Vector2.Lerp(from, to, k) + n * jitter;
            }
            I._bolts.Add(new Bolt { pts = pts, color = color, life = life, maxlife = life });
        }

        public static void Puff(Vector2 pos, float r0, float r1, Color color, float life = 0.35f)
        {
            if (I == null) return;
            I._puffs.Add(new PuffFx { pos = pos, r0 = r0, r1 = r1, color = color, life = life, maxlife = life });
        }

        public static void Number(Vector2 pos, string text, Color color, float size = 15f, bool big = false)
        {
            if (I == null) return;
            I._texts.Add(new Txt { pos = pos + new Vector2(Gd.Rand(-8, 8), 0), vel = new Vector2(Gd.Rand(-24, 24), -78f),
                life = 0.62f, maxlife = 0.62f, text = text, color = color, size = size, big = big });
        }

        public static void Flash(Color color, float life = 0.12f)
        {
            if (I == null) return;
            I.flashCol = color; I.flashT = life;
        }

        public static void ShakeAdd(float amount)
        {
            if (I != null) I.shake = Mathf.Min(I.shake + amount, 26f);
        }

        public static void ClearAll()
        {
            if (I == null) return;
            I._parts.Clear(); I._texts.Clear(); I._bolts.Clear(); I._rings.Clear(); I._slashes.Clear(); I._zones.Clear(); I._rays.Clear(); I._puffs.Clear();
            I.shake = 0f; I.flashT = 0f;
        }
    }
}
