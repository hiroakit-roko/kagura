using UnityEngine;

namespace Kagura.Game
{
    /// <summary>一定時間その場に留まる領域（Godot 版 zone.gd）。moon / fog / frost / cloud。</summary>
    public class Zone : MonoBehaviour
    {
        public string kind = "moon";
        public float r = 60f, life = 2f, maxlife = 2f, dmg = 10f;
        public Color color = Color.white;
        public Vector2 pos, vel;
        public bool Active;
        private float _t, _tick, _rot;
        private Vec _vec;

        private void Awake() { _vec = Vec.Create(transform, "vec", Gd.ZPBullet - 1); }

        public void Setup(Vector2 p, string k, float radius, float sec, float d, Color col)
        {
            pos = p; kind = k; r = radius; life = sec; maxlife = sec; dmg = d; color = col;
            _t = 0f; _tick = 0f; _rot = 0f; vel = Vector2.zero;
            Active = true;
            gameObject.SetActive(true);
            transform.position = Gd.ToWorld(pos);
            Draw();
        }

        public void Despawn() { Active = false; gameObject.SetActive(false); }

        public void Tick(float dt, GameManager g)
        {
            _t += dt;
            life -= dt;
            if (life <= 0f) { Despawn(); return; }
            pos += vel * dt;
            vel = Vector2.Lerp(vel, Vector2.zero, Mathf.Clamp01(2f * dt));
            _rot += dt * (kind == "moon" ? 3f : 0.6f);
            _tick -= dt;
            if (_tick <= 0f) { _tick = kind == "moon" ? 0.4f : 0.5f; Apply(g); }
            transform.position = Gd.ToWorld(pos);
            Draw();
        }

        private void Apply(GameManager g)
        {
            var inside = new System.Collections.Generic.List<Enemy>();
            foreach (var e in g.EnemyList()) if (e.Active && Vector2.Distance(e.pos, pos) <= r + e.radius * 0.5f) inside.Add(e);
            switch (kind)
            {
                case "moon":
                    foreach (var e in inside) { Combat.Hit(e, dmg, e.pos, HitOpts.Of("moon", "tsuki")); Fx.SlashFx(e.pos, Random.value * Gd.TAU, 18f, color, 2f, 0.15f, 5f); }
                    break;
                case "fog":
                    foreach (var e in inside) { e.AddHangover(1, Combat.HangoverDps()); if (g.player != null && g.player.Has("duo_ama_suku")) e.AddExposed(Combat.EXPOSED_T); }
                    break;
                case "frost":
                    foreach (var e in inside) { e.AddChill(1); Combat.Hit(e, dmg * 0.5f, e.pos, new HitOpts { tag = "zone", kami = "iza", quiet = true, dir = Vector2.up }); }
                    break;
                case "cloud":
                    {
                        Enemy best = null; float bd = r * r;
                        foreach (var e in inside) { float d = (pos - e.pos).sqrMagnitude; if (d < bd) { bd = d; best = e; } }
                        if (best != null) Combat.Lightning(best, dmg, pos + new Vector2(Gd.Rand(-20, 20), -30), 0);
                        break;
                    }
            }
        }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            float a = Mathf.Clamp01(life * 2f) * Mathf.Clamp01(_t * 4f);
            switch (kind)
            {
                case "moon":
                    for (int i = 0; i < 3; i++)
                    {
                        float ang = _rot + Gd.TAU * i / 3f;
                        v.DrawArc(Vector2.zero, r * 0.8f, ang, ang + 1.4f, 16, Gd.WithA(color, 0.85f * a), 6f);
                        v.DrawArc(Vector2.zero, r * 0.8f, ang + 0.2f, ang + 1.2f, 12, new Color(1, 1, 1, 0.7f * a), 2f);
                    }
                    v.DrawCircle(Vector2.zero, r, Gd.WithA(color, 0.08f * a));
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 40, Gd.WithA(color, 0.35f * a), 1.5f);
                    break;
                case "fog":
                    for (int i = 0; i < 5; i++)
                    {
                        Vector2 off = new Vector2(Mathf.Cos(_t * 0.7f + i * 1.3f), Mathf.Sin(_t * 0.9f + i * 2.1f)) * r * 0.35f;
                        v.DrawCircle(off, r * (0.55f + 0.1f * Mathf.Sin(_t * 2f + i)), Gd.WithA(color, 0.10f * a));
                    }
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 40, Gd.WithA(color, 0.3f * a), 1.5f);
                    break;
                case "frost":
                    v.DrawCircle(Vector2.zero, r, Gd.WithA(color, 0.12f * a));
                    for (int i = 0; i < 6; i++)
                    {
                        float ang = _rot + Gd.TAU * i / 6f;
                        Vector2 p1 = Gd.Dir(ang) * r * 0.9f;
                        v.DrawLine(Vector2.zero, p1, new Color(1, 1, 1, 0.35f * a), 1.5f);
                        Vector2 side = p1 * 0.6f, n = Gd.Orth(p1.normalized) * r * 0.15f;
                        v.DrawLine(side, side + n, new Color(1, 1, 1, 0.3f * a), 1f);
                        v.DrawLine(side, side - n, new Color(1, 1, 1, 0.3f * a), 1f);
                    }
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 40, Gd.WithA(color, 0.5f * a), 2f);
                    break;
                case "cloud":
                    for (int i = 0; i < 4; i++)
                        v.DrawCircle(new Vector2((i - 1.5f) * 22f, Mathf.Sin(i * 2f + _t * 3f) * 4f), 22f + 6f * Mathf.Abs(Mathf.Sin(i * 1.7f)), new Color(0.35f, 0.3f, 0.5f, 0.9f * a));
                    float flick = 0.4f + 0.6f * (Mathf.Repeat(_t * 7f, 1f) < 0.2f ? 1f : 0f);
                    v.DrawCircle(new Vector2(0, 4), 12f, Gd.WithA(color, 0.5f * a * flick));
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 40, Gd.WithA(color, 0.15f * a), 1f);
                    break;
            }
            v.End();
        }
    }
}
